///|
fn masked_points(
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
) -> Array[@core.Point] raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  let x_values = xs.values()
  let y_values = ys.values()
  let points = Array(capacity=xs.length())
  let missing = @core.point(0.0 / 0.0, 0.0 / 0.0)
  for index in 0..<xs.length() {
    let point = @core.point(x_values[index], y_values[index])
    points.push(
      if xs.is_masked(index) || ys.is_masked(index) || !point.is_finite() {
        missing
      } else {
        point
      },
    )
  }
  points
}

///|
/// Plot paired masked arrays. The combined mask creates gaps in the line.
pub fn Figure::plot_masked(
  self : Figure,
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().plot_masked(xs, ys, color~, label~)
}

///|
/// Plot paired masked arrays through the axes view.
pub fn Axes::plot_masked(
  self : Axes,
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.line(masked_points(xs, ys), color~, label~)
}

///|
/// Scatter paired masked arrays. Any mask in either input suppresses the point.
pub fn Figure::scatter_masked(
  self : Figure,
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().scatter_masked(xs, ys, color~, label~)
}

///|
/// Scatter paired masked arrays through the axes view.
pub fn Axes::scatter_masked(
  self : Axes,
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.scatter(masked_points(xs, ys), color~, label~)
}

///|
/// Fill between masked lower and upper arrays. Any combined mask creates a
/// gap in the filled region.
pub fn Figure::fill_between_masked(
  self : Figure,
  xs : @core.MaskedArray,
  lower : @core.MaskedArray,
  upper : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().fill_between_masked(xs, lower, upper, color~, label~)
}

///|
/// Fill between masked lower and upper arrays through the axes view.
pub fn Axes::fill_between_masked(
  self : Axes,
  xs : @core.MaskedArray,
  lower : @core.MaskedArray,
  upper : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.fill_between(
    xs.to_array(),
    lower.to_array(),
    upper.to_array(),
    color~,
    label~,
  )
}

///|
/// Fill between masked left and right arrays sampled at y positions.
pub fn Figure::fill_betweenx_masked(
  self : Figure,
  ys : @core.MaskedArray,
  left : @core.MaskedArray,
  right : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().fill_betweenx_masked(ys, left, right, color~, label~)
}

///|
/// Fill between masked left and right arrays through the axes view.
pub fn Axes::fill_betweenx_masked(
  self : Axes,
  ys : @core.MaskedArray,
  left : @core.MaskedArray,
  right : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.add_fill_between(
    ys.to_array(),
    left.to_array(),
    right.to_array(),
    true,
    color,
    label,
  )
}
