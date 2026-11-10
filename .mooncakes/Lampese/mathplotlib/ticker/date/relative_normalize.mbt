///|
// Round the exact binary64 value to a decimal quantum, then convert the decimal
// back to binary64. This mirrors CPython's correctly rounded dtoa/strtod path;
// multiplying a Double by 10^digits first can turn a near-tie into a false tie.
fn relative_decimal_round(
  value : Double,
  digits : Int32,
) -> Double raise DateError {
  relative_finite(value)
  if digits < 0 || digits > 11 {
    raise DateError::InvalidDate(
      message="relative decimal precision is out of range",
    )
  }
  if value == 0.0 {
    return value
  }
  let bits = value.reinterpret_as_uint64()
  let negative = bits >> 63 != 0UL
  let encoded_exponent = ((bits >> 52) & 2047UL).to_int()
  let fraction = bits & 4503599627370495UL
  let (mantissa, exponent) = if encoded_exponent == 0 {
    (fraction, -1074)
  } else {
    (fraction + 4503599627370496UL, encoded_exponent - 1023 - 52)
  }
  let mut scale = 1L
  for _ in 0..<digits {
    scale *= 10L
  }
  let numerator = @bigint.BigInt::from_uint64(mantissa) *
    @bigint.BigInt::from_int64(scale)
  let (numerator, denominator) = if exponent >= 0 {
    (numerator.shl(exponent), @bigint.BigInt::from_int(1))
  } else {
    (numerator, @bigint.BigInt::from_int(1).shl(-exponent))
  }
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  let comparison = (remainder + remainder).compare(denominator)
  let rounded = if comparison > 0 ||
    (comparison == 0 && !(quotient % @bigint.BigInt::from_int(2)).is_zero()) {
    quotient + @bigint.BigInt::from_int(1)
  } else {
    quotient
  }
  let text = (if negative { "-" } else { "" }) +
    rounded.to_string() +
    "e-" +
    digits.to_string()
  let result = @string.parse_double(text) catch {
    _ =>
      raise DateError::InvalidDate(message="relative decimal conversion failed")
  }
  relative_finite(result)
  result
}

///|
fn relative_integer_double(value : Double) -> Double {
  if value == 0.0 {
    0.0
  } else {
    value.trunc()
  }
}

///|
/// Return integer-valued relative day/time components using dateutil's staged
/// decimal rounding. Absolute fields, leapdays and weekday remain unchanged.
///
/// ```mbt check
/// test {
///   let delta = @date.RelativeDelta::new(days=1.5, hours=2.0).normalized()
///   assert_eq((delta.days(), delta.hours()), (1.0, 14.0))
///   let next = @date.datetime(2024, 1, 31).add_relative_delta(
///     @date.RelativeDelta::new(months=1L),
///   )
///   assert_eq((next.month(), next.day()), (2, 29))
/// }
/// ```
pub fn RelativeDelta::normalized(
  self : RelativeDelta,
) -> RelativeDelta raise DateError {
  let days = relative_integer_double(self.days)
  let hours_f = relative_decimal_round(
    self.hours + 24.0 * (self.days - days),
    11,
  )
  let hours = relative_integer_double(hours_f)
  let minutes_f = relative_decimal_round(
    self.minutes + 60.0 * (hours_f - hours),
    10,
  )
  let minutes = relative_integer_double(minutes_f)
  let seconds_f = relative_decimal_round(
    self.seconds + 60.0 * (minutes_f - minutes),
    8,
  )
  let seconds = relative_integer_double(seconds_f)
  let microseconds = round_even_to_int64(
    self.microseconds + 1000000.0 * (seconds_f - seconds),
  )
  RelativeDelta::new(
    years=self.years,
    months=Int64::from_int(self.months),
    days~,
    hours~,
    minutes~,
    seconds~,
    microseconds=microseconds.to_double(),
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
