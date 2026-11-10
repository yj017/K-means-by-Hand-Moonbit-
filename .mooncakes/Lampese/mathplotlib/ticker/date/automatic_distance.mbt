///|
fn auto_date_difference(left : DateTime, right : DateTime) -> Int64 {
  match (left.timezone, right.timezone) {
    (Some(first), Some(last)) if physical_equal(first, last) =>
      locator_microseconds(left) - locator_microseconds(right)
    _ => rruleset_instant(left) - rruleset_instant(right)
  }
}

///|
fn auto_shift_months(
  value : DateTime,
  months : Int32,
) -> DateTime raise DateError {
  let shifted = match locator_shift_months(value, months) {
    Some(value) => value
    None =>
      raise DateError::InvalidDate(
        message="calendar difference exceeds supported years",
      )
  }
  match value.timezone {
    Some(zone) => zone.resolve_arithmetic_local(shifted)
    None => shifted
  }
}

///|
// dates.get_locator combines relativedelta calendar components with timedelta
// days and seconds. Retain its signed month-end behavior and Python's floor
// seconds representation before normalizing the residual into hours/minutes.
fn automatic_distances(
  first : DateTime,
  last : DateTime,
) -> Array[Double] raise DateError {
  let difference = auto_date_difference(last, first)
  let reverse = difference < 0L
  let mut months = (last.year - first.year) * 12 + last.month - first.month
  let mut shifted = auto_shift_months(first, months)
  while (if reverse {
          auto_date_difference(last, shifted) > 0L
        } else {
          auto_date_difference(last, shifted) < 0L
        }) {
    months += if reverse { 1 } else { -1 }
    shifted = auto_shift_months(first, months)
  }
  let residual = auto_date_difference(last, shifted)
  let seconds = locator_floor_div64(residual, 1_000_000L)
  let sign = if reverse { -1 } else { 1 }
  let absolute = if reverse { -difference } else { difference }
  let days = absolute / 86_400_000_000L
  let total_seconds = timedelta(microseconds=absolute).total_seconds()
  let hours = days.to_double() * 24.0 +
    (seconds / 3600L % 24L).to_double() * Double::from_int(sign)
  let minutes = hours * 60.0 +
    (seconds / 60L % 60L).to_double() * Double::from_int(sign)
  [
    Double::from_int(months / 12 * sign),
    Double::from_int(months * sign),
    days.to_double(),
    hours,
    minutes,
    total_seconds.floor(),
    (total_seconds * 1.0e6).floor(),
  ]
}
