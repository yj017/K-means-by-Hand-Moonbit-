///|
/// A locator with no ticks. It needs no bound axis or numeric parameters.
pub struct NullLocator {
  priv messages : Array[String]
}

///|
pub fn NullLocator::new() -> NullLocator {
  { messages: [], }
}

///|
pub fn NullLocator::copy(self : NullLocator) -> NullLocator {
  { messages: self.messages.copy(), }
}

///|
/// Capture the inherited warning; this operation changes no tick parameters.
pub fn NullLocator::set_params(self : NullLocator) -> Unit {
  self.messages.clear()
  self.messages.push(
    "'set_params()' not defined for locator of type <class 'matplotlib.ticker.NullLocator'>",
  )
}

///|
pub fn NullLocator::warnings(self : NullLocator) -> Array[String] {
  self.messages.copy()
}

///|
pub fn NullLocator::call(self : NullLocator) -> Array[Double] {
  self.messages.clear()
  []
}

///|
pub fn NullLocator::tick_values(
  self : NullLocator,
  _lower : Double,
  _upper : Double,
) -> Array[Double] {
  self.messages.clear()
  []
}

///|
pub fn NullLocator::view_limits(
  self : NullLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  self.messages.clear()
  locator_nonsingular(lower, upper, 0.001)
}

///|
pub fn NullLocator::nonsingular(
  self : NullLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  self.messages.clear()
  locator_nonsingular(lower, upper, 0.05)
}
