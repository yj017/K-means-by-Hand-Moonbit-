///|
// The named Asinh locator shares D24's mathematical nearest-even profile.
// Work with outward BigInt intervals; the separately recorded Darwin results
// are observations, not substitutions for these portable primitive values.
fn asinh_math_log_bounds(
  integer : @bigint.BigInt,
  exponent : Int32,
  precision : Int32,
) -> (@bigint.BigInt, @bigint.BigInt) {
  let one = @bigint.BigInt::from_int(1)
  let leading = integer.bit_length() - 1
  let scale = one << leading
  let power = @bigint.BigInt::from_int(exponent + leading)
  let (lo, hi) = log_grid_atanh_bounds(
    integer - scale,
    integer + scale,
    precision,
  )
  let (two_lo, two_hi) = log_grid_atanh_bounds(
    one,
    @bigint.BigInt::from_int(3),
    precision,
  )
  if power < @bigint.BigInt::from_int(0) {
    (lo + power * two_hi, hi + power * two_lo)
  } else {
    (lo + power * two_lo, hi + power * two_hi)
  }
}

///|
fn asinh_math_integer_sqrt(value : @bigint.BigInt) -> @bigint.BigInt {
  if value.is_zero() {
    return value
  }
  for current = @bigint.BigInt::from_int(1) << ((value.bit_length() + 1) / 2) {
    let next = (current + value / current) >> 1
    if next >= current {
      return current
    }
    continue next
  }
}

///|
fn asinh_math_asinh(value : Double) -> Double {
  if value.is_nan() || value.is_inf() || value == 0.0 {
    return value
  }
  let magnitude = Double::abs(value)
  // |asinh(x)-x| < |x|^3/6, below half an ulp throughout this range.
  if magnitude < 0.0000000037252902984619140625 {
    return value
  }
  let one = @bigint.BigInt::from_int(1)
  let (integer, unit) = index_binary_parts(magnitude)
  let square_unit = Int32::min(unit * 2, 0)
  let radicand = ((integer * integer) << (unit * 2 - square_unit)) +
    (one << -square_unit)
  for precision = 192 {
    // radicand*2^square_unit >= 1, so integer division here is floor.
    let root_top = (radicand.bit_length() - 1 + square_unit) / 2
    let root_unit = root_top - precision
    let shift = square_unit - root_unit * 2
    let scaled = if shift >= 0 { radicand << shift } else { radicand >> -shift }
    let root_lo = asinh_math_integer_sqrt(scaled)
    let exact = if shift >= 0 {
      root_lo * root_lo == scaled
    } else {
      (root_lo * root_lo) << -shift == radicand
    }
    let root_hi = if exact { root_lo } else { root_lo + one }
    let sum_unit = Int32::min(unit, root_unit)
    let x = integer << (unit - sum_unit)
    let sum_lo = x + (root_lo << (root_unit - sum_unit))
    let sum_hi = x + (root_hi << (root_unit - sum_unit))
    let (lo, _) = asinh_math_log_bounds(sum_lo, sum_unit, precision)
    let (_, hi) = asinh_math_log_bounds(sum_hi, sum_unit, precision)
    let lower = index_round_binary(lo, -precision)
    let upper = index_round_binary(hi, -precision)
    if lower.reinterpret_as_uint64() == upper.reinterpret_as_uint64() {
      return if value < 0.0 { -lower } else { lower }
    }
    continue precision * 2
  }
}

///|
// Enclose exp(x), 0 < x <= 1024, in units 2^-precision. Reduce exactly
// by 2^14 so t<=1/16, use Taylor bounds, then square fourteen times.
fn asinh_math_exp_bounds(
  value : Double,
  precision : Int32,
) -> (@bigint.BigInt, @bigint.BigInt) {
  let one = @bigint.BigInt::from_int(1)
  let scale = one << precision
  let (integer, unit) = index_binary_parts(value)
  let shift = unit - 14 + precision
  let (x_lo, x_hi) = if shift >= 0 {
    let exact = integer << shift
    (exact, exact)
  } else {
    let divisor = one << -shift
    (integer / divisor, (integer + divisor - one) / divisor)
  }
  let mut term_lo = scale
  let mut term_hi = scale
  let mut sum_lo = scale
  let mut sum_hi = scale
  for index = 1 {
    let denominator = scale * @bigint.BigInt::from_int(index)
    term_lo = term_lo * x_lo / denominator
    term_hi = (term_hi * x_hi + denominator - one) / denominator
    sum_lo += term_lo
    sum_hi += term_hi
    if index >= 2 && term_hi <= one {
      // Next/existing term ratio <= (1/16)/(index+1); the entire
      // remaining positive tail is strictly smaller than one scaled unit.
      sum_hi += one
      break
    }
    continue index + 1
  }
  for _ in 0..<14 {
    sum_lo = (sum_lo * sum_lo) >> precision
    sum_hi = (sum_hi * sum_hi + scale - one) >> precision
  }
  (sum_lo, sum_hi)
}

///|
fn asinh_math_sinh(value : Double) -> Double {
  if value.is_nan() || value.is_inf() || value == 0.0 {
    return value
  }
  let magnitude = Double::abs(value)
  // sinh(x)-x < x^3/5 for |x|<2^-28, again below half an ulp.
  if magnitude < 0.0000000037252902984619140625 {
    return value
  }
  if magnitude > 1024.0 {
    return if value < 0.0 { -1.0 / 0.0 } else { 1.0 / 0.0 }
  }
  let one = @bigint.BigInt::from_int(1)
  for precision = 192 {
    let (exp_lo, exp_hi) = asinh_math_exp_bounds(magnitude, precision)
    let numerator = one << (precision * 2)
    let inverse_lo = numerator / exp_hi
    let inverse_hi = (numerator + exp_lo - one) / exp_lo
    let lower = index_round_binary(exp_lo - inverse_hi, -precision - 1)
    let upper = index_round_binary(exp_hi - inverse_lo, -precision - 1)
    if lower.reinterpret_as_uint64() == upper.reinterpret_as_uint64() {
      return if value < 0.0 { -lower } else { lower }
    }
    continue precision * 2
  }
}

///|
fn asinh_math_log10(value : Double) -> Double {
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
  // Exactly representable powers of ten have integral logarithms.
  // Recognize them directly to avoid unnecessary interval evaluation.
  if value >= 10.0 {
    let (integer, unit) = index_binary_parts(value)
    if unit >= 0 {
      let mut exact = integer << unit
      let ten = @bigint.BigInt::from_int(10)
      let mut count = 0
      while exact % ten == @bigint.BigInt::from_int(0) {
        exact = exact / ten
        count += 1
      }
      if exact == @bigint.BigInt::from_int(1) {
        return count.to_double()
      }
    } else {
      // Normal integers below 2^52 still have a negative binary unit.
      let mask = @bigint.BigInt::from_int(1) << -unit
      if integer % mask == @bigint.BigInt::from_int(0) {
        let mut exact = integer / mask
        let ten = @bigint.BigInt::from_int(10)
        let mut count = 0
        while exact % ten == @bigint.BigInt::from_int(0) {
          exact = exact / ten
          count += 1
        }
        if exact == @bigint.BigInt::from_int(1) {
          return count.to_double()
        }
      }
    }
  }
  let (integer, unit) = index_binary_parts(value)
  let one = @bigint.BigInt::from_int(1)
  for precision = 192 {
    let (lo, hi) = asinh_math_log_bounds(integer, unit, precision)
    let (ten_lo, ten_hi) = asinh_math_log_bounds(
      @bigint.BigInt::from_int(10),
      0,
      precision,
    )
    let scale = one << precision
    // BigInt division truncates toward zero. Negate the negative numerator
    // first, so floor/ceil below only ever divide positive integers.
    let (ratio_lo, ratio_hi) = if value < 1.0 {
      let lower = hi.neg() * scale / ten_hi
      let upper = (lo.neg() * scale + ten_lo - one) / ten_lo
      (upper.neg(), lower.neg())
    } else {
      (lo * scale / ten_hi, (hi * scale + ten_lo - one) / ten_lo)
    }
    let lower = index_round_binary(ratio_lo, -precision)
    let upper = index_round_binary(ratio_hi, -precision)
    if lower.reinterpret_as_uint64() == upper.reinterpret_as_uint64() {
      return lower
    }
    continue precision * 2
  }
}
