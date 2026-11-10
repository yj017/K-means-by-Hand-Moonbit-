///|
/// Convert this value to Matplotlib's floating-point day representation.
pub fn DateTime::to_ordinal(self : DateTime) -> Double {
  unix_microseconds_to_ordinal(rruleset_instant(self))
}

///|
/// Convert a Matplotlib UTC day value to a date, rounding to the nearest
/// microsecond and applying an optional fixed offset for the returned fields.
/// `offset_seconds` retains sub-minute history; nonzero `offset_minutes` and
/// `offset_seconds` cannot be supplied together.
pub fn from_ordinal(
  value : Double,
  offset_minutes~ : Int32 = 0,
  offset_seconds? : Int32,
) -> DateTime raise DateError {
  let offset_seconds = resolve_offset_seconds(offset_minutes, offset_seconds)
  decoded_ordinal(value, offset_seconds, false)
}

///|
fn decoded_ordinal(
  value : Double,
  offset_seconds : Int32,
  generated : Bool,
) -> DateTime raise DateError {
  let total_microseconds = ordinal_to_unix_microseconds(value, generated~)
  let mut local_microseconds = total_microseconds +
    Int64::from_int(offset_seconds) * 1_000_000L
  // Matplotlib applies the distant-date 20-microsecond correction after
  // converting to the requested timezone, so the correction follows the
  // local clock's microsecond field across midnight and offset boundaries.
  if Double::abs(value) > 70.0 * 365.0 {
    let second = locator_floor_div64(local_microseconds, 1_000_000L)
    let fraction = local_microseconds - second * 1_000_000L
    local_microseconds = second * 1_000_000L +
      round_even_to_int64(fraction.to_double() / 20.0) * 20L
  }
  datetime_from_microseconds(local_microseconds, offset_seconds)
}

///|
/// Convert an exact local microsecond count to a validated DateTime.
fn datetime_from_microseconds(
  local_microseconds : Int64,
  offset_seconds : Int32,
) -> DateTime raise DateError {
  let day_number = floor_divide_microseconds(local_microseconds)
  let remainder = local_microseconds - day_number * 86_400_000_000L
  let total_seconds = remainder / 1_000_000L
  let microsecond = (remainder % 1_000_000L).to_int()
  let (year, month, day) = civil_from_days(day_number.to_int())
  let hour = (total_seconds / 3600L).to_int()
  let minute = (total_seconds % 3600L / 60L).to_int()
  let second = (total_seconds % 60L).to_int()
  datetime(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    microsecond~,
    offset_seconds~,
  )
}

///|
// Convert a nonnegative or negative floating-point value to an Int64 using
// the ties-to-even rule used by NumPy's round.  The supported ordinal range
// is far below the point where the intermediate value can overflow Int64.
fn round_even_to_int64(value : Double) -> Int64 {
  let lower = value.floor()
  let fraction = value - lower
  let lower_integer = lower.to_int64()
  if fraction < 0.5 {
    lower_integer
  } else if fraction > 0.5 {
    lower_integer + 1L
  } else if lower_integer % 2L == 0L {
    lower_integer
  } else {
    lower_integer + 1L
  }
}

///|
// Floor division by the positive number of microseconds in a day.
fn floor_divide_microseconds(value : Int64) -> Int64 {
  let quotient = value / 86_400_000_000L
  if value % 86_400_000_000L < 0L {
    quotient - 1L
  } else {
    quotient
  }
}

///|
/// Matplotlib-compatible name for converting a date to a numeric day value.
pub fn date2num(value : DateTime) -> Double {
  value.to_ordinal()
}

///|
/// Convert a numeric UTC day value using the current timezone rc, unless an
/// explicit tz string, timezone object or fixed offset is supplied. Explicit
/// offset_minutes=0 selects UTC. from_ordinal remains the legacy UTC helper.
pub fn num2date(
  value : Double,
  tz? : String,
  timezone? : DateTimeZone,
  offset_minutes? : Int32,
  offset_seconds? : Int32,
) -> DateTime raise DateError {
  if offset_minutes is Some(_) || offset_seconds is Some(_) {
    if tz is Some(_) || timezone is Some(_) {
      raise DateError::InvalidDate(
        message="use either a timezone or fixed offset",
      )
    }
    return from_ordinal(
      value,
      offset_minutes=offset_minutes.unwrap_or(0),
      offset_seconds?,
    )
  }
  selected_timezone(tz, timezone).to_datetime(value)
}
