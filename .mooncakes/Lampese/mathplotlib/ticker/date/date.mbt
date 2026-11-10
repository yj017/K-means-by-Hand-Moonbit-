///|
/// Errors raised while constructing or parsing a date value.
pub(all) suberror DateError {
  InvalidDate(message~ : String)
  InvalidFormat(message~ : String)
}

///|
/// A Gregorian date and time used by the date ticker.
///
/// `offset_seconds` stores an exact offset east of UTC, including historical seconds. The numeric
/// representation follows Matplotlib: days since 1970-01-01 UTC, with the
/// local time converted back to its instant before encoding.
pub struct DateTime {
  year : Int32
  month : Int32
  day : Int32
  hour : Int32
  minute : Int32
  second : Int32
  microsecond : Int32
  offset_minutes : Int32
  priv offset_seconds : Int32
  priv abbreviation : String?
  priv timezone : DateTimeZone?
}

///|
fn validate_date(
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
  second : Int32,
  microsecond : Int32,
  offset_seconds : Int32,
) -> Unit raise DateError {
  if year < 1 || year > 9999 {
    raise DateError::InvalidDate(message="year must be in 1..9999")
  }
  if month < 1 || month > 12 {
    raise DateError::InvalidDate(message="month must be in 1..12")
  }
  if day < 1 || day > days_in_month(year, month) {
    raise DateError::InvalidDate(message="day is outside the month")
  }
  if hour < 0 || hour > 23 {
    raise DateError::InvalidDate(message="hour must be in 0..23")
  }
  if minute < 0 || minute > 59 {
    raise DateError::InvalidDate(message="minute must be in 0..59")
  }
  if second < 0 || second > 59 {
    raise DateError::InvalidDate(message="second must be in 0..59")
  }
  if microsecond < 0 || microsecond > 999999 {
    raise DateError::InvalidDate(message="microsecond must be in 0..999999")
  }
  validate_offset_seconds(offset_seconds)
}

///|
/// Construct a validated Gregorian date and time.
/// `offset_seconds` selects exact historical offsets. Supply either seconds
/// or a nonzero `offset_minutes`, never both.
///
/// ```mbt check
/// test {
///   let value = @date.datetime(1970, 1, 1, hour=2, offset_minutes=120)
///   assert_eq(value.offset_minutes(), 120)
///   assert_eq(value.to_ordinal(), 0.0)
/// }
/// ```
pub fn datetime(
  year : Int32,
  month : Int32,
  day : Int32,
  hour~ : Int32 = 0,
  minute~ : Int32 = 0,
  second~ : Int32 = 0,
  microsecond~ : Int32 = 0,
  offset_minutes~ : Int32 = 0,
  offset_seconds? : Int32,
) -> DateTime raise DateError {
  let offset_seconds = resolve_offset_seconds(offset_minutes, offset_seconds)
  validate_date(
    year, month, day, hour, minute, second, microsecond, offset_seconds,
  )
  {
    year,
    month,
    day,
    hour,
    minute,
    second,
    microsecond,
    offset_minutes: offset_seconds / 60,
    offset_seconds,
    abbreviation: None,
    timezone: None,
  }
}

///|
pub fn DateTime::year(self : DateTime) -> Int32 {
  self.year
}

///|
pub fn DateTime::month(self : DateTime) -> Int32 {
  self.month
}

///|
pub fn DateTime::day(self : DateTime) -> Int32 {
  self.day
}

///|
pub fn DateTime::hour(self : DateTime) -> Int32 {
  self.hour
}

///|
pub fn DateTime::minute(self : DateTime) -> Int32 {
  self.minute
}

///|
pub fn DateTime::second(self : DateTime) -> Int32 {
  self.second
}

///|
pub fn DateTime::microsecond(self : DateTime) -> Int32 {
  self.microsecond
}

///|
/// Return whole offset minutes, truncated toward zero for historical seconds.
/// Use `offset_seconds()` for exact arithmetic.
pub fn DateTime::offset_minutes(self : DateTime) -> Int32 {
  self.offset_seconds / 60
}

///|
/// Convert this instant to a different fixed UTC offset.
/// The conversion preserves all six microsecond digits even far from epoch.
///
/// ```mbt check
/// test {
///   let value = @date.datetime(2243, 10, 17, microsecond=123456)
///   let shifted = value.with_offset(-480)
///   assert_eq(shifted.day(), 16)
///   assert_eq(shifted.hour(), 16)
///   assert_eq(shifted.microsecond(), 123456)
/// }
/// ```
pub fn DateTime::with_offset(
  self : DateTime,
  offset_minutes : Int32,
) -> DateTime raise DateError {
  validate_offset(offset_minutes)
  self.with_offset_seconds(offset_minutes * 60)
}

///|
/// Return the exact fixed offset east of UTC, in seconds.
///
/// ```mbt check
/// test {
///   let value = @date.datetime(1900, 1, 1, offset_seconds=561)
///   assert_eq(value.offset_seconds(), 561)
///   assert_eq(@date.format_date(value.with_offset(0), "%H:%M:%S"), "23:50:39")
/// }
/// ```
pub fn DateTime::offset_seconds(self : DateTime) -> Int32 {
  self.offset_seconds
}

///|
/// Return the TZif designation, if this value was converted through a TZif zone.
pub fn DateTime::timezone_abbreviation(self : DateTime) -> String? {
  self.abbreviation
}

///|
/// Convert this instant to an exact offset, preserving all microsecond digits.
pub fn DateTime::with_offset_seconds(
  self : DateTime,
  offset_seconds : Int32,
) -> DateTime raise DateError {
  validate_offset_seconds(offset_seconds)
  let utc_microseconds = locator_microseconds(self) -
    Int64::from_int(self.offset_seconds) * 1_000_000L
  datetime_from_microseconds(
    utc_microseconds + Int64::from_int(offset_seconds) * 1_000_000L,
    offset_seconds,
  )
}

///|
/// Return the weekday using Monday=0 through Sunday=6, like Python datetime.
pub fn DateTime::weekday(self : DateTime) -> Int32 {
  weekday_from_civil(self.year, self.month, self.day)
}

///|
fn validate_offset(offset_minutes : Int32) -> Unit raise DateError {
  if offset_minutes <= -1440 || offset_minutes >= 1440 {
    raise DateError::InvalidDate(
      message="offset_minutes must be in -1439..1439",
    )
  }
}

///|
fn validate_offset_seconds(offset_seconds : Int32) -> Unit raise DateError {
  if offset_seconds <= -86400 || offset_seconds >= 86400 {
    raise DateError::InvalidDate(
      message="offset_seconds must be in -86399..86399",
    )
  }
}

///|
fn resolve_offset_seconds(
  minutes : Int32,
  seconds : Int32?,
) -> Int32 raise DateError {
  validate_offset(minutes)
  match seconds {
    Some(value) => {
      if minutes != 0 {
        raise DateError::InvalidDate(
          message="specify offset_minutes or offset_seconds, not both",
        )
      }
      validate_offset_seconds(value)
      value
    }
    None => minutes * 60
  }
}

///|
/// Return the retained rule zone, if converted using with_timezone/to_datetime.
/// Explicit fixed-offset conversions clear this reference.
pub fn DateTime::timezone(self : DateTime) -> DateTimeZone? {
  self.timezone
}
