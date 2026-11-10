///|
fn[A] relative_prefer(first : A?, second : A?) -> A? {
  match first {
    Some(_) => first
    None => second
  }
}

///|
fn relative_sub_years(first : Int64, second : Int64) -> Int64 raise DateError {
  if (second > 0L && first < -9223372036854775808L + second) ||
    (second < 0L && first > 9223372036854775807L + second) {
    raise DateError::InvalidDate(message="relative years overflow Int64")
  }
  first - second
}

///|
fn RelativeDelta::rebuild(
  self : RelativeDelta,
  years : Int64,
  months : Int64,
  days : Double,
  hours : Double,
  minutes : Double,
  seconds : Double,
  microseconds : Double,
) -> RelativeDelta raise DateError {
  RelativeDelta::new(
    years~,
    months~,
    days~,
    hours~,
    minutes~,
    seconds~,
    microseconds~,
    leapdays=self.leapdays,
    year?=self.year,
    month?=self.month,
    day?=self.day,
    hour?=self.hour,
    minute?=self.minute,
    second?=self.second,
    microsecond?=self.microsecond,
    on_weekday?=self.weekday,
  )
}

///|
/// Add relative components; the right operand supplies non-None absolute fields
/// and weekday, and supplies leapdays when nonzero. Inputs remain unchanged.
pub fn RelativeDelta::add(
  self : RelativeDelta,
  other : RelativeDelta,
) -> RelativeDelta raise DateError {
  let absolute = {
    ..self,
    year: relative_prefer(other.year, self.year),
    month: relative_prefer(other.month, self.month),
    day: relative_prefer(other.day, self.day),
    hour: relative_prefer(other.hour, self.hour),
    minute: relative_prefer(other.minute, self.minute),
    second: relative_prefer(other.second, self.second),
    microsecond: relative_prefer(other.microsecond, self.microsecond),
    weekday: relative_prefer(other.weekday, self.weekday),
    leapdays: if other.leapdays != 0.0 {
      other.leapdays
    } else {
      self.leapdays
    },
  }
  let (years, months) = relative_checked_calendar(
    @bigint.BigInt::from_int64(self.years) +
    @bigint.BigInt::from_int64(other.years),
    @bigint.BigInt::from_int(self.months + other.months),
  )
  absolute.rebuild(
    years,
    months,
    self.days + other.days,
    self.hours + other.hours,
    self.minutes + other.minutes,
    self.seconds + other.seconds,
    self.microseconds + other.microseconds,
  )
}

///|
/// Subtract relative fields. Absolute fields/weekday prefer the left operand;
/// leapdays also prefer the left nonzero value, as in dateutil.__sub__.
pub fn RelativeDelta::subtract(
  self : RelativeDelta,
  other : RelativeDelta,
) -> RelativeDelta raise DateError {
  let absolute = {
    ..self,
    year: relative_prefer(self.year, other.year),
    month: relative_prefer(self.month, other.month),
    day: relative_prefer(self.day, other.day),
    hour: relative_prefer(self.hour, other.hour),
    minute: relative_prefer(self.minute, other.minute),
    second: relative_prefer(self.second, other.second),
    microsecond: relative_prefer(self.microsecond, other.microsecond),
    weekday: relative_prefer(self.weekday, other.weekday),
    leapdays: if self.leapdays != 0.0 {
      self.leapdays
    } else {
      other.leapdays
    },
  }
  let (years, months) = relative_checked_calendar(
    @bigint.BigInt::from_int64(self.years) -
    @bigint.BigInt::from_int64(other.years),
    @bigint.BigInt::from_int(self.months - other.months),
  )
  absolute.rebuild(
    years,
    months,
    self.days - other.days,
    self.hours - other.hours,
    self.minutes - other.minutes,
    self.seconds - other.seconds,
    self.microseconds - other.microseconds,
  )
}

///|
pub fn RelativeDelta::add_timedelta(
  self : RelativeDelta,
  delta : TimeDelta,
) -> RelativeDelta raise DateError {
  self.rebuild(
    self.years,
    Int64::from_int(self.months),
    self.days + delta.days.to_double(),
    self.hours,
    self.minutes,
    self.seconds + delta.seconds.to_double(),
    self.microseconds + delta.microseconds.to_double(),
  )
}

///|
/// Negate only relative fields. Absolute fields, leapdays and weekday retain
/// their meaning even when a delta is used in datetime subtraction.
pub fn RelativeDelta::negated(
  self : RelativeDelta,
) -> RelativeDelta raise DateError {
  self.rebuild(
    relative_sub_years(0L, self.years),
    -Int64::from_int(self.months),
    -self.days,
    -self.hours,
    -self.minutes,
    -self.seconds,
    -self.microseconds,
  )
}

///|
pub fn RelativeDelta::abs(
  self : RelativeDelta,
) -> RelativeDelta raise DateError {
  let years = if self.years < 0L {
    relative_sub_years(0L, self.years)
  } else {
    self.years
  }
  self.rebuild(
    years,
    Int64::from_int(self.months).abs(),
    Double::abs(self.days),
    Double::abs(self.hours),
    Double::abs(self.minutes),
    Double::abs(self.seconds),
    Double::abs(self.microseconds),
  )
}

///|
/// Return a copy with the weeks property replaced, retaining the old day
/// remainder. This property setter does not normalize other relative fields.
pub fn RelativeDelta::with_weeks(
  self : RelativeDelta,
  weeks : Double,
) -> RelativeDelta raise DateError {
  relative_finite(weeks)
  let days = self.days - self.weeks() * 7.0 + weeks * 7.0
  relative_finite(days)
  { ..self, days, }
}

///|
pub fn RelativeDelta::is_zero(self : RelativeDelta) -> Bool {
  self.years == 0L &&
  self.months == 0 &&
  self.days == 0.0 &&
  self.leapdays == 0.0 &&
  self.hours == 0.0 &&
  self.minutes == 0.0 &&
  self.seconds == 0.0 &&
  self.microseconds == 0.0 &&
  self.year is None &&
  self.month is None &&
  self.day is None &&
  self.weekday is None &&
  self.hour is None &&
  self.minute is None &&
  self.second is None &&
  self.microsecond is None
}

///|
pub impl Eq for RelativeDelta with fn equal(self, other) {
  let weekdays = match (self.weekday, other.weekday) {
    (None, None) => true
    (Some(a), Some(b)) => {
      let first = a.nth.unwrap_or(1)
      let second = b.nth.unwrap_or(1)
      a.weekday == b.weekday &&
      (if first == 0 { 1 } else { first }) ==
      (if second == 0 { 1 } else { second })
    }
    _ => false
  }
  weekdays &&
  self.years == other.years &&
  self.months == other.months &&
  self.days == other.days &&
  self.leapdays == other.leapdays &&
  self.hours == other.hours &&
  self.minutes == other.minutes &&
  self.seconds == other.seconds &&
  self.microseconds == other.microseconds &&
  self.year == other.year &&
  self.month == other.month &&
  self.day == other.day &&
  self.hour == other.hour &&
  self.minute == other.minute &&
  self.second == other.second &&
  self.microsecond == other.microsecond
}

///|
pub extend RelativeDelta with Eq::{equal, not_equal}

///|
pub fn DateTime::sub_relative_delta(
  self : DateTime,
  delta : RelativeDelta,
) -> DateTime raise DateError {
  self.add_relative_delta(delta.negated())
}

///|
// Scaling first converts every relative field to an integer. Keep those
// temporary integers exact through carries, including cancellation of values
// larger than binary64's exact-integer range, before exposing Double day fields.
fn relative_double_integer(value : Double) -> @bigint.BigInt raise DateError {
  relative_finite(value)
  let bits = value.reinterpret_as_uint64()
  let encoded_exponent = ((bits >> 52) & 2047UL).to_int()
  let fraction = bits & 4503599627370495UL
  let (mantissa, exponent) = if encoded_exponent == 0 {
    (fraction, -1074)
  } else {
    (fraction + 4503599627370496UL, encoded_exponent - 1023 - 52)
  }
  let number = @bigint.BigInt::from_uint64(mantissa)
  let integer = if exponent >= 0 {
    number.shl(exponent)
  } else {
    number.shr(-exponent)
  }
  if bits >> 63 != 0UL {
    integer.neg()
  } else {
    integer
  }
}

///|
/// Scale through float multiplication and truncate each relative component
/// independently, including for factor=1. Absolute fields/leapdays/weekday
/// persist. Integer carries are exact before storing typed day/time components.
pub fn RelativeDelta::scaled(
  self : RelativeDelta,
  factor : Double,
) -> RelativeDelta raise DateError {
  relative_finite(factor)
  let mut years = relative_double_integer(self.years.to_double() * factor)
  let months = relative_double_integer(self.months.to_double() * factor)
  let mut days = relative_double_integer(self.days * factor)
  let mut hours = relative_double_integer(self.hours * factor)
  let mut minutes = relative_double_integer(self.minutes * factor)
  let mut seconds = relative_double_integer(self.seconds * factor)
  let microseconds = relative_double_integer(self.microseconds * factor)
  let million = @bigint.BigInt::from_int(1000000)
  let sixty = @bigint.BigInt::from_int(60)
  let twenty_four = @bigint.BigInt::from_int(24)
  let twelve = @bigint.BigInt::from_int(12)
  seconds = seconds + microseconds / million
  let microseconds = microseconds % million
  minutes = minutes + seconds / sixty
  let seconds = seconds % sixty
  hours = hours + minutes / sixty
  let minutes = minutes % sixty
  days = days + hours / twenty_four
  let hours = hours % twenty_four
  years = years + months / twelve
  let months = months % twelve
  if years.compare_int64(-9223372036854775808L) < 0 ||
    years.compare_int64(9223372036854775807L) > 0 {
    raise DateError::InvalidDate(message="scaled relative years overflow Int64")
  }
  let days = @string.parse_double(days.to_string()) catch {
    _ =>
      raise DateError::InvalidDate(
        message="scaled relative days overflow Double",
      )
  }
  relative_finite(days)
  self.rebuild(
    years.to_int64(),
    months.to_int64(),
    days,
    hours.to_int().to_double(),
    minutes.to_int().to_double(),
    seconds.to_int().to_double(),
    microseconds.to_int().to_double(),
  )
}

///|
/// Divide through the original reciprocal-and-multiply path. Each relative
/// component is truncated independently; absolute fields and leapdays persist.
pub fn RelativeDelta::divided(
  self : RelativeDelta,
  factor : Double,
) -> RelativeDelta raise DateError {
  if factor == 0.0 {
    raise DateError::InvalidDate(
      message="cannot divide a relative delta by zero",
    )
  }
  self.scaled(1.0 / factor)
}

///|
fn relative_checked_calendar(
  years : @bigint.BigInt,
  months : @bigint.BigInt,
) -> (Int64, Int64) raise DateError {
  let twelve = @bigint.BigInt::from_int(12)
  let years = years + months / twelve
  if years.compare_int64(-9223372036854775808L) < 0 ||
    years.compare_int64(9223372036854775807L) > 0 {
    raise DateError::InvalidDate(
      message="relative calendar arithmetic overflows Int64",
    )
  }
  (years.to_int64(), (months % twelve).to_int64())
}
