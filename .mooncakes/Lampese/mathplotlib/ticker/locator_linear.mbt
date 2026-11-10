///|
/// Mutable NumPy-style evenly spaced ticks and shared exact-bound presets.
pub struct LinearLocator {
  priv mut configured_count : Int32?
  priv mut preset_values : LinearLocatorPresets
}

///|
/// The omitted count stays unset; its effective value is always eleven.
pub fn LinearLocator::new(
  numticks? : Int32,
  presets? : LinearLocatorPresets,
) -> LinearLocator {
  {
    configured_count: numticks,
    preset_values: presets.unwrap_or_else(LinearLocatorPresets::new),
  }
}

///|
pub fn LinearLocator::numticks(self : LinearLocator) -> Int32 {
  self.configured_count.unwrap_or(11)
}

///|
pub fn LinearLocator::configured_numticks(self : LinearLocator) -> Int32? {
  self.configured_count
}

///|
/// Set the public count property; None restores the effective default eleven.
pub fn LinearLocator::set_numticks(
  self : LinearLocator,
  numticks : Int32?,
) -> Unit {
  self.configured_count = numticks
}

///|
pub fn LinearLocator::presets(self : LinearLocator) -> LinearLocatorPresets {
  self.preset_values
}

///|
/// Omitted parameters retain their values. Preset storage is shared by reference.
pub fn LinearLocator::set_params(
  self : LinearLocator,
  numticks? : Int32,
  presets? : LinearLocatorPresets,
) -> Unit {
  if presets is Some(value) {
    self.preset_values = value
  }
  if numticks is Some(value) {
    self.configured_count = Some(value)
  }
}

///|
/// A shallow copy: count updates are independent and preset storage stays shared.
pub fn LinearLocator::copy(self : LinearLocator) -> LinearLocator {
  {
    configured_count: self.configured_count,
    preset_values: self.preset_values,
  }
}

///|
/// Normalize the bounds before matching presets or evaluating the configured count.
pub fn LinearLocator::tick_values(
  self : LinearLocator,
  lower : Double,
  upper : Double,
) -> TickValues raise @core.DataError {
  let (first, last) = locator_nonsingular(lower, upper, 0.05)
  if self.preset_values.get(first, last) is Some(values) {
    return values
  }
  let count = self.numticks()
  if count < 0 {
    raise @core.DataError::InvalidTicks(
      message="linear locator sample count must be nonnegative",
    )
  }
  let length = Int32::min(count, 100000)
  let delta = last - first
  let divisor = count - 1
  let values = if divisor > 0 {
    let divisor = Double::from_int(divisor)
    let step = delta / divisor
    if step == 0.0 {
      Array::makei(length, index => {
        Double::from_int(index) / divisor * delta + first
      })
    } else {
      Array::makei(length, index => Double::from_int(index) * step + first)
    }
  } else {
    Array::makei(length, index => Double::from_int(index) * delta + first)
  }
  if count > 1 && length == count {
    values[length - 1] = last
  }
  TickValues::from_array(values)
}

///|
pub fn LinearLocator::nonsingular(
  _self : LinearLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.05)
}

///|
/// Apply source decimal rounding when axes.autolimit_mode is round_numbers.
pub fn LinearLocator::view_limits(
  self : LinearLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  let mut first = lower
  let mut last = upper
  if last < first {
    let temporary = first
    first = last
    last = temporary
  }
  if first == last {
    first -= 1.0
    last += 1.0
  }
  if @config.axes_autolimit_mode() == "round_numbers" {
    let span = last - first
    if span <= 0.0 {
      raise @core.DataError::InvalidTicks(
        message="linear locator rounding logarithm is undefined",
      )
    }
    let numerator = @math.log10(span)
    // Compute the subtraction only after this comparison, avoiding Int32.min - 1.
    let base = if self.numticks() <= 2 {
      raise @core.DataError::InvalidTicks(
        message="linear locator rounding divisor is zero",
      )
    } else {
      Double::from_int(self.numticks() - 1)
    }
    let denominator = @math.log10(base)
    let (exponent, remainder) = @tick_grid.divmod(numerator, denominator)
    let exponent = exponent - (if remainder < 0.5 { 1.0 } else { 0.0 })
    let scale = @math.pow(base, -exponent)
    if scale.is_nan() || scale.is_inf() || scale == 0.0 {
      raise @core.DataError::InvalidTicks(
        message="linear locator rounding scale is undefined",
      )
    }
    let scaled_first = scale * first
    let scaled_last = scale * last
    if scaled_first.is_nan() ||
      scaled_first.is_inf() ||
      scaled_last.is_nan() ||
      scaled_last.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="linear locator rounded endpoint is not finite",
      )
    }
    first = scaled_first.floor() / scale
    last = scaled_last.ceil() / scale
  }
  locator_nonsingular(first, last, 0.001)
}
