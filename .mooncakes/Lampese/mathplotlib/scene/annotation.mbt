///|
/// An annotation whose anchor and text may use display-relative coordinates.
pub struct Annotation {
  x : Double
  y : Double
  text_x : Double
  text_y : Double
  value : String
  xycoords : String
  textcoords : String
  connector : String
  arrow : Bool
  arrowcolor : String
  linewidth : Double
  head_length : Double
  head_width : Double
  style : @core.Style
}

///|
fn annotation(
  x : Double,
  y : Double,
  text_x : Double,
  text_y : Double,
  value : String,
  xycoords : String,
  textcoords : String,
  connector : String,
  arrow : Bool,
  arrowcolor : String,
  linewidth : Double,
  head_length : Double,
  head_width : Double,
  style : @core.Style,
) -> Annotation {
  {
    x,
    y,
    text_x,
    text_y,
    value,
    xycoords,
    textcoords,
    connector,
    arrow,
    arrowcolor,
    linewidth,
    head_length,
    head_width,
    style,
  }
}

///|
fn annotation_coordinates_supported(value : String) -> Bool {
  value == "data" ||
  value == "axes fraction" ||
  value == "figure fraction" ||
  value == "display" ||
  value == "offset points" ||
  value == "offset pixels"
}

///|
fn annotation_connector_supported(value : String) -> Bool {
  value == "straight" || value == "arc3" || value == "angle"
}

///|
fn validate_annotation_number(
  value : Double,
  axis : String,
) -> Unit raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise @core.DataError::InvalidAnnotation(
      message="annotation coordinates must be finite on \{axis}",
    )
  }
}

///|
fn validate_annotation_style(
  linewidth : Double,
  head_length : Double,
  head_width : Double,
) -> Unit raise @core.DataError {
  if linewidth.is_nan() || linewidth.is_inf() || linewidth < 0.0 {
    raise @core.DataError::InvalidAnnotation(
      message="annotation linewidth must be finite and non-negative",
    )
  }
  if head_length.is_nan() || head_length.is_inf() || head_length < 0.0 {
    raise @core.DataError::InvalidAnnotation(
      message="arrow head length must be finite and non-negative",
    )
  }
  if head_width.is_nan() || head_width.is_inf() || head_width < 0.0 {
    raise @core.DataError::InvalidAnnotation(
      message="arrow head width must be finite and non-negative",
    )
  }
}

///|
fn annotation_arrow_artists(
  axes : Axes,
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
  color : String,
  linewidth : Double,
  head_length : Double,
  head_width : Double,
) -> Array[Artist] {
  let result : Array[Artist] = []
  let start = @core.point(x, y)
  let end = @core.point(x + dx, y + dy)
  let magnitude = (dx * dx + dy * dy).sqrt()
  let line_style = @core.style(color, width=linewidth)
  if magnitude == 0.0 {
    return result
  }
  let effective_head_length = Double::min(head_length, magnitude)
  let unit_x = dx / magnitude
  let unit_y = dy / magnitude
  let base_x = end.x() - unit_x * effective_head_length
  let base_y = end.y() - unit_y * effective_head_length
  let base = @core.point(base_x, base_y)
  if effective_head_length == 0.0 || head_width == 0.0 {
    let artist = Artist::Line([start, end], line_style)
    axes.push_artist(artist)
    result.push(artist)
  } else {
    let half_width = head_width / 2.0
    let perpendicular_x = -unit_y
    let perpendicular_y = unit_x
    let left = @core.point(
      base_x + perpendicular_x * half_width,
      base_y + perpendicular_y * half_width,
    )
    let right = @core.point(
      base_x - perpendicular_x * half_width,
      base_y - perpendicular_y * half_width,
    )
    let line = Artist::Line([start, base], line_style)
    let polygon = Artist::Polygon(
      [left, end, right],
      @core.style(color, width=linewidth, fill=color),
    )
    axes.push_artist(line)
    axes.push_artist(polygon)
    result.push(line)
    result.push(polygon)
  }
  result
}

///|
/// Draw one data-coordinate arrow from `(x, y)` by `(dx, dy)`.
pub fn Figure::arrow(
  self : Figure,
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  head_length~ : Double = 0.15,
  head_width~ : Double = 0.10,
  label~ : String = "",
) -> Unit raise @core.DataError {
  self
  .axes()
  .arrow(x, y, dx, dy, color~, linewidth~, head_length~, head_width~, label~)
}

///|
/// Draw one data-coordinate arrow from `(x, y)` by `(dx, dy)`.
pub fn Axes::arrow(
  self : Axes,
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  head_length~ : Double = 0.15,
  head_width~ : Double = 0.10,
  label~ : String = "",
) -> Unit raise @core.DataError {
  validate_annotation_number(x, "x")
  validate_annotation_number(y, "y")
  validate_annotation_number(dx, "dx")
  validate_annotation_number(dy, "dy")
  validate_annotation_style(linewidth, head_length, head_width)
  let resolved_color = self.resolve_color(color)
  ignore(
    annotation_arrow_artists(
      self, x, y, dx, dy, resolved_color, linewidth, head_length, head_width,
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Add text at a data point, optionally connected by an arrow.
///
/// `offset_x` and `offset_y` place the text relative to `(x, y)` in data
/// coordinates. When `arrow` is true, the arrow points from the text to the
/// annotated data point.
pub fn Figure::annotate(
  self : Figure,
  value : String,
  x : Double,
  y : Double,
  offset_x~ : Double = 0.0,
  offset_y~ : Double = 0.0,
  arrow~ : Bool = false,
  color~ : String = "#111827",
  arrowcolor~ : String = "",
  linewidth~ : Double = 1.0,
  head_length~ : Double = 0.15,
  head_width~ : Double = 0.10,
  fontsize~ : Int32 = 12,
  xycoords~ : String = "data",
  textcoords~ : String = "data",
  connector~ : String = "straight",
) -> Unit raise @core.DataError {
  self
  .axes()
  .annotate(
    value,
    x,
    y,
    offset_x~,
    offset_y~,
    arrow~,
    color~,
    arrowcolor~,
    linewidth~,
    head_length~,
    head_width~,
    fontsize~,
    xycoords~,
    textcoords~,
    connector~,
  )
}

///|
/// Add text at a data point, optionally connected by an arrow.
pub fn Axes::annotate(
  self : Axes,
  value : String,
  x : Double,
  y : Double,
  offset_x~ : Double = 0.0,
  offset_y~ : Double = 0.0,
  arrow~ : Bool = false,
  color~ : String = "#111827",
  arrowcolor~ : String = "",
  linewidth~ : Double = 1.0,
  head_length~ : Double = 0.15,
  head_width~ : Double = 0.10,
  fontsize~ : Int32 = 12,
  xycoords~ : String = "data",
  textcoords~ : String = "data",
  connector~ : String = "straight",
) -> Unit raise @core.DataError {
  validate_annotation_number(x, "x")
  validate_annotation_number(y, "y")
  validate_annotation_number(offset_x, "offset_x")
  validate_annotation_number(offset_y, "offset_y")
  validate_annotation_style(linewidth, head_length, head_width)
  if fontsize < 1 {
    raise @core.DataError::InvalidAnnotation(
      message="annotation fontsize must be positive",
    )
  }
  if !annotation_coordinates_supported(xycoords) {
    raise @core.DataError::InvalidAnnotation(
      message="unsupported annotation xycoords",
    )
  }
  if !annotation_coordinates_supported(textcoords) {
    raise @core.DataError::InvalidAnnotation(
      message="unsupported annotation textcoords",
    )
  }
  if xycoords == "offset points" || xycoords == "offset pixels" {
    raise @core.DataError::InvalidAnnotation(
      message="annotation xycoords cannot be an offset mode without a base",
    )
  }
  if !annotation_connector_supported(connector) {
    raise @core.DataError::InvalidAnnotation(
      message="annotation connector must be straight, arc3, or angle",
    )
  }
  let text_x = if textcoords == "offset points" || textcoords == "offset pixels" {
    offset_x
  } else {
    x + offset_x
  }
  let text_y = if textcoords == "offset points" {
    offset_y
  } else {
    y + offset_y
  }
  validate_annotation_number(text_x, "text_x")
  validate_annotation_number(text_y, "text_y")
  if xycoords == "data" && textcoords == "data" && connector == "straight" {
    self.push_artist(
      Artist::Text(
        text_x,
        text_y,
        value,
        @core.style(color, font_size=Double::from_int(fontsize)),
      ),
    )
    if arrow {
      let resolved_arrowcolor = self.resolve_color(arrowcolor)
      ignore(
        annotation_arrow_artists(
          self,
          text_x,
          text_y,
          x - text_x,
          y - text_y,
          resolved_arrowcolor,
          linewidth,
          head_length,
          head_width,
        ),
      )
    }
  } else {
    let resolved_arrowcolor = if arrow {
      self.resolve_color(arrowcolor)
    } else {
      ""
    }
    self.push_artist(
      Artist::Annotation(
        annotation(
          x,
          y,
          text_x,
          text_y,
          value,
          xycoords,
          textcoords,
          connector,
          arrow,
          resolved_arrowcolor,
          linewidth,
          head_length,
          head_width,
          @core.style(color, font_size=Double::from_int(fontsize)),
        ),
      ),
    )
  }
}
