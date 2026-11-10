// Calendar arithmetic for TZif epoch conversion.
//
// The public date components use Int, but all epoch and day arithmetic stays
// in Int64. This is essential on targets where Int is a signed 32-bit value.

///|
let max_int64 : Int64 = 9_223_372_036_854_775_807L

///|
let min_int64 : Int64 = -9_223_372_036_854_775_808L

///|
fn invalid_civil_time(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> @types.TzifError {
  InvalidLocalTime({
    year,
    month,
    day,
    hour,
    minute,
    second,
    utoff: 0,
    is_dst: false,
    abbr: "",
  })
}

///|
/// Add two epoch-second values without allowing Int64 wraparound.
pub fn checked_add_epoch_seconds(
  value : Int64,
  delta : Int64,
) -> @types.TzifResult[Int64] {
  if (delta > 0L && value > max_int64 - delta) ||
    (delta < 0L && value < min_int64 - delta) {
    Err(TimestampOutOfRange(value))
  } else {
    Ok(value + delta)
  }
}

///|
/// Subtract an epoch-second delta without allowing Int64 wraparound.
pub fn checked_sub_epoch_seconds(
  value : Int64,
  delta : Int64,
) -> @types.TzifResult[Int64] {
  if (delta > 0L && value < min_int64 + delta) ||
    (delta < 0L && value > max_int64 + delta) {
    Err(TimestampOutOfRange(value))
  } else {
    Ok(value - delta)
  }
}

///|
/// Returns whether `year` is a Gregorian leap year.
pub fn is_leap_year(year : Int) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|
/// Returns the number of days in `month`, or zero when `month` is invalid.
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
/// Returns whether a proleptic Gregorian calendar date is valid.
pub fn is_valid_date(year : Int, month : Int, day : Int) -> Bool {
  let max_day = days_in_month(year, month)
  max_day != 0 && day >= 1 && day <= max_day
}

///|
/// Returns whether a civil clock time is valid.
///
/// Leap seconds are deliberately not accepted here because TZif civil-time
/// conversion uses POSIX seconds, whose seconds field is in 0..59.
pub fn is_valid_civil_time(hour : Int, minute : Int, second : Int) -> Bool {
  hour >= 0 &&
  hour < 24 &&
  minute >= 0 &&
  minute < 60 &&
  second >= 0 &&
  second < 60
}

///|
/// Divides `numerator` by a positive `divisor`, rounding toward negative
/// infinity. TZif uses this for negative epoch timestamps, where normal Int64
/// division would otherwise truncate toward zero.
fn floor_div_i64(numerator : Int64, divisor : Int64) -> Int64 {
  guard divisor > 0L else { panic() }
  let quotient = numerator / divisor
  if numerator % divisor < 0L {
    quotient - 1L
  } else {
    quotient
  }
}

///|
/// Returns the non-negative remainder for division by a positive divisor.
fn floor_mod_i64(numerator : Int64, divisor : Int64) -> Int64 {
  guard divisor > 0L else { panic() }
  let remainder = numerator % divisor
  if remainder < 0L {
    remainder + divisor
  } else {
    remainder
  }
}

///|
/// Converts a valid proleptic Gregorian date to days since 1970-01-01.
///
/// This is the constant-time `days_from_civil` algorithm. It intentionally
/// uses Int64 throughout so years far from the epoch cannot overflow a
/// 32-bit target while accumulating days.
pub fn days_from_civil(year : Int, month : Int, day : Int) -> Int64 {
  let mut adjusted_year = year.to_int64()
  if month <= 2 {
    adjusted_year = adjusted_year - 1L
  }
  let era = floor_div_i64(adjusted_year, 400L)
  let year_of_era = adjusted_year - era * 400L
  let march_month = if month > 2 { month - 3 } else { month + 9 }
  let day_of_year = (153L * march_month.to_int64() + 2L) / 5L +
    day.to_int64() -
    1L
  let day_of_era = year_of_era * 365L +
    year_of_era / 4L -
    year_of_era / 100L +
    day_of_year
  era * 146097L + day_of_era - 719468L
}

///|
/// Converts a day count to a proleptic Gregorian `(year, month, day)` tuple.
///
/// `LocalDateTime.year` is an Int, so day counts whose year cannot be
/// represented on every target return `TimestampOutOfRange` instead of being
/// truncated.
pub fn civil_from_days(
  days_since_epoch : Int64,
) -> @types.TzifResult[(Int, Int, Int)] {
  let adjusted_days = match
    checked_add_epoch_seconds(days_since_epoch, 719468L) {
    Ok(value) => value
    Err(_) => return Err(TimestampOutOfRange(days_since_epoch))
  }
  let era = floor_div_i64(adjusted_days, 146097L)
  let day_of_era = adjusted_days - era * 146097L
  let year_of_era = (
      day_of_era -
      day_of_era / 1460L +
      day_of_era / 36524L -
      day_of_era / 146096L
    ) /
    365L
  let mut year = year_of_era + era * 400L
  let day_of_year = day_of_era -
    (365L * year_of_era + year_of_era / 4L - year_of_era / 100L)
  let march_month = (5L * day_of_year + 2L) / 153L
  let day = day_of_year - (153L * march_month + 2L) / 5L + 1L
  let month = if march_month < 10L {
    march_month + 3L
  } else {
    march_month - 9L
  }
  if month <= 2L {
    year = year + 1L
  }
  let civil_year = year.to_int()
  if civil_year.to_int64() != year {
    Err(TimestampOutOfRange(days_since_epoch))
  } else {
    Ok((civil_year, month.to_int(), day.to_int()))
  }
}

///|
/// Decomposes UTC epoch seconds into `(year, month, day, hour, minute,
/// second)`. Negative timestamps use floor division, so `-1L` is correctly
/// represented as 1969-12-31 23:59:59.
pub fn decompose_epoch(
  epoch_seconds : Int64,
) -> @types.TzifResult[(Int, Int, Int, Int, Int, Int)] {
  let days = floor_div_i64(epoch_seconds, 86400L)
  let time_of_day = floor_mod_i64(epoch_seconds, 86400L)
  let (year, month, day) = match civil_from_days(days) {
    Ok(value) => value
    Err(_) => return Err(TimestampOutOfRange(epoch_seconds))
  }
  let hour = (time_of_day / 3600L).to_int()
  let minute = (time_of_day % 3600L / 60L).to_int()
  let second = (time_of_day % 60L).to_int()
  Ok((year, month, day, hour, minute, second))
}

///|
/// Composes a proleptic Gregorian date and time into UTC epoch seconds.
///
/// Invalid civil fields and arithmetic overflow are returned as checked
/// errors. This keeps every public conversion path free from normalization or
/// wraparound surprises.
pub fn compose_epoch(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> @types.TzifResult[Int64] {
  if !is_valid_date(year, month, day) ||
    !is_valid_civil_time(hour, minute, second) {
    return Err(invalid_civil_time(year, month, day, hour, minute, second))
  }
  let days = days_from_civil(year, month, day)
  if days > max_int64 / 86400L || days < min_int64 / 86400L {
    return Err(TimestampOutOfRange(days))
  }
  let day_seconds = days * 86400L
  let time_of_day = hour.to_int64() * 3600L +
    minute.to_int64() * 60L +
    second.to_int64()
  checked_add_epoch_seconds(day_seconds, time_of_day)
}

///|
/// Computes the day of week for an epoch timestamp.
///
/// Returns 0=Sunday, 1=Monday, ..., 6=Saturday. Epoch 0 was Thursday.
pub fn day_of_week_of_epoch(epoch : Int64) -> Int {
  let days = floor_div_i64(epoch, 86400L)
  floor_mod_i64(days + 4L, 7L).to_int()
}
