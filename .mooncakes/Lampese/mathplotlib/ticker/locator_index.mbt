///|
/// An index grid whose origin is the data minimum plus an offset.
/// Parameters retain all Double values; invalid ranges fail when queried.
pub struct IndexLocator {
  priv mut base : Double
  priv mut offset : Double
  priv mut data_interval : (() -> (Double, Double))?
}

///|
pub fn IndexLocator::new(base~ : Double, offset~ : Double) -> IndexLocator {
  { base, offset, data_interval: None, }
}

///|
pub fn IndexLocator::base(self : IndexLocator) -> Double {
  self.base
}

///|
pub fn IndexLocator::offset(self : IndexLocator) -> Double {
  self.offset
}

///|
pub fn IndexLocator::set_params(
  self : IndexLocator,
  base? : Double,
  offset? : Double,
) -> Unit {
  if base is Some(value) {
    self.base = value
  }
  if offset is Some(value) {
    self.offset = value
  }
}

///|
/// Copy the parameters while retaining the currently bound data provider.
pub fn IndexLocator::copy(self : IndexLocator) -> IndexLocator {
  { base: self.base, offset: self.offset, data_interval: self.data_interval, }
}

///|
/// Bind a source of data bounds. View limits do not replace this interval.
pub fn IndexLocator::bind_data_interval(
  self : IndexLocator,
  provider : () -> (Double, Double),
) -> Unit {
  self.data_interval = Some(provider)
}

///|
/// Query the current data interval, matching the source locator's call protocol.
pub fn IndexLocator::call(
  self : IndexLocator,
) -> Array[Double] raise @core.DataError {
  match self.data_interval {
    None =>
      raise @core.DataError::InvalidTicks(
        message="index locator is not bound to a data interval",
      )
    Some(provider) => {
      let (lower, upper) = provider()
      self.tick_values(lower, upper)
    }
  }
}

///|
/// Source arange semantics, retaining the first 100000 values of larger grids.
/// Bounds keep their incoming order. A negative base can produce descending ticks.
pub fn IndexLocator::tick_values(
  self : IndexLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  if self.base == 0.0 {
    raise @core.DataError::InvalidTicks(message="index locator step is zero")
  }
  let start = lower + self.offset
  let stop = upper + 1.0e-12
  let delta = stop - start
  let ratio = delta / self.base
  if ratio.is_nan() {
    raise @core.DataError::InvalidTicks(
      message="index locator cannot compute grid length",
    )
  }
  if ratio.is_inf() ||
    ratio < -9223372036854775808.0 ||
    ratio >= 9223372036854775808.0 {
    raise @core.DataError::InvalidTicks(
      message="index locator grid length exceeds supported size",
    )
  }
  let count = if ratio == 0.0 && delta != 0.0 {
    // NumPy preserves a positive underflowed quotient as one element.
    if ratio.reinterpret_as_uint64() >> 63 == 0UL {
      1.0
    } else {
      0.0
    }
  } else {
    ratio.ceil()
  }
  if count <= 0.0 {
    return []
  }
  // NumPy checks size * sizeof(double) against the signed pointer maximum.
  if count >= 1152921504606846976.0 {
    raise @core.DataError::InvalidTicks(
      message="index locator array exceeds supported size",
    )
  }
  let length = Double::min(count, 100000.0).to_int()
  let second = start + self.base
  let actual_step = second - start
  if length <= 2 || start == 0.0 || actual_step == 0.0 || actual_step.is_inf() {
    return Array::makei(length, index => {
      if index == 0 {
        start
      } else if index == 1 {
        second
      } else {
        start + Double::from_int(index) * actual_step
      }
    })
  }
  let (start_integer, start_exponent) = index_binary_parts(start)
  let (step_integer, step_exponent) = index_binary_parts(actual_step)
  let exponent = Int32::min(start_exponent, step_exponent)
  let start_integer = start_integer << (start_exponent - exponent)
  let step_integer = step_integer << (step_exponent - exponent)
  Array::makei(length, index => {
    if index == 0 {
      start
    } else if index == 1 {
      second
    } else {
      index_round_binary(
        start_integer + step_integer * @bigint.BigInt::from_int(index),
        exponent,
      )
    }
  })
}

///|
pub fn IndexLocator::nonsingular(
  _self : IndexLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.05)
}

///|
pub fn IndexLocator::view_limits(
  _self : IndexLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.001)
}
