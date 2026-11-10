///|
fn validate_pie(
  values : Array[Double],
  labels : Array[String],
  colors : Array[String],
  start_angle : Double,
) -> Unit raise @core.DataError {
  if values.length() == 0 {
    raise @core.DataError::InvalidPie(message="pie requires at least one value")
  }
  if labels.length() != 0 && labels.length() != values.length() {
    raise @core.DataError::InvalidPie(
      message="pie labels must match the number of values",
    )
  }
  if colors.length() != 0 && colors.length() != values.length() {
    raise @core.DataError::InvalidPie(
      message="pie colors must match the number of values",
    )
  }
  if start_angle.is_nan() || start_angle.is_inf() {
    raise @core.DataError::InvalidPie(message="pie start_angle must be finite")
  }
  let mut total = 0.0
  for value in values {
    if value.is_nan() || value.is_inf() || value < 0.0 {
      raise @core.DataError::InvalidPie(
        message="pie values must be finite and non-negative",
      )
    }
    total += value
  }
  if total <= 0.0 {
    raise @core.DataError::InvalidPie(
      message="pie values must have a positive sum",
    )
  }
}

///|
fn parse_pie_color(value : String) -> @colors.Rgba raise @core.DataError {
  @colors.parse_color(value) catch {
    @colors.ColorError::InvalidColor(_)
    | @colors.ColorError::ComponentOutOfRange(_)
    | @colors.ColorError::InvalidColorMap(_) =>
      raise @core.DataError::InvalidPie(message="invalid pie color")
  }
}

///|
fn resolve_pie_colors(
  axes : Axes,
  colors : Array[String],
  count : Int32,
) -> Array[String] raise @core.DataError {
  let result = Array(capacity=count)
  for index in 0..<count {
    let value = if colors.length() == 0 {
      axes.resolve_color("")
    } else {
      colors[index]
    }
    let color = parse_pie_color(value)
    result.push(color.to_css())
  }
  result
}

///|
/// Draw a pie chart and return the normalized slice fractions.
pub fn Figure::pie(
  self : Figure,
  values : Array[Double],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  start_angle~ : Double = 0.0,
) -> Array[Double] raise @core.DataError {
  self.axes().pie(values, labels~, colors~, start_angle~)
}

///|
/// Draw a pie chart and return the normalized slice fractions.
pub fn Axes::pie(
  self : Axes,
  values : Array[Double],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  start_angle~ : Double = 0.0,
) -> Array[Double] raise @core.DataError {
  validate_pie(values, labels, colors, start_angle)
  let resolved_colors = resolve_pie_colors(self, colors, values.length())
  let mut total = 0.0
  for value in values {
    total += value
  }
  let fractions = Array(capacity=values.length())
  for value in values {
    fractions.push(value / total)
  }
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::Pie(values.copy(), labels.copy(), resolved_colors, start_angle),
  )
  self.add_container(ContainerKind::Pie, start, "")
  fractions
}
