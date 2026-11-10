///|
fn float_text(value : Double) -> String {
  Double::to_string(value)
}

///|
fn valid_point(scale : Scale, point : @core.Point) -> Bool {
  point.is_finite() &&
  scale.x_axis_scale.is_valid(point.x()) &&
  scale.y_axis_scale.is_valid(point.y())
}

///|
fn clamp_to_limits(value : Double, first : Double, second : Double) -> Double {
  if first <= second {
    Double::clamp(value, min=first, max=second)
  } else {
    Double::clamp(value, min=second, max=first)
  }
}

///|
fn points_text(
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
) -> String {
  let result = StringBuilder()
  for i in 0..<points.length() {
    let p = points[i]
    result.write_string(float_text(map_x(scale, left, plot_width, p.x())))
    result.write_string(",")
    result.write_string(float_text(map_y(scale, top, plot_height, p.y())))
    if i + 1 < points.length() {
      result.write_string(" ")
    }
  }
  result.to_string()
}

///|
// Axis._update_ticks uses transformed view coordinates with interval_contains_close.
// Keep locator neighbors for formatting, but draw only the visible tick components.
fn tick_in_view(
  value : Double,
  axis_scale : @ticker_scale.Scale,
  lower : Double,
  upper : Double,
) -> Bool {
  if !axis_scale.is_valid(value) {
    return false
  }
  let first = axis_scale.transform(lower)
  let last = axis_scale.transform(upper)
  let position = axis_scale.transform(value)
  let low = Double::min(first, last)
  let high = Double::max(first, last)
  let tolerance = (high - low) * 1.0e-10
  low - tolerance <= position && position <= high + tolerance
}
