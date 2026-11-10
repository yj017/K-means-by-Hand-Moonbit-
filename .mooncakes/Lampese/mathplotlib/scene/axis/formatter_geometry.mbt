///|
/// Supply bottom-up display origin and length for one-pixel short formatting.
pub fn Axis::bind_formatter_geometry(
  self : Axis,
  provider : () -> (Double, Double),
) -> Unit {
  self.formatter_geometry_provider = Some(provider)
  self.formatter_axis_binding.bind_short_format_delta(value => {
    let (origin, length) = self.formatter_display_geometry().unwrap()
    let (lower, upper) = self.view_interval_checked()
    short_format_pixel_delta(
      value,
      lower,
      upper,
      origin,
      length,
      self.coordinate_transform(),
      self.coordinate_inverse(),
    )
  })
}

///|
/// Return live display geometry, preferring the active render layout.
pub fn Axis::formatter_display_geometry(self : Axis) -> (Double, Double)? {
  if self.tick_layout_active &&
    self.tick_layout_origin is Some(origin) &&
    self.tick_layout_length is Some(length) {
    return Some((origin, length))
  }
  match self.formatter_geometry_provider {
    Some(provider) => Some(provider())
    None => None
  }
}

///|
/// Resolve the data distance of neighboring display pixels through both affines.
pub fn short_format_pixel_delta(
  value : Double,
  lower : Double,
  upper : Double,
  origin : Double,
  length : Double,
  transform : (Double) -> Double,
  inverse : (Double) -> Double,
) -> Double raise @core.DataError {
  let first = transform(lower)
  let last = transform(upper)
  let normalized_scale = 1.0 / (last - first)
  let normalized_translation = -first * normalized_scale
  let a = length * normalized_scale
  let e = length * normalized_translation + origin
  if a == 0.0 {
    raise @core.DataError::InvalidTicks(message="LinAlgError: Singular matrix")
  }
  let inverse_a = 1.0 / a
  let inverse_e = -e / a
  let screen = transform(value) * a + e
  let before = inverse((screen - 1.0) * inverse_a + inverse_e)
  let after = inverse((screen + 1.0) * inverse_a + inverse_e)
  Double::max(Double::abs(before - value), Double::abs(after - value))
}
