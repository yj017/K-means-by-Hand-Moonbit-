///|
// Python/NumPy divmod snaps its approximate quotient to an integer and gives
// the remainder the positive denominator's sign. floor(value / step) differs.
pub fn divmod(value : Double, step : Double) -> (Double, Double) {
  let mut remainder = value % step
  let mut quotient = (value - remainder) / step
  if remainder != 0.0 {
    if remainder < 0.0 {
      remainder += step
      quotient -= 1.0
    }
  } else {
    remainder = 0.0
  }
  let floor = if quotient != 0.0 {
    let floor = quotient.floor()
    if quotient - floor > 0.5 {
      floor + 1.0
    } else {
      floor
    }
  } else if value.reinterpret_as_uint64() >> 63 != 0UL {
    -0.0
  } else {
    0.0
  }
  (floor, remainder)
}

///|
/// Edge_integer.ge with the zero internal tolerance offset used by MultipleLocator.
pub fn ge(value : Double, step : Double, offset~ : Double = 0.0) -> Double {
  let (quotient, remainder) = divmod(value, step)
  if Double::abs(remainder / step) < edge_tolerance(step, offset) {
    quotient
  } else {
    quotient + 1.0
  }
}

///|
/// Edge_integer.le with the zero internal tolerance offset used by MultipleLocator.
pub fn le(value : Double, step : Double, offset~ : Double = 0.0) -> Double {
  let (quotient, remainder) = divmod(value, step)
  if Double::abs(remainder / step - 1.0) < edge_tolerance(step, offset) {
    quotient + 1.0
  } else {
    quotient
  }
}

///|
fn edge_tolerance(step : Double, offset : Double) -> Double {
  if Double::abs(offset) > 0.0 {
    let digits = @math.log10(Double::abs(offset) / step)
    let proposed = @math.pow(10.0, digits - 12.0)
    let tolerance = if proposed > 1.0e-10 { proposed } else { 1.0e-10 }
    if tolerance < 0.4999 {
      tolerance
    } else {
      0.4999
    }
  } else {
    1.0e-10
  }
}

///|
/// Source-order ascending MultipleLocator grid, bounded to an eager prefix.
pub fn ticks(
  lower : Double,
  upper : Double,
  step : Double,
  offset~ : Double = 0.0,
) -> Array[Double] raise @core.DataError {
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="multiple grid bounds must be finite",
    )
  }
  let first = Double::min(lower, upper) - offset
  let last = Double::max(lower, upper) - offset
  let aligned = ge(first, step) * step
  if aligned.is_nan() || aligned.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="multiple grid alignment is not finite",
    )
  }
  let (count, _) = divmod(last - aligned + 0.001 * step, step)
  let count = count + 3.0
  if count.is_nan() || count.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="multiple tick count is not finite",
    )
  }
  let length = Double::max(0.0, Double::min(100000.0, count)).to_int()
  let base = aligned - step
  Array::makei(length, index => base + Double::from_int(index) * step + offset)
}
