///|
// exp of a nonnegative fixed-point interval, reduced exactly by 2^14.
// The accepted Asinh Taylor proof applies: reduced argument <1/16, outward
// term division and a one-unit tail enclosure, followed by fourteen squares.
fn scalar_math_exp_fixed(
  lower : @bigint.BigInt,
  upper : @bigint.BigInt,
  precision : Int32,
) -> LogPowerInterval {
  let one = @bigint.BigInt::from_int(1)
  let scale = one << precision
  let divisor = one << 14
  let a = lower / divisor
  let b = (upper + divisor - one) / divisor
  let mut term_lo = scale
  let mut term_hi = scale
  let mut sum_lo = scale
  let mut sum_hi = scale
  for index = 1 {
    let denominator = scale * @bigint.BigInt::from_int(index)
    term_lo = term_lo * a / denominator
    term_hi = (term_hi * b + denominator - one) / denominator
    sum_lo += term_lo
    sum_hi += term_hi
    if index >= 2 && term_hi <= one {
      sum_hi += one
      break
    }
    continue index + 1
  }
  for _ in 0..<14 {
    sum_lo = (sum_lo * sum_lo) >> precision
    sum_hi = (sum_hi * sum_hi + scale - one) >> precision
  }
  log_power_normalize(
    sum_lo,
    sum_hi,
    @bigint.BigInt::from_int(-precision),
    precision,
  )
}

///|
// Correctly rounded mathematical 10^x. Nonintegral binary64 x is a rational
// with power-of-two denominator; 10^x is irrational, so adaptive bounds cannot
// get stuck at an exact binary64 midpoint. Integer cases reuse D24's kernel.
fn scalar_math_pow10(value : Double) -> Double {
  if value.is_nan() {
    return value
  }
  if value == 0.0 {
    return 1.0
  }
  if value >= 309.0 {
    return 1.0 / 0.0
  }
  if value <= -324.0 {
    return 0.0
  }
  if value.floor() == value {
    return log_grid_integer_power(10.0, value)
  }
  let magnitude = Double::abs(value)
  if magnitude < 0.00000000000000001387778780781445675529539585113525390625 {
    return 1.0
  }
  let one = @bigint.BigInt::from_int(1)
  let (integer, unit) = index_binary_parts(magnitude)
  for precision = 192 {
    let (log_lo, log_hi) = asinh_math_log_bounds(
      @bigint.BigInt::from_int(10),
      0,
      precision,
    )
    let a = integer * log_lo
    let b = integer * log_hi
    let (lower, upper) = if unit >= 0 {
      (a << unit, b << unit)
    } else {
      let divisor = one << -unit
      (a / divisor, (b + divisor - one) / divisor)
    }
    let exp = scalar_math_exp_fixed(lower, upper, precision)
    let result = if value < 0.0 { exp.reciprocal(precision) } else { exp }
    let lo = log_power_bound_round(result.lower, result.unit)
    let hi = log_power_bound_round(result.upper, result.unit)
    if lo.reinterpret_as_uint64() == hi.reinterpret_as_uint64() {
      return lo
    }
    continue precision * 2
  }
}

///|
fn scalar_math_integer_power10(
  value : @bigint.BigInt,
) -> @bigint.BigInt raise @core.DataError {
  // 10^n >= 2^(3n). Above this proven boundary the result cannot have the
  // Int32 bit_length required by the existing BigInt representation/helpers.
  if value >= @bigint.BigInt::from_int(715827883) {
    raise @core.DataError::InvalidTicks(
      message="ResourceError: decimal power exceeds BigInt bit addressability",
    )
  }
  @bigint.BigInt::from_int(10).pow(value)
}

///|
fn scalar_math_power10(
  exponent : ScalarNumber,
  float_base~ : Bool,
) -> ScalarNumber raise @core.DataError {
  if !float_base && exponent is (NumpyInt64(_) | NumpyBool(_)) {
    let n = scalar_numeric_integer(exponent)
    if n < @bigint.BigInt::from_int(0) {
      raise @core.DataError::InvalidTicks(
        message="ValueError: Integers to negative integer powers are not allowed.",
      )
    }
    let mut remaining = n.to_uint64()
    let mut factor = 10UL
    let mut result = 1UL
    while remaining != 0UL {
      if (remaining & 1UL) != 0UL {
        result *= factor
      }
      remaining = remaining >> 1
      if remaining != 0UL {
        factor *= factor
      }
    }
    return ScalarNumber::NumpyInt64(result.reinterpret_as_int64())
  }
  if !float_base && exponent is (Integer(_) | Boolean(_)) {
    let integer = scalar_numeric_integer(exponent)
    if integer >= @bigint.BigInt::from_int(0) {
      return ScalarNumber::Integer(scalar_math_integer_power10(integer))
    }
  }
  let value = scalar_numeric_double(exponent)
  let result = scalar_math_pow10(value)
  let numpy = scalar_numeric_numpy(exponent)
  if !numpy && !value.is_inf() && !value.is_nan() && result.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="OverflowError: (34, 'Result too large')",
    )
  }
  if numpy {
    ScalarNumber::NumpyFloat64(result)
  } else {
    ScalarNumber::Number(result)
  }
}

///|
fn scalar_math_log10(value : ScalarNumber) -> Double raise @core.DataError {
  match value {
    Integer(integer) => {
      if integer <= @bigint.BigInt::from_int(0) {
        raise @core.DataError::InvalidTicks(
          message="ValueError: math domain error",
        )
      }
      let one = @bigint.BigInt::from_int(1)
      for precision = 192 {
        let (lo, hi) = asinh_math_log_bounds(integer, 0, precision)
        let (ten_lo, ten_hi) = asinh_math_log_bounds(
          @bigint.BigInt::from_int(10),
          0,
          precision,
        )
        let scale = one << precision
        let lower = index_round_binary(lo * scale / ten_hi, -precision)
        let upper = index_round_binary(
          (hi * scale + ten_lo - one) / ten_lo,
          -precision,
        )
        if lower.reinterpret_as_uint64() == upper.reinterpret_as_uint64() {
          return lower
        }
        continue precision * 2
      }
    }
    _ => {
      let number = scalar_numeric_double(value)
      if number <= 0.0 {
        raise @core.DataError::InvalidTicks(
          message="ValueError: math domain error",
        )
      }
      asinh_math_log10(number)
    }
  }
}

///|
fn scalar_math_rint(value : Double) -> Double {
  if value.is_inf() || value.is_nan() || value == 0.0 {
    return value
  }
  let rounded = try! auto_minor_round(value)
  if rounded.is_zero() {
    return if value < 0.0 { -0.0 } else { 0.0 }
  }
  index_round_binary(rounded, 0)
}

///|
// Pinned NumPy calculation.c power_of_ten, deliberately repeated multiplication
// rather than a single correctly rounded power. Final decimal text remains D29.
fn scalar_math_numpy_round(value : Double, decimals : Int32) -> Double {
  if decimals == 0 {
    return scalar_math_rint(value)
  }
  let count = Int32::abs(decimals)
  let mut factor = match count {
    0 => 1.0
    1 => 10.0
    2 => 100.0
    3 => 1000.0
    4 => 10000.0
    5 => 100000.0
    6 => 1000000.0
    7 => 10000000.0
    8 => 100000000.0
    _ => 1000000000.0
  }
  if count > 9 {
    for _ in 9..<count {
      factor *= 10.0
    }
  }
  if decimals > 0 {
    let scaled = value * factor
    let rounded = scalar_math_rint(scaled)
    rounded / factor
  } else {
    let scaled = value / factor
    let rounded = scalar_math_rint(scaled)
    rounded * factor
  }
}

///|
fn scalar_math_round_digits(
  value : ScalarNumber,
  digits : Int32,
) -> ScalarNumber raise @core.DataError {
  let number = scalar_numeric_double(value)
  if scalar_numeric_numpy(value) {
    return ScalarNumber::NumpyFloat64(scalar_math_numpy_round(number, digits))
  }
  if number.is_nan() || number.is_inf() || number == 0.0 {
    return ScalarNumber::Number(number)
  }
  let integer = decimal_round(number, digits)
  let integer = if number < 0.0 { integer.neg() } else { integer }
  let rounded = if integer.is_zero() {
    if number < 0.0 {
      -0.0
    } else {
      0.0
    }
  } else if digits >= 0 {
    log_grid_integer_ratio(integer, decimal_power(digits))
  } else {
    index_round_binary(integer * decimal_power(-digits), 0)
  }
  ScalarNumber::Number(rounded)
}

///|
fn scalar_math_round_ten(
  value : ScalarNumber,
) -> ScalarNumber raise @core.DataError {
  scalar_math_round_digits(value, 10)
}

///|
// NumPy spacing resolves a Boolean input to its first supported floating
// ufunc loop, float16 (11 significant bits), rather than to float64. Other
// admitted numeric scalar types select the float64 loop. Preserve that dtype
// resolution before computing the adjacent representable value.
fn scalar_math_spacing(value : ScalarNumber) -> Double raise @core.DataError {
  match value {
    Boolean(value) | NumpyBool(value) =>
      if value {
        0.0009765625
      } else {
        0.000000059604644775390625
      }
    _ => {
      let value = scalar_numeric_double(value)
      if value.is_inf() || value.is_nan() {
        return 0.0 / 0.0
      }
      let magnitude = Double::abs(value)
      let next = (magnitude.reinterpret_as_uint64() + 1UL).reinterpret_as_double()
      let spacing = next - magnitude
      if value < 0.0 {
        -spacing
      } else {
        spacing
      }
    }
  }
}
