///|
/// Calendar-relative changes and absolute field replacements. Fractional time
/// components remain separate until normalized or applied; months are calendar
/// months. Construction and inspection do not read the date epoch or timezone rc.
pub struct RelativeDelta {
  priv years : Int64
  priv months : Int32
  priv days : Double
  priv leapdays : Double
  priv hours : Double
  priv minutes : Double
  priv seconds : Double
  priv microseconds : Double
  priv year : Int32?
  priv month : Int32?
  priv day : Int32?
  priv hour : Int32?
  priv minute : Int32?
  priv second : Int32?
  priv microsecond : Int32?
  priv weekday : RelativeWeekday?
} derive(Debug)

///|
pub extend RelativeDelta with @debug.Debug::{to_repr}

///|
fn relative_finite(value : Double) -> Unit raise DateError {
  if value.is_nan() || value.is_inf() {
    raise DateError::InvalidDate(
      message="relative date components must be finite",
    )
  }
}

///|
fn relative_add_years(first : Int64, second : Int64) -> Int64 raise DateError {
  if (second > 0L && first > 9223372036854775807L - second) ||
    (second < 0L && first < -9223372036854775808L - second) {
    raise DateError::InvalidDate(message="relative years overflow Int64")
  }
  first + second
}

///|
// CPython float divmod for a nonnegative input and positive integer divisor.
// The quotient rounds the result of (value - remainder) / divisor to recover
// exact-integer division when the final floating operation is slightly inexact.
fn relative_carry(
  value : Double,
  base : Double,
  threshold : Double,
) -> (Double, Double) {
  if Double::abs(value) <= threshold {
    return (0.0, value)
  }
  let magnitude = Double::abs(value)
  let remainder = magnitude % base
  let quotient = (magnitude - remainder) / base
  let floor = quotient.floor()
  let integral = if quotient - floor > 0.5 { floor + 1.0 } else { floor }
  if value < 0.0 {
    (-integral, -remainder)
  } else {
    (integral, remainder)
  }
}

///|
/// Construct dateutil's relative/absolute calendar fields. Relative years and
/// months are Int64; fractional day/time fields are finite Double. Absolute
/// fields are stored without datetime validation until application, including
/// year/month/day=0 fallback. Use either weekday (-7..6 tuple index) or the
/// on_weekday object form. nlyearday takes precedence over a nonzero yearday.
pub fn RelativeDelta::new(
  years~ : Int64 = 0L,
  months~ : Int64 = 0L,
  days~ : Double = 0.0,
  weeks~ : Double = 0.0,
  leapdays~ : Double = 0.0,
  hours~ : Double = 0.0,
  minutes~ : Double = 0.0,
  seconds~ : Double = 0.0,
  microseconds~ : Double = 0.0,
  year? : Int32,
  month? : Int32,
  day? : Int32,
  hour? : Int32,
  minute? : Int32,
  second? : Int32,
  microsecond? : Int32,
  weekday? : Int32,
  on_weekday? : RelativeWeekday,
  yearday? : Int32,
  nlyearday? : Int32,
) -> RelativeDelta raise DateError {
  for value in [days, weeks, leapdays, hours, minutes, seconds, microseconds] {
    relative_finite(value)
  }
  let weekday = match (weekday, on_weekday) {
    (Some(_), Some(_)) =>
      raise DateError::InvalidDate(message="use either weekday or on_weekday")
    (Some(index), None) => {
      if index < -7 || index > 6 {
        raise DateError::InvalidDate(message="integer weekday must be in -7..6")
      }
      Some(RelativeWeekday::new(if index < 0 { index + 7 } else { index }))
    }
    (_, object) => object
  }
  let mut month = month
  let mut day = day
  let mut leapdays = leapdays
  let yday = if nlyearday.unwrap_or(0) != 0 {
    nlyearday.unwrap()
  } else {
    let selected = yearday.unwrap_or(0)
    if selected > 59 {
      leapdays = -1.0
    }
    selected
  }
  if yday != 0 {
    if yday > 366 {
      raise DateError::InvalidDate(message="invalid relative year day")
    }
    let limits = [31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 366]
    let mut index = 0
    while index < 11 && yday > limits[index] {
      index += 1
    }
    month = Some(index + 1)
    day = Some(yday - (if index == 0 { 0 } else { limits[index - 1] }))
  }
  let (carry, microseconds) = relative_carry(microseconds, 1000000.0, 999999.0)
  let (carry, seconds) = relative_carry(seconds + carry, 60.0, 59.0)
  let (carry, minutes) = relative_carry(minutes + carry, 60.0, 59.0)
  let (carry, hours) = relative_carry(hours + carry, 24.0, 23.0)
  let days = days + weeks * 7.0 + carry
  for value in [days, hours, minutes, seconds, microseconds] {
    relative_finite(value)
  }
  let years = relative_add_years(years, months / 12L)
  {
    years,
    months: (months % 12L).to_int(),
    days,
    leapdays,
    hours,
    minutes,
    seconds,
    microseconds,
    year,
    month,
    day,
    hour,
    minute,
    second,
    microsecond,
    weekday,
  }
}

///|
/// Integral-valued Double, matching truncation in dateutil's weeks property.
pub fn RelativeDelta::weeks(self : RelativeDelta) -> Double {
  (self.days / 7.0).trunc()
}

///|
pub fn RelativeDelta::has_time(self : RelativeDelta) -> Bool {
  self.hours != 0.0 ||
  self.minutes != 0.0 ||
  self.seconds != 0.0 ||
  self.microseconds != 0.0 ||
  self.hour is Some(_) ||
  self.minute is Some(_) ||
  self.second is Some(_) ||
  self.microsecond is Some(_)
}

///|
pub fn RelativeDelta::years(self : RelativeDelta) -> Int64 {
  self.years
}

///|
pub fn RelativeDelta::months(self : RelativeDelta) -> Int32 {
  self.months
}

///|
pub fn RelativeDelta::days(self : RelativeDelta) -> Double {
  self.days
}

///|
pub fn RelativeDelta::leapdays(self : RelativeDelta) -> Double {
  self.leapdays
}

///|
pub fn RelativeDelta::hours(self : RelativeDelta) -> Double {
  self.hours
}

///|
pub fn RelativeDelta::minutes(self : RelativeDelta) -> Double {
  self.minutes
}

///|
pub fn RelativeDelta::seconds(self : RelativeDelta) -> Double {
  self.seconds
}

///|
pub fn RelativeDelta::microseconds(self : RelativeDelta) -> Double {
  self.microseconds
}

///|
pub fn RelativeDelta::year(self : RelativeDelta) -> Int32? {
  self.year
}

///|
pub fn RelativeDelta::month(self : RelativeDelta) -> Int32? {
  self.month
}

///|
pub fn RelativeDelta::day(self : RelativeDelta) -> Int32? {
  self.day
}

///|
pub fn RelativeDelta::hour(self : RelativeDelta) -> Int32? {
  self.hour
}

///|
pub fn RelativeDelta::minute(self : RelativeDelta) -> Int32? {
  self.minute
}

///|
pub fn RelativeDelta::second(self : RelativeDelta) -> Int32? {
  self.second
}

///|
pub fn RelativeDelta::microsecond(self : RelativeDelta) -> Int32? {
  self.microsecond
}

///|
pub fn RelativeDelta::weekday(self : RelativeDelta) -> RelativeWeekday? {
  self.weekday
}
