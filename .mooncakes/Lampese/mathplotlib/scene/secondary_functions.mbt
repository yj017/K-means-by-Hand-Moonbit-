///|
/// Replace the functions used to map parent limits. A matching parent scale
/// name retains the installed transform and ticker objects until a name change.
/// Functions remain assigned if the later scale synchronization raises.
pub fn SecondaryAxis::set_functions(
  self : SecondaryAxis,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
) -> Unit raise @core.DataError {
  self.forward = forward
  self.inverse = inverse
  self.synchronize_parent_scale()
}

///|
/// Store identity limit functions, corresponding to source set_functions(None).
/// The same parent-name gate applies to the already installed transform.
pub fn SecondaryAxis::reset_functions(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  self.set_functions(value => value, value => value)
}
