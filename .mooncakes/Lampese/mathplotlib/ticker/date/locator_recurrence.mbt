///|
// Expand a local calendar candidate to every UTC instant it can represent.
// Fixed-offset locators have exactly one candidate.
fn DateLocator::ordinals_for_date(
  self : DateLocator,
  value : DateTime,
) -> Array[Double] {
  match self.timezone {
    Some(timezone) => timezone.local_ordinal_candidates(value)
    None => [value.to_ordinal()]
  }
}

///|
fn locator_push_date_ticks(
  result : Array[Double],
  locator : DateLocator,
  value : DateTime,
  first : Double,
  last : Double,
) -> Unit {
  for ordinal in locator.ordinals_for_date(value) {
    locator_push_tick(result, ordinal, first, last)
  }
}

///|
fn locator_floor_div64(value : Int64, divisor : Int64) -> Int64 {
  let quotient = value / divisor
  if value % divisor < 0L {
    quotient - 1L
  } else {
    quotient
  }
}

///|
fn locator_ceil_div64(value : Int64, divisor : Int64) -> Int64 {
  -locator_floor_div64(-value, divisor)
}

///|
fn locator_seconds(value : DateTime) -> Int64 {
  Int64::from_int(days_from_civil(value.year, value.month, value.day)) * 86400L +
  Int64::from_int(value.hour * 3600 + value.minute * 60 + value.second)
}

///|
fn locator_microseconds(value : DateTime) -> Int64 {
  locator_seconds(value) * 1_000_000L + Int64::from_int(value.microsecond)
}

///|
// Only called with microseconds inside the supported Gregorian year range.
fn locator_datetime_microseconds(
  microseconds : Int64,
  offset_seconds : Int32,
) -> DateTime {
  let day = locator_floor_div64(microseconds, 86_400_000_000L)
  let remainder = microseconds - day * 86_400_000_000L
  let (year, month, day) = civil_from_days(day.to_int())
  {
    year,
    month,
    day,
    hour: (remainder / 3_600_000_000L).to_int(),
    minute: (remainder % 3_600_000_000L / 60_000_000L).to_int(),
    second: (remainder % 60_000_000L / 1_000_000L).to_int(),
    microsecond: (remainder % 1_000_000L).to_int(),
    offset_minutes: offset_seconds / 60,
    offset_seconds,
    abbreviation: None,
    timezone: None,
  }
}

///|
// Only called with seconds inside the supported Gregorian year range.
fn locator_datetime(seconds : Int64, offset_minutes : Int32) -> DateTime {
  locator_datetime_microseconds(seconds * 1_000_000L, offset_minutes * 60)
}

///|
// Like dateutil.relativedelta, preserve the time and clamp the day when the
// target month is shorter. Returning None signals datetime under/overflow.
fn locator_shift_months(value : DateTime, months : Int32) -> DateTime? {
  let index = value.year * 12 + value.month - 1 + months
  if index < 12 || index >= 120000 {
    return None
  }
  let year = index / 12
  let month = index % 12 + 1
  Some({
    year,
    month,
    day: Int32::min(value.day, days_in_month(year, month)),
    hour: value.hour,
    minute: value.minute,
    second: value.second,
    microsecond: value.microsecond,
    offset_minutes: value.offset_minutes,
    offset_seconds: value.offset_seconds,
    abbreviation: value.abbreviation,
    timezone: value.timezone,
  })
}

///|
// RRuleLocator._create_rrule uses first - relativedelta(last, first).
// A calendar difference is whole months followed by the residual microseconds;
// replacing it with (last - first) days changes interval phases near month ends.
fn recurrence_start(first : DateTime, last : DateTime) -> DateTime {
  let mut months = (last.year - first.year) * 12 + last.month - first.month
  let last_microseconds = locator_microseconds(last)
  let mut shifted = locator_shift_months(first, months).unwrap()
  if locator_microseconds(shifted) > last_microseconds {
    months -= 1
    shifted = locator_shift_months(first, months).unwrap()
  }
  let residual = last_microseconds - locator_microseconds(shifted)
  let minimum = locator_microseconds({
    year: 1,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    microsecond: 0,
    offset_minutes: 0,
    offset_seconds: 0,
    abbreviation: None,
    timezone: None,
  })
  let start = match locator_shift_months(first, -months) {
    Some(value) => Int64::max(locator_microseconds(value) - residual, minimum)
    None => minimum
  }
  locator_datetime_microseconds(start, first.offset_seconds)
}

///|
// Skip recurrence candidates before the visible range without changing phase.
// All arithmetic uses Int64: a valid interval may be as large as Int::MAX.
fn locator_align(first : Int64, anchor : Int64, step : Int64) -> Int64 {
  anchor + Int64::max(0L, locator_ceil_div64(first - anchor, step)) * step
}

///|
fn locator_push_tick(
  result : Array[Double],
  value : Double,
  first : Double,
  last : Double,
) -> Unit {
  if result.length() < 100000 && value >= first && value <= last {
    result.push(value)
  }
}

///|
fn locator_datetime_seconds(
  seconds : Int64,
  offset_seconds : Int32,
) -> DateTime {
  locator_datetime_microseconds(seconds * 1_000_000L, offset_seconds)
}
