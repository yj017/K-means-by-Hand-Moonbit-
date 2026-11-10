///|
/// Draw a ring chart and return normalized slice fractions. `inner_radius` is a
/// fraction of the outer radius: 0 is a filled pie, and 0.55 leaves a transparent
/// hole. The ratio must be finite, non-negative and strictly less than 1.
pub fn Figure::donut(
  self : Figure,
  values : Array[Double],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  start_angle~ : Double = 0.0,
  inner_radius~ : Double = 0.55,
) -> Array[Double] raise @core.DataError {
  self.axes().donut(values, labels~, colors~, start_angle~, inner_radius~)
}

///|
/// Draw an annular pie with a real transparent hole. Slice colors, labels and
/// original indices follow `pie`; the container and interaction kind remain Pie.
/// Invalid input is reported as `DataError::InvalidPie` before adding artists.
pub fn Axes::donut(
  self : Axes,
  values : Array[Double],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  start_angle~ : Double = 0.0,
  inner_radius~ : Double = 0.55,
) -> Array[Double] raise @core.DataError {
  validate_pie(values, labels, colors, start_angle)
  if inner_radius.is_nan() ||
    inner_radius.is_inf() ||
    inner_radius < 0.0 ||
    inner_radius >= 1.0 {
    raise @core.DataError::InvalidPie(
      message="donut inner_radius must be a finite ratio in [0, 1)",
    )
  }
  let mut total = 0.0
  for value in values {
    total += value
  }
  if total.is_inf() {
    raise @core.DataError::InvalidPie(
      message="donut values must have a finite sum",
    )
  }
  let resolved_colors = resolve_pie_colors(self, colors, values.length())
  let fractions = values.map(value => value / total)
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::Donut(
      values.copy(),
      labels.copy(),
      resolved_colors,
      start_angle,
      inner_radius,
    ),
  )
  self.add_container(ContainerKind::Pie, start, "")
  fractions
}
