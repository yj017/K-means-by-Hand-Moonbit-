///|
/// Draw arrows for a vector field sampled at paired x/y positions.
pub fn Figure::quiver(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().quiver(xs, ys, us, vs, color~, label~)
}

///|
/// Draw arrows for a vector field sampled at paired x/y positions.
pub fn Axes::quiver(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  if xs.length() != us.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=us.length(),
    )
  }
  if xs.length() != vs.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=vs.length(),
    )
  }
  let points = Array(capacity=xs.length())
  let vectors = Array(capacity=xs.length())
  for index in 0..<xs.length() {
    let x = xs[index]
    let y = ys[index]
    let u = us[index]
    let v = vs[index]
    if x.is_nan() || x.is_inf() || y.is_nan() || y.is_inf() {
      raise @core.DataError::NonFiniteLimit(axis="both")
    }
    if u.is_nan() || u.is_inf() || v.is_nan() || v.is_inf() {
      raise @core.DataError::InvalidQuiver(
        message="quiver vectors must be finite",
      )
    }
    points.push(@core.point(x, y))
    vectors.push(@core.point(u, v))
  }
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::Quiver(points, vectors, @core.style(resolved_color, width=1.5)),
  )
  self.record_vector_hit(@render.vector_hit_data(points, vectors).unwrap())
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
  self.add_container(ContainerKind::Quiver, start, label)
}
