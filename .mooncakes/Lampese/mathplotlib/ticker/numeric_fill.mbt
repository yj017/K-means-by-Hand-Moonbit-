// Exact binary64 primitives shared by Index and MaxN arange fill.

///|
// NumPy's pinned Darwin fill uses one fused multiply-add after its first two
// assignments. The index is already rounded from npy_intp to binary64.
fn numeric_arange_fill(start : Double, step : Double, index : Double) -> Double {
  let product = index * step
  if start == 0.0 {
    return product
  }
  if step == 0.0 {
    return start + product
  }
  if step.is_inf() || index.is_inf() || start.is_inf() || product.is_nan() {
    return start + product
  }
  let step_bits = step.reinterpret_as_uint64() & 0x7fffffffffffffffUL
  // Scaling by a normal power of two is exact when the product stays finite.
  if (step_bits & 0xfffffffffffffUL) == 0UL && !product.is_inf() {
    return start + product
  }
  let (start_integer, start_exponent) = index_binary_parts(start)
  let (step_integer, step_exponent) = index_binary_parts(step)
  let (index_integer, index_exponent) = index_binary_parts(index)
  let product_integer = step_integer * index_integer
  let product_exponent = step_exponent + index_exponent
  let exponent = Int32::min(start_exponent, product_exponent)
  index_round_binary(
    (start_integer << (start_exponent - exponent)) +
    (product_integer << (product_exponent - exponent)),
    exponent,
  )
}

///|
fn index_binary_parts(value : Double) -> (@bigint.BigInt, Int32) {
  let bits = value.reinterpret_as_uint64()
  let biased = ((bits >> 52) & 2047UL).to_int()
  let mantissa = if biased == 0 {
    bits & 0xfffffffffffffUL
  } else {
    (bits & 0xfffffffffffffUL) | 0x10000000000000UL
  }
  let integer = @bigint.BigInt::from_uint64(mantissa)
  let integer = if bits >> 63 == 0UL { integer } else { integer.neg() }
  (integer, if biased == 0 { -1074 } else { biased - 1075 })
}

///|
// Round an exact binary integer times a power of two once, ties to even.
// This supplies the fused fill profile observed in the pinned Darwin NumPy.
fn index_round_binary(integer : @bigint.BigInt, exponent : Int32) -> Double {
  if integer.is_zero() {
    return 0.0
  }
  let negative = integer < @bigint.BigInt::from_int(0)
  let integer = if negative { integer.neg() } else { integer }
  let top = integer.bit_length() - 1 + exponent
  let mut unit = Int32::max(top - 52, -1074)
  let shift = unit - exponent
  let mut rounded = if shift > 0 {
    let quotient = integer >> shift
    let remainder = integer - (quotient << shift)
    let half = @bigint.BigInt::from_int(1) << (shift - 1)
    if remainder > half ||
      (remainder == half && (quotient.to_uint64() & 1UL) != 0UL) {
      quotient + @bigint.BigInt::from_int(1)
    } else {
      quotient
    }
  } else {
    integer << -shift
  }
  if rounded.bit_length() > 53 {
    rounded = rounded >> 1
    unit += 1
  }
  let sign = if negative { 0x8000000000000000UL } else { 0UL }
  let bits = if unit > 971 {
    sign | 0x7ff0000000000000UL
  } else {
    let mantissa = rounded.to_uint64()
    if mantissa < 0x10000000000000UL {
      sign | mantissa
    } else {
      sign | ((unit + 1075).to_uint64() << 52) | (mantissa - 0x10000000000000UL)
    }
  }
  bits.reinterpret_as_int64().reinterpret_as_double()
}
