///|
/// Mutable fixed spacing and offset. Adapters share this handle; copy() is independent.
pub struct MultipleLocator {
  priv mut base : Double
  priv mut offset : Double
}

///|
fn validate_multiple(
  base : Double,
  offset : Double,
) -> Unit raise @core.DataError {
  if base.is_nan() || base.is_inf() || base <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="multiple locator base must be finite and positive",
    )
  }
  if offset.is_nan() || offset.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="multiple locator offset must be finite",
    )
  }
}

///|
/// Fixed spacing with a phase offset, retaining outer neighboring ticks.
///
/// ```mbt check
/// test {
///   let locator = @ticker.MultipleLocator::new(base=2.0, offset=1.0)
///   let adapter = locator.as_locator()
///   assert_eq(locator.tick_values(0.0, 5.0), [-1.0, 1.0, 3.0, 5.0, 7.0])
///   locator.set_params(base=4.0)
///   assert_eq(adapter.multiple_locator().unwrap().base(), 4.0)
///   assert_eq(locator.copy().offset(), 1.0)
/// }
/// ```
pub fn MultipleLocator::new(
  base~ : Double = 1.0,
  offset~ : Double = 0.0,
) -> MultipleLocator raise @core.DataError {
  validate_multiple(base, offset)
  { base, offset, }
}

///|
pub fn MultipleLocator::base(self : MultipleLocator) -> Double {
  self.base
}

///|
pub fn MultipleLocator::offset(self : MultipleLocator) -> Double {
  self.offset
}

///|
/// Validate typed parameters before replacing either value. Omitted values stay unchanged.
pub fn MultipleLocator::set_params(
  self : MultipleLocator,
  base? : Double,
  offset? : Double,
) -> Unit raise @core.DataError {
  let base = base.unwrap_or(self.base)
  let offset = offset.unwrap_or(self.offset)
  validate_multiple(base, offset)
  self.base = base
  self.offset = offset
}

///|
pub fn MultipleLocator::copy(self : MultipleLocator) -> MultipleLocator {
  { base: self.base, offset: self.offset, }
}

///|
/// Ascending ticks including neighboring points, matching source tick_values.
pub fn MultipleLocator::tick_values(
  self : MultipleLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  @tick_grid.ticks(lower, upper, self.base, offset=self.offset)
}

///|
// transforms._nonsingular, preserving binary64 operation order and zero threshold.
fn locator_nonsingular(
  lower : Double,
  upper : Double,
  expander : Double,
  tiny~ : Double = 1.0e-15,
) -> (Double, Double) {
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    return (-expander, expander)
  }
  let mut first = Double::min(lower, upper)
  let mut last = Double::max(lower, upper)
  let largest = Double::max(Double::abs(first), Double::abs(last))
  if largest < 1.0e6 / tiny * 2.2250738585072014e-308 {
    first = -expander
    last = expander
  } else if last - first <= largest * tiny {
    first -= expander * Double::abs(first)
    last += expander * Double::abs(last)
  }
  (first, last)
}

///|
pub fn MultipleLocator::nonsingular(
  _self : MultipleLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.05)
}

///|
/// Read axes.autolimit_mode at each call; round each original endpoint before sorting.
pub fn MultipleLocator::view_limits(
  self : MultipleLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  let (first, last) = if @config.axes_autolimit_mode() == "round_numbers" {
    let mut first = @tick_grid.le(lower - self.offset, self.base) * self.base +
      self.offset
    let mut last = @tick_grid.ge(upper - self.offset, self.base) * self.base +
      self.offset
    if first == last {
      first -= 1.0
      last += 1.0
    }
    (first, last)
  } else {
    (lower, upper)
  }
  locator_nonsingular(first, last, 0.001)
}

///|
pub fn MultipleLocator::as_locator(self : MultipleLocator) -> Locator {
  Multiple(self)
}

///|
pub fn MultipleLocator::as_minor_locator(
  self : MultipleLocator,
) -> MinorLocator {
  Multiple(self)
}

///|
pub fn Locator::multiple_locator(self : Locator) -> MultipleLocator? {
  match self {
    Multiple(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::multiple_locator(self : MinorLocator) -> MultipleLocator? {
  match self {
    Multiple(value) => Some(value)
    _ => None
  }
}

///|
pub fn multiple_locator(
  base~ : Double = 1.0,
  offset~ : Double = 0.0,
) -> Locator raise @core.DataError {
  MultipleLocator::new(base~, offset~).as_locator()
}
