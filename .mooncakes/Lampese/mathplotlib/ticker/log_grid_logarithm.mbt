///|
// Enclose 2*atanh(numerator/denominator), with 0<=z<=1/3, in integer
// multiples of 2^-precision. Every product and quotient is directed outward.
fn log_grid_atanh_bounds(
  numerator : @bigint.BigInt,
  denominator : @bigint.BigInt,
  precision : Int32,
) -> (@bigint.BigInt, @bigint.BigInt) {
  if numerator.is_zero() {
    return (numerator, numerator)
  }
  let one = @bigint.BigInt::from_int(1)
  let scale = one << precision
  let lower_z = numerator * scale / denominator
  let upper_z = (numerator * scale + denominator - one) / denominator
  let lower_square = (lower_z * lower_z) >> precision
  let upper_square = (upper_z * upper_z + scale - one) >> precision
  let mut lower_term = lower_z
  let mut upper_term = upper_z
  let mut lower_sum = @bigint.BigInt::from_int(0)
  let mut upper_sum = @bigint.BigInt::from_int(0)
  let count = (precision + 4) / 3
  for index in 0..<count {
    let odd = @bigint.BigInt::from_int(index * 2 + 1)
    lower_sum += lower_term / odd
    upper_sum += (upper_term + odd - one) / odd
    lower_term = (lower_term * lower_square) >> precision
    upper_term = (upper_term * upper_square + scale - one) >> precision
  }
  // Remaining exact terms are less than 3*(1/9)^count < 2^-precision.
  (lower_sum << 1, (upper_sum << 1) + one)
}

///|
// This private Log helper uses mathematical nearest-even rounding uniformly
// across targets. Darwin NumPy/libm profile observations remain separate in
// testdata/log_grid_logarithm_reference.json, including any source differences.
fn log_grid_natural_log(value : Double) -> Double {
  if value.is_nan() || value == 1.0 / 0.0 {
    return value
  }
  if value == 0.0 {
    return -1.0 / 0.0
  }
  if value < 0.0 {
    return 0.0 / 0.0
  }
  if value == 1.0 {
    return 0.0
  }
  let (integer, exponent) = index_binary_parts(value)
  let leading = integer.bit_length() - 1
  let scale = @bigint.BigInt::from_int(1) << leading
  let power = @bigint.BigInt::from_int(exponent + leading)
  for precision = 192 {
    let (mantissa_lower, mantissa_upper) = log_grid_atanh_bounds(
      integer - scale,
      integer + scale,
      precision,
    )
    let (two_lower, two_upper) = log_grid_atanh_bounds(
      @bigint.BigInt::from_int(1),
      @bigint.BigInt::from_int(3),
      precision,
    )
    let (lower, upper) = if power < @bigint.BigInt::from_int(0) {
      (mantissa_lower + power * two_upper, mantissa_upper + power * two_lower)
    } else {
      (mantissa_lower + power * two_lower, mantissa_upper + power * two_upper)
    }
    let lower = index_round_binary(lower, -precision)
    let upper = index_round_binary(upper, -precision)
    if lower.reinterpret_as_uint64() == upper.reinterpret_as_uint64() {
      return lower
    }
    continue precision * 2
  }
}
