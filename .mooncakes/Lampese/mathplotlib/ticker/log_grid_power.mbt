///|
// Positive directed bounds share a binary unit. BigInt units avoid an
// artificial exponent limit when a finite Double exponent is itself huge.
priv struct LogPowerInterval {
  lower : @bigint.BigInt
  upper : @bigint.BigInt
  unit : @bigint.BigInt
}

///|
fn log_power_normalize(
  lower : @bigint.BigInt,
  upper : @bigint.BigInt,
  unit : @bigint.BigInt,
  precision : Int32,
) -> LogPowerInterval {
  let mut lower = lower
  let mut upper = upper
  let mut unit = unit
  while upper.bit_length() > precision {
    let shift = upper.bit_length() - precision
    lower = lower >> shift
    upper = (
        upper +
        (@bigint.BigInt::from_int(1) << shift) -
        @bigint.BigInt::from_int(1)
      ) >>
      shift
    unit += @bigint.BigInt::from_int(shift)
  }
  { lower, upper, unit, }
}

///|
fn LogPowerInterval::multiply(
  self : LogPowerInterval,
  other : LogPowerInterval,
  precision : Int32,
) -> LogPowerInterval {
  log_power_normalize(
    self.lower * other.lower,
    self.upper * other.upper,
    self.unit + other.unit,
    precision,
  )
}

///|
fn LogPowerInterval::reciprocal(
  self : LogPowerInterval,
  precision : Int32,
) -> LogPowerInterval {
  let numerator = @bigint.BigInt::from_int(1) << (precision * 2)
  log_power_normalize(
    numerator / self.upper,
    (numerator + self.lower - @bigint.BigInt::from_int(1)) / self.lower,
    self.unit.neg() - @bigint.BigInt::from_int(precision * 2),
    precision,
  )
}

///|
fn log_power_bound_round(
  mantissa : @bigint.BigInt,
  unit : @bigint.BigInt,
) -> Double {
  if mantissa.is_zero() {
    return 0.0
  }
  let top = unit + @bigint.BigInt::from_int(mantissa.bit_length() - 1)
  if top > @bigint.BigInt::from_int(1024) {
    return 1.0 / 0.0
  }
  if top < @bigint.BigInt::from_int(-1075) {
    return 0.0
  }
  index_round_binary(mantissa, unit.to_int())
}

///|
fn log_power_large(interval : LogPowerInterval) -> Bool {
  !interval.lower.is_zero() &&
  interval.unit + @bigint.BigInt::from_int(interval.lower.bit_length() - 1) >
  @bigint.BigInt::from_int(1024)
}

///|
fn log_power_small(interval : LogPowerInterval) -> Bool {
  interval.unit + @bigint.BigInt::from_int(interval.upper.bit_length() - 1) <
  @bigint.BigInt::from_int(-1075)
}

///|
// Correctly rounded integer powers, proved by outward-rounded bounds rather
// than a target's libm approximation. Every retry starts from the exact base.
// The mathematical rounding contract deliberately differs from occasional
// non-correctly-rounded Darwin libm results. Original and mathematical bits
// are both recorded by scripts/generate_log_grid_power_reference.py and
// testdata/log_grid_power_reference.json; no fixture-specific correction is used.
fn log_grid_integer_power(base : Double, exponent : Double) -> Double {
  let negative = base < 0.0 && exponent % 2.0 != 0.0
  let magnitude = Double::abs(base)
  if magnitude == 1.0 {
    return if negative { -1.0 } else { 1.0 }
  }
  let (base_integer, base_unit) = index_binary_parts(magnitude)
  let (exponent_integer, exponent_unit) = index_binary_parts(
    Double::abs(exponent),
  )
  let exponent_integer = if exponent_unit >= 0 {
    exponent_integer << exponent_unit
  } else {
    exponent_integer >> -exponent_unit
  }
  let growing = (magnitude > 1.0) != (exponent < 0.0)
  for precision = 192 {
    let initial = LogPowerInterval::{
      lower: base_integer,
      upper: base_integer,
      unit: @bigint.BigInt::from_int(base_unit),
    }
    let mut factor = if exponent < 0.0 {
      initial.reciprocal(precision)
    } else {
      initial
    }
    let mut accumulated = LogPowerInterval::{
      lower: @bigint.BigInt::from_int(1),
      upper: @bigint.BigInt::from_int(1),
      unit: @bigint.BigInt::from_int(0),
    }
    let mut remaining = exponent_integer
    while !remaining.is_zero() {
      if growing && log_power_large(factor) {
        return if negative { -1.0 / 0.0 } else { 1.0 / 0.0 }
      }
      if !growing && log_power_small(factor) {
        return if negative { -0.0 } else { 0.0 }
      }
      if remaining % @bigint.BigInt::from_int(2) != @bigint.BigInt::from_int(0) {
        accumulated = accumulated.multiply(factor, precision)
      }
      remaining = remaining >> 1
      if !remaining.is_zero() {
        factor = factor.multiply(factor, precision)
      }
    }
    let lower = log_power_bound_round(accumulated.lower, accumulated.unit)
    let upper = log_power_bound_round(accumulated.upper, accumulated.unit)
    if lower.reinterpret_as_uint64() == upper.reinterpret_as_uint64() {
      return if negative { -lower } else { lower }
    }
    continue precision * 2
  }
}
