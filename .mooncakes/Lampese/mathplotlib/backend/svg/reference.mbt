///|
fn append_reference_line(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  value : Double,
  horizontal : Bool,
  style : @core.Style,
) -> Unit {
  if horizontal {
    if !scale.y_axis_scale.is_valid(value) {
      return
    }
  } else if !scale.x_axis_scale.is_valid(value) {
    return
  }
  let attrs = if horizontal {
    [
      ("x1", float_text(left)),
      ("y1", float_text(map_y(scale, top, plot_height, value))),
      ("x2", float_text(left + plot_width)),
      ("y2", float_text(map_y(scale, top, plot_height, value))),
    ]
  } else {
    [
      ("x1", float_text(map_x(scale, left, plot_width, value))),
      ("y1", float_text(top)),
      ("x2", float_text(map_x(scale, left, plot_width, value))),
      ("y2", float_text(top + plot_height)),
    ]
  }
  let attributes = Array(capacity=6)
  for attribute in attrs {
    attributes.push(attribute)
  }
  attributes.push(("stroke", style.color()))
  attributes.push(("stroke-width", float_text(style.width())))
  try! writer.empty_element("line", attributes)
}

///|
fn append_axline_candidate(
  points : Array[@core.Point],
  point : @core.Point,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
  x_scale : @ticker_scale.Scale,
  y_scale : @ticker_scale.Scale,
) -> Unit {
  if point.x().is_nan() ||
    point.x().is_inf() ||
    point.y().is_nan() ||
    point.y().is_inf() ||
    point.x() < xmin ||
    point.x() > xmax ||
    point.y() < ymin ||
    point.y() > ymax ||
    !x_scale.is_valid(point.x()) ||
    !y_scale.is_valid(point.y()) {
    return
  }
  for existing in points {
    if Double::abs(existing.x() - point.x()) < 1.0e-12 &&
      Double::abs(existing.y() - point.y()) < 1.0e-12 {
      return
    }
  }
  points.push(point)
}

///|
fn append_transformed_axline_candidate(
  points : Array[@core.Point],
  point : @core.Point,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Unit {
  if point.x().is_nan() ||
    point.x().is_inf() ||
    point.y().is_nan() ||
    point.y().is_inf() ||
    point.x() < xmin ||
    point.x() > xmax ||
    point.y() < ymin ||
    point.y() > ymax {
    return
  }
  for existing in points {
    if Double::abs(existing.x() - point.x()) < 1.0e-12 &&
      Double::abs(existing.y() - point.y()) < 1.0e-12 {
      return
    }
  }
  points.push(point)
}

///|
/// Clip an axline in transformed coordinates for logarithmic axes.
///
/// Matplotlib's two-point form represents a straight line in display space.
/// Transforming both points before clipping preserves that meaning when one
/// or both axes use a nonlinear scale.
fn append_transformed_axline(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  point : @core.Point,
  direction : @core.Point,
  style : @core.Style,
) -> Unit {
  if !scale.x_axis_scale.is_valid(point.x()) ||
    !scale.y_axis_scale.is_valid(point.y()) {
    return
  }
  let second = @core.point(point.x() + direction.x(), point.y() + direction.y())
  if !scale.x_axis_scale.is_valid(second.x()) ||
    !scale.y_axis_scale.is_valid(second.y()) {
    return
  }
  let tx0 = scale.x_axis_scale.transform(point.x())
  let ty0 = scale.y_axis_scale.transform(point.y())
  let tx1 = scale.x_axis_scale.transform(second.x())
  let ty1 = scale.y_axis_scale.transform(second.y())
  let xmin = Double::min(
    scale.x_axis_scale.transform(scale.xmin),
    scale.x_axis_scale.transform(scale.xmax),
  )
  let xmax = Double::max(
    scale.x_axis_scale.transform(scale.xmin),
    scale.x_axis_scale.transform(scale.xmax),
  )
  let ymin = Double::min(
    scale.y_axis_scale.transform(scale.ymin),
    scale.y_axis_scale.transform(scale.ymax),
  )
  let ymax = Double::max(
    scale.y_axis_scale.transform(scale.ymin),
    scale.y_axis_scale.transform(scale.ymax),
  )
  let dx = tx1 - tx0
  let dy = ty1 - ty0
  if dx == 0.0 && dy == 0.0 {
    return
  }
  let candidates : Array[@core.Point] = []
  if dx == 0.0 {
    append_transformed_axline_candidate(
      candidates,
      @core.point(tx0, ymin),
      xmin,
      xmax,
      ymin,
      ymax,
    )
    append_transformed_axline_candidate(
      candidates,
      @core.point(tx0, ymax),
      xmin,
      xmax,
      ymin,
      ymax,
    )
  } else {
    let y_at_xmin = ty0 + (xmin - tx0) * dy / dx
    let y_at_xmax = ty0 + (xmax - tx0) * dy / dx
    append_transformed_axline_candidate(
      candidates,
      @core.point(xmin, y_at_xmin),
      xmin,
      xmax,
      ymin,
      ymax,
    )
    append_transformed_axline_candidate(
      candidates,
      @core.point(xmax, y_at_xmax),
      xmin,
      xmax,
      ymin,
      ymax,
    )
    if dy != 0.0 {
      let x_at_ymin = tx0 + (ymin - ty0) * dx / dy
      let x_at_ymax = tx0 + (ymax - ty0) * dx / dy
      append_transformed_axline_candidate(
        candidates,
        @core.point(x_at_ymin, ymin),
        xmin,
        xmax,
        ymin,
        ymax,
      )
      append_transformed_axline_candidate(
        candidates,
        @core.point(x_at_ymax, ymax),
        xmin,
        xmax,
        ymin,
        ymax,
      )
    }
  }
  if candidates.length() >= 2 {
    let first = candidates[0]
    let second = candidates[1]
    let first_data = @core.point(
      scale.x_axis_scale.inverse(first.x()),
      scale.y_axis_scale.inverse(first.y()),
    )
    let second_data = @core.point(
      scale.x_axis_scale.inverse(second.x()),
      scale.y_axis_scale.inverse(second.y()),
    )
    try! writer.empty_element("line", [
      ("x1", float_text(map_x(scale, left, plot_width, first_data.x()))),
      ("y1", float_text(map_y(scale, top, plot_height, first_data.y()))),
      ("x2", float_text(map_x(scale, left, plot_width, second_data.x()))),
      ("y2", float_text(map_y(scale, top, plot_height, second_data.y()))),
      ("stroke", style.color()),
      ("stroke-width", float_text(style.width())),
    ])
  }
}

///|
fn append_axline(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  point : @core.Point,
  direction : @core.Point,
  style : @core.Style,
) -> Unit {
  if scale.x_axis_scale.is_nonlinear() || scale.y_axis_scale.is_nonlinear() {
    append_transformed_axline(
      writer, scale, left, top, plot_width, plot_height, point, direction, style,
    )
    return
  }
  let xmin = Double::min(scale.xmin, scale.xmax)
  let xmax = Double::max(scale.xmin, scale.xmax)
  let ymin = Double::min(scale.ymin, scale.ymax)
  let ymax = Double::max(scale.ymin, scale.ymax)
  let dx = direction.x()
  let dy = direction.y()
  if dx == 0.0 && dy == 0.0 {
    return
  }
  let candidates : Array[@core.Point] = []
  if dx == 0.0 {
    append_axline_candidate(
      candidates,
      @core.point(point.x(), ymin),
      xmin,
      xmax,
      ymin,
      ymax,
      scale.x_axis_scale,
      scale.y_axis_scale,
    )
    append_axline_candidate(
      candidates,
      @core.point(point.x(), ymax),
      xmin,
      xmax,
      ymin,
      ymax,
      scale.x_axis_scale,
      scale.y_axis_scale,
    )
  } else {
    let y_at_xmin = point.y() + (xmin - point.x()) * dy / dx
    let y_at_xmax = point.y() + (xmax - point.x()) * dy / dx
    append_axline_candidate(
      candidates,
      @core.point(xmin, y_at_xmin),
      xmin,
      xmax,
      ymin,
      ymax,
      scale.x_axis_scale,
      scale.y_axis_scale,
    )
    append_axline_candidate(
      candidates,
      @core.point(xmax, y_at_xmax),
      xmin,
      xmax,
      ymin,
      ymax,
      scale.x_axis_scale,
      scale.y_axis_scale,
    )
    if dy != 0.0 {
      let x_at_ymin = point.x() + (ymin - point.y()) * dx / dy
      let x_at_ymax = point.x() + (ymax - point.y()) * dx / dy
      append_axline_candidate(
        candidates,
        @core.point(x_at_ymin, ymin),
        xmin,
        xmax,
        ymin,
        ymax,
        scale.x_axis_scale,
        scale.y_axis_scale,
      )
      append_axline_candidate(
        candidates,
        @core.point(x_at_ymax, ymax),
        xmin,
        xmax,
        ymin,
        ymax,
        scale.x_axis_scale,
        scale.y_axis_scale,
      )
    }
  }
  if candidates.length() >= 2 {
    let first = candidates[0]
    let second = candidates[1]
    try! writer.empty_element("line", [
      ("x1", float_text(map_x(scale, left, plot_width, first.x()))),
      ("y1", float_text(map_y(scale, top, plot_height, first.y()))),
      ("x2", float_text(map_x(scale, left, plot_width, second.x()))),
      ("y2", float_text(map_y(scale, top, plot_height, second.y()))),
      ("stroke", style.color()),
      ("stroke-width", float_text(style.width())),
    ])
  }
}

///|
fn append_span(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  lower : Double,
  upper : Double,
  horizontal : Bool,
  style : @core.Style,
) -> Unit {
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  if horizontal {
    if !scale.y_axis_scale.is_valid(lower) ||
      !scale.y_axis_scale.is_valid(upper) {
      return
    }
    let first = map_y(scale, top, plot_height, lower)
    let second = map_y(scale, top, plot_height, upper)
    try! writer.empty_element("rect", [
      ("x", float_text(left)),
      ("y", float_text(Double::min(first, second))),
      ("width", float_text(plot_width)),
      ("height", float_text(Double::abs(second - first))),
      ("fill", fill),
      ("fill-opacity", "0.35"),
      ("stroke", "none"),
    ])
  } else {
    if !scale.x_axis_scale.is_valid(lower) ||
      !scale.x_axis_scale.is_valid(upper) {
      return
    }
    let first = map_x(scale, left, plot_width, lower)
    let second = map_x(scale, left, plot_width, upper)
    try! writer.empty_element("rect", [
      ("x", float_text(Double::min(first, second))),
      ("y", float_text(top)),
      ("width", float_text(Double::abs(second - first))),
      ("height", float_text(plot_height)),
      ("fill", fill),
      ("fill-opacity", "0.35"),
      ("stroke", "none"),
    ])
  }
}
