///|
// CPython timedelta accumulates each float's integer contribution exactly and
// carries fractional microseconds separately, in us/seconds/minutes/hours/days
// order. Round the combined fraction using the integer sum's parity.
fn RelativeDelta::wall_duration(
  self : RelativeDelta,
  effective_days : Double,
) -> TimeDelta raise DateError {
  relative_finite(effective_days)
  if effective_days < -3652060.0 || effective_days > 3652060.0 {
    raise DateError::InvalidDate(
      message="relative date arithmetic overflows years 1..9999",
    )
  }
  let mut whole = 0L
  let mut leftover = 0.0
  for
    (value, factor) in [
      (self.microseconds, 1L),
      (self.seconds, 1000000L),
      (self.minutes, 60000000L),
      (self.hours, 3600000000L),
      (effective_days, 86400000000L),
    ] {
    let integer = value.trunc()
    whole += integer.to_int64() * factor
    let fraction = (value - integer) * factor.to_double()
    let integer = fraction.trunc()
    whole += integer.to_int64()
    leftover += fraction - integer
  }
  let floor = leftover.floor().to_int64()
  let fraction = leftover - floor.to_double()
  let rounded = if fraction < 0.5 {
    floor
  } else if fraction > 0.5 {
    floor + 1L
  } else if (whole + floor) % 2L == 0L {
    floor
  } else {
    floor + 1L
  }
  normalized_timedelta(0L, whole + rounded)
}

///|
/// Apply calendar replacements/relative fields, then weekday movement. Months
/// clamp to month end. Relative time uses exact wall-clock microseconds and the
/// retained rule zone; folds reset to the earlier occurrence and gaps use the
/// dateutil post-transition offset. Neither rc timezone nor epoch is read.
pub fn DateTime::add_relative_delta(
  self : DateTime,
  delta : RelativeDelta,
) -> DateTime raise DateError {
  let year = match delta.year {
    Some(value) if value != 0 => value
    _ => self.year
  }
  let mut year = relative_add_years(Int64::from_int(year), delta.years)
  let month = match delta.month {
    Some(value) if value != 0 => value
    _ => self.month
  }
  let mut month = Int64::from_int(month)
  if delta.months != 0 {
    month += Int64::from_int(delta.months)
    if month > 12L {
      year = relative_add_years(year, 1L)
      month -= 12L
    } else if month < 1L {
      year = relative_add_years(year, -1L)
      month += 12L
    }
  }
  if year < 1L || year > 9999L || month < 1L || month > 12L {
    raise DateError::InvalidDate(
      message="relative date year or month is outside the calendar",
    )
  }
  let year = year.to_int()
  let month = month.to_int()
  let day = match delta.day {
    Some(value) if value != 0 => value
    _ => self.day
  }
  let base = datetime(
    year,
    month,
    Int32::min(day, days_in_month(year, month)),
    hour=delta.hour.unwrap_or(self.hour),
    minute=delta.minute.unwrap_or(self.minute),
    second=delta.second.unwrap_or(self.second),
    microsecond=delta.microsecond.unwrap_or(self.microsecond),
    offset_seconds=self.offset_seconds,
  )
  let days = if delta.leapdays != 0.0 && month > 2 && is_leap_year(year) {
    delta.days + delta.leapdays
  } else {
    delta.days
  }
  let duration = delta.wall_duration(days)
  let mut result = base.add_timedelta(duration)
  if delta.weekday is Some(weekday) {
    let nth = weekday.nth.unwrap_or(1)
    let nth = if nth == 0 { 1L } else { Int64::from_int(nth) }
    let target = Int64::from_int(weekday.weekday)
    let current = Int64::from_int(result.weekday())
    let shift = if nth > 0L {
      (nth - 1L) * 7L + ((7L - current + target) % 7L + 7L) % 7L
    } else {
      -((-nth - 1L) * 7L + ((current - target) % 7L + 7L) % 7L)
    }
    if shift < -3652060L || shift > 3652060L {
      raise DateError::InvalidDate(
        message="relative weekday movement overflows the calendar",
      )
    }
    result = result.add_timedelta(timedelta(days=shift.to_int()))
  }
  match self.timezone {
    Some(zone) => zone.resolve_arithmetic_local(result)
    None => { ..result, abbreviation: self.abbreviation, }
  }
}
