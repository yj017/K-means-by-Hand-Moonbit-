///|
/// A normalized microsecond duration with Python timedelta's full day range.
/// The three components avoid overflowing a single Int64 microsecond count.
pub struct TimeDelta {
  priv days : Int32
  priv seconds : Int32
  priv microseconds : Int32
} derive(Eq, Compare, Debug)

///|
pub extend TimeDelta with Eq::{equal, not_equal}

///|
pub extend TimeDelta with Compare::{compare, op_lt, op_le, op_gt, op_ge}

///|
pub extend TimeDelta with @debug.Debug::{to_repr}

///|
fn delta_split(value : Int64, divisor : Int64) -> (Int64, Int64) {
  let quotient = value / divisor
  let remainder = value % divisor
  if remainder < 0L {
    (quotient - 1L, remainder + divisor)
  } else {
    (quotient, remainder)
  }
}

///|
fn normalized_timedelta(
  days : Int64,
  microseconds : Int64,
) -> TimeDelta raise DateError {
  let (extra_days, remainder) = delta_split(microseconds, 86_400_000_000L)
  let days = days + extra_days
  if days < -999999999L || days > 999999999L {
    raise DateError::InvalidDate(
      message="timedelta days are outside -999999999..999999999",
    )
  }
  {
    days: days.to_int(),
    seconds: (remainder / 1_000_000L).to_int(),
    microseconds: (remainder % 1_000_000L).to_int(),
  }
}

///|
/// Construct an exact integer-component duration. Components are normalized;
/// seconds and microseconds are nonnegative even when the duration is negative.
///
/// ```mbt check
/// test {
///   let delta = @date.timedelta(microseconds=-1L)
///   assert_eq(
///     (delta.days(), delta.seconds(), delta.microseconds()),
///     (-1, 86399, 999999),
///   )
///   assert_eq(delta.total_seconds(), -0.000001)
/// }
/// ```
pub fn timedelta(
  days~ : Int32 = 0,
  seconds~ : Int64 = 0L,
  microseconds~ : Int64 = 0L,
  milliseconds~ : Int64 = 0L,
  minutes~ : Int32 = 0,
  hours~ : Int32 = 0,
  weeks~ : Int32 = 0,
) -> TimeDelta raise DateError {
  let (second_days, second_rest) = delta_split(seconds, 86400L)
  let (micro_days, micro_rest) = delta_split(microseconds, 86_400_000_000L)
  let (milli_days, milli_rest) = delta_split(milliseconds, 86400000L)
  let (minute_days, minute_rest) = delta_split(Int64::from_int(minutes), 1440L)
  let (hour_days, hour_rest) = delta_split(Int64::from_int(hours), 24L)
  normalized_timedelta(
    Int64::from_int(days) +
    Int64::from_int(weeks) * 7L +
    second_days +
    micro_days +
    milli_days +
    minute_days +
    hour_days,
    second_rest * 1_000_000L +
    micro_rest +
    milli_rest * 1000L +
    minute_rest * 60_000_000L +
    hour_rest * 3_600_000_000L,
  )
}

///|
/// Convert a floating-point day count to a microsecond duration. Fractional
/// microseconds use round-half-to-even, matching datetime.timedelta(days=x).
/// NaN, infinity and durations outside the day range raise DateError.
///
/// ```mbt check
/// test {
///   let delta = @date.num2timedelta(1.5)
///   assert_eq((delta.days(), delta.seconds()), (1, 43200))
/// }
/// ```
pub fn num2timedelta(value : Double) -> TimeDelta raise DateError {
  if value.is_nan() ||
    value.is_inf() ||
    value <= -1000000000.0 ||
    value >= 1000000000.0 {
    raise DateError::InvalidDate(
      message="day count is not a finite representable timedelta",
    )
  }
  let days = value.to_int64()
  // The whole-day microsecond contribution is even. Rounding the fractional
  // contribution alone therefore preserves the parity of CPython's integer sum.
  let fraction = (value - days.to_double()) * 86_400_000_000.0
  normalized_timedelta(days, round_even_to_int64(fraction))
}

///|
/// Convert a floating-point day array, preserving order. Invalid elements
/// raise DateError; the input is never modified.
pub fn num2timedeltas(
  values : Array[Double],
) -> Array[TimeDelta] raise DateError {
  values.map(num2timedelta)
}

///|
pub fn TimeDelta::days(self : TimeDelta) -> Int32 {
  self.days
}

///|
pub fn TimeDelta::seconds(self : TimeDelta) -> Int32 {
  self.seconds
}

///|
pub fn TimeDelta::microseconds(self : TimeDelta) -> Int32 {
  self.microseconds
}

///|
/// Return total seconds as a float, retaining the sign of tiny negative values.
pub fn TimeDelta::total_seconds(self : TimeDelta) -> Double {
  let seconds = Int64::from_int(self.days) * 86400L +
    Int64::from_int(self.seconds)
  if seconds < 0L && self.microseconds != 0 {
    (seconds + 1L).to_double() +
    Double::from_int(self.microseconds - 1000000) / 1_000_000.0
  } else {
    seconds.to_double() + Double::from_int(self.microseconds) / 1_000_000.0
  }
}

///|
/// Add a duration in local calendar time, preserving all microsecond digits.
/// A retained rule zone resolves the new offset: folds choose the earlier
/// instant and gaps use dateutil's post-transition offset. Calendar overflow
/// raises DateError. Fixed offsets retain their original offset.
pub fn DateTime::add_timedelta(
  self : DateTime,
  delta : TimeDelta,
) -> DateTime raise DateError {
  self.add_timedelta_multiple(delta, 1L)
}

///|
fn DateTime::add_timedelta_multiple(
  self : DateTime,
  delta : TimeDelta,
  factor : Int64,
) -> DateTime raise DateError {
  let product = if factor == 0L {
    0L
  } else {
    // Any nonzero multiple of a larger duration cannot fit between two
    // supported local dates. Check this before converting the whole duration.
    if delta.days < -3652060 || delta.days > 3652060 {
      raise DateError::InvalidDate(
        message="date arithmetic overflows years 1..9999",
      )
    }
    let micros = Int64::from_int(delta.days) * 86_400_000_000L +
      Int64::from_int(delta.seconds) * 1_000_000L +
      Int64::from_int(delta.microseconds)
    if micros != 0L {
      let limit = 315_537_897_599_999_999L / micros.abs()
      if factor > limit || factor < -limit {
        raise DateError::InvalidDate(
          message="date arithmetic overflows years 1..9999",
        )
      }
    }
    micros * factor
  }
  let shifted = datetime_from_microseconds(
    locator_microseconds(self) + product,
    self.offset_seconds,
  )
  match self.timezone {
    Some(zone) => zone.resolve_arithmetic_local(shifted)
    None => shifted
  }
}
