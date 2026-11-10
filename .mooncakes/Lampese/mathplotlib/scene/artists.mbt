///|
/// Add a horizontal bar plot from y positions and widths.
fn horizontal_bar_points(values : Array[@core.Point]) -> Array[@core.Point] {
  let points = Array(capacity=values.length())
  for value in values {
    points.push(@core.point(value.y(), value.x()))
  }
  points
}

///|
pub fn Figure::barh(
  self : Figure,
  ys : Array[Double],
  widths : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().barh(ys, widths, color~, label~)
}

///|
/// Draw a horizontal reference line in data coordinates.
pub fn Figure::axhline(
  self : Figure,
  value : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().axhline(value, color~, label~)
}

///|
/// Draw a vertical reference line in data coordinates.
pub fn Figure::axvline(
  self : Figure,
  value : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().axvline(value, color~, label~)
}

///|
fn validate_axline_point(point : @core.Point) -> Unit raise @core.DataError {
  if point.x().is_nan() ||
    point.x().is_inf() ||
    point.y().is_nan() ||
    point.y().is_inf() {
    raise @core.DataError::InvalidReference(
      message="axline points must be finite",
    )
  }
}

///|
/// Draw an infinitely long line through one or two data points.
pub fn Figure::axline(
  self : Figure,
  xy1 : @core.Point,
  xy2? : @core.Point,
  slope? : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  match (xy2, slope) {
    (Some(xy2), Some(slope)) =>
      self.axes().axline(xy1, xy2~, slope~, color~, label~)
    (Some(xy2), None) => self.axes().axline(xy1, xy2~, color~, label~)
    (None, Some(slope)) => self.axes().axline(xy1, slope~, color~, label~)
    (None, None) => self.axes().axline(xy1, color~, label~)
  }
}

///|
/// Add text at a data coordinate.
pub fn Figure::text(
  self : Figure,
  x : Double,
  y : Double,
  value : String,
  color~ : String = "#111827",
) -> Unit raise @core.DataError {
  self.axes().text(x, y, value, color~)
}

///|
/// Add horizontal bars through the axes view.
pub fn Axes::barh(
  self : Axes,
  ys : Array[Double],
  widths : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let values = @core.series(ys, widths)
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::BarH(
      horizontal_bar_points(values.points()),
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
  self.add_container(ContainerKind::Bar, start, label)
}

///|
/// Add a horizontal reference line through the axes view.
pub fn Axes::axhline(
  self : Axes,
  value : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise @core.DataError::NonFiniteLimit(axis="y")
  }
  let resolved_color = self.resolve_color(color)
  self.push_artist(Artist::HLine(value, @core.style(resolved_color)))
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Add a vertical reference line through the axes view.
pub fn Axes::axvline(
  self : Axes,
  value : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise @core.DataError::NonFiniteLimit(axis="x")
  }
  let resolved_color = self.resolve_color(color)
  self.push_artist(Artist::VLine(value, @core.style(resolved_color)))
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Draw an infinitely long line through one or two data points.
pub fn Axes::axline(
  self : Axes,
  xy1 : @core.Point,
  xy2? : @core.Point,
  slope? : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  validate_axline_point(xy1)
  let direction = match (xy2, slope) {
    (Some(xy2), None) => {
      validate_axline_point(xy2)
      let value = @core.point(xy2.x() - xy1.x(), xy2.y() - xy1.y())
      if value.x() == 0.0 && value.y() == 0.0 {
        raise @core.DataError::InvalidReference(
          message="axline points must be distinct",
        )
      }
      value
    }
    (None, Some(slope)) => {
      if slope.is_nan() || slope.is_inf() {
        raise @core.DataError::InvalidReference(
          message="axline slope must be finite",
        )
      }
      if self.x_scale().is_nonlinear() || self.y_scale().is_nonlinear() {
        raise @core.DataError::InvalidReference(
          message="axline slope is not supported on non-linear axes",
        )
      }
      @core.point(1.0, slope)
    }
    (Some(_), Some(_)) =>
      raise @core.DataError::InvalidReference(
        message="provide either xy2 or slope, not both",
      )
    (None, None) =>
      raise @core.DataError::InvalidReference(
        message="axline requires xy2 or slope",
      )
  }
  let resolved_color = self.resolve_color(color)
  self.push_artist(Artist::AxLine(xy1, direction, @core.style(resolved_color)))
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Add text through the axes view.
pub fn Axes::text(
  self : Axes,
  x : Double,
  y : Double,
  value : String,
  color~ : String = "#111827",
) -> Unit raise @core.DataError {
  if x.is_nan() || x.is_inf() {
    raise @core.DataError::NonFiniteLimit(axis="x")
  }
  if y.is_nan() || y.is_inf() {
    raise @core.DataError::NonFiniteLimit(axis="y")
  }
  self.push_artist(Artist::Text(x, y, value, @core.style(color)))
}
