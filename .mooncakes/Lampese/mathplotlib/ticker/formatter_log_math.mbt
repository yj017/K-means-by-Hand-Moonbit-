///|
fn log_format_error(message : String) -> @core.DataError {
  @core.DataError::InvalidTicks(message~)
}

///|
fn log_format_round(value : Double) -> @bigint.BigInt raise @core.DataError {
  if value.is_nan() {
    raise log_format_error("ValueError: cannot convert float NaN to integer")
  }
  if value.is_inf() {
    raise log_format_error(
      "OverflowError: cannot convert float infinity to integer",
    )
  }
  auto_minor_round(value)
}

///|
fn log_format_close(value : Double) -> Bool raise @core.DataError {
  let rounded = index_round_binary(log_format_round(value), 0)
  let difference = Double::abs(value - rounded)
  value == rounded ||
  difference <= 1.0e-9 * Double::abs(rounded) ||
  difference <= 1.0e-9 * Double::abs(value)
}

///|
fn log_format_next_down(value : Double) -> Double {
  if value.is_nan() || value == -1.0 / 0.0 {
    return value
  }
  if value == 0.0 {
    return -5.0e-324
  }
  let bits = value.reinterpret_as_uint64()
  (if value > 0.0 { bits - 1UL } else { bits + 1UL }).reinterpret_as_double()
}

///|
fn log_format_log(
  value : ScalarNumber,
  base : Double,
) -> Double raise @core.DataError {
  let numerator = eng_math_natural_log(value)
  let denominator = eng_math_natural_log(ScalarNumber::Number(base))
  if denominator == 0.0 {
    raise log_format_error("ZeroDivisionError: float division by zero")
  }
  numerator / denominator
}

///|
fn log_format_floor_div(
  n : @bigint.BigInt,
  d : @bigint.BigInt,
) -> @bigint.BigInt {
  let quotient = n / d
  if n < @bigint.BigInt::from_int(0) && n % d != @bigint.BigInt::from_int(0) {
    quotient - @bigint.BigInt::from_int(1)
  } else {
    quotient
  }
}

///|
fn log_format_ceil_div(
  n : @bigint.BigInt,
  d : @bigint.BigInt,
) -> @bigint.BigInt {
  log_format_floor_div(n.neg(), d).neg()
}

///|
// A dyadic exponent gives a rational result precisely when the odd mantissa
// is a perfect 2^q-th power and the binary unit is divisible by 2^q. Resolve
// those exact cases first, including potential binary64 rounding midpoints.
fn log_format_rational_power(base : Double, exponent : Double) -> Double? {
  let one = @bigint.BigInt::from_int(1)
  let two = @bigint.BigInt::from_int(2)
  let (raw, raw_unit) = index_binary_parts(base)
  let mut mantissa = raw
  let mut unit = raw_unit
  while mantissa % two == @bigint.BigInt::from_int(0) {
    mantissa = mantissa >> 1
    unit += 1
  }
  let (raw_exp, raw_exp_unit) = index_binary_parts(exponent)
  let mut numerator = raw_exp
  let mut exponent_unit = raw_exp_unit
  while numerator % two == @bigint.BigInt::from_int(0) {
    numerator = numerator >> 1
    exponent_unit += 1
  }
  if exponent_unit >= 0 {
    return None
  }
  let q = -exponent_unit
  if q >= 31 {
    return None
  }
  let degree = 1 << q
  if unit % degree != 0 {
    return None
  }
  let root = if mantissa == one {
    one
  } else {
    if q > 5 {
      return None
    }
    let mut lower = one
    let mut upper = (one << ((mantissa.bit_length() + degree - 1) / degree)) +
      one
    while upper - lower > one {
      let middle = (lower + upper) >> 1
      if middle.pow(@bigint.BigInt::from_int(degree)) <= mantissa {
        lower = middle
      } else {
        upper = middle
      }
    }
    if lower.pow(@bigint.BigInt::from_int(degree)) != mantissa {
      return None
    }
    lower
  }
  let root = index_round_binary(root, unit / degree)
  Some(log_grid_integer_power(root, index_round_binary(numerator, 0)))
}

///|
// Correctly rounded positive-base fractional powers. The exact-rational
// cases above terminate by integer bounds; all remaining cases are irrational
// and therefore cannot coincide with a binary64 midpoint. Source libm and
// mathematical values are recorded separately by the D33 reference generator.
fn log_format_positive_power(base : Double, exponent : Double) -> Double {
  if exponent == 0.0 || base == 1.0 {
    return 1.0
  }
  if base.is_nan() || exponent.is_nan() {
    return 0.0 / 0.0
  }
  if base == 0.0 {
    return if exponent < 0.0 { 1.0 / 0.0 } else { 0.0 }
  }
  if base == 1.0 / 0.0 {
    return if exponent < 0.0 { 0.0 } else { base }
  }
  if exponent.is_inf() {
    return if (base > 1.0) != (exponent < 0.0) { 1.0 / 0.0 } else { 0.0 }
  }
  if exponent.floor() == exponent {
    return log_grid_integer_power(base, exponent)
  }
  if log_format_rational_power(base, exponent) is Some(value) {
    return value
  }
  let one = @bigint.BigInt::from_int(1)
  let (base_integer, base_unit) = index_binary_parts(base)
  let (exponent_integer, exponent_unit) = index_binary_parts(exponent)
  for precision = 192 {
    let (a, b) = asinh_math_log_bounds(base_integer, base_unit, precision)
    let (a, b) = if exponent_integer < @bigint.BigInt::from_int(0) {
      (b * exponent_integer, a * exponent_integer)
    } else {
      (a * exponent_integer, b * exponent_integer)
    }
    let (lower, upper) = if exponent_unit >= 0 {
      (a << exponent_unit, b << exponent_unit)
    } else {
      let divisor = one << -exponent_unit
      (log_format_floor_div(a, divisor), log_format_ceil_div(b, divisor))
    }
    let bound = @bigint.BigInt::from_int(800) << precision
    if lower > bound {
      return 1.0 / 0.0
    }
    if upper < bound.neg() {
      return 0.0
    }
    if lower < bound.neg() || upper > bound {
      continue precision * 2
    }
    let negative = upper < @bigint.BigInt::from_int(0)
    if lower < @bigint.BigInt::from_int(0) && !negative {
      continue precision * 2
    }
    let result = if negative {
      scalar_math_exp_fixed(upper.neg(), lower.neg(), precision).reciprocal(
        precision,
      )
    } else {
      scalar_math_exp_fixed(lower, upper, precision)
    }
    let a = log_power_bound_round(result.lower, result.unit)
    let b = log_power_bound_round(result.upper, result.unit)
    if a.reinterpret_as_uint64() == b.reinterpret_as_uint64() {
      return a
    }
    continue precision * 2
  }
}

///|
fn log_format_power(
  base : Double,
  exponent : ScalarNumber,
) -> Double raise @core.DataError {
  let value = scalar_numeric_double(exponent)
  let result = log_format_positive_power(base, value)
  if !scalar_numeric_numpy(exponent) &&
    base != 0.0 &&
    !base.is_inf() &&
    !value.is_inf() &&
    result.is_inf() {
    raise log_format_error(
      "OverflowError: (34, 'Numerical result out of range')",
    )
  }
  result
}

///|
fn log_format_isfinite(
  value : ScalarNumber,
  operation : String,
) -> Bool raise @core.DataError {
  if value is Integer(integer) {
    if integer < @bigint.BigInt::from_int64(-9223372036854775808L) ||
      integer > @bigint.BigInt::from_uint64(18446744073709551615UL) {
      raise log_format_error(
        "TypeError: ufunc '" +
        operation +
        "' not supported for the input types, and the inputs could not be safely coerced to any supported types according to the casting rule ''safe''",
      )
    }
    return true
  }
  let number = scalar_numeric_double(value)
  !number.is_nan() && !number.is_inf()
}
