///|
fn polygon_points_text(
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  upper : Array[@core.Point],
  lower : Array[@core.Point],
) -> String {
  let result = StringBuilder()
  for i in 0..<upper.length() {
    let p = upper[i]
    result.write_string(float_text(map_x(scale, left, plot_width, p.x())))
    result.write_string(",")
    result.write_string(float_text(map_y(scale, top, plot_height, p.y())))
    result.write_string(" ")
  }
  for i in 0..<lower.length() {
    let p = lower[lower.length() - 1 - i]
    result.write_string(float_text(map_x(scale, left, plot_width, p.x())))
    result.write_string(",")
    result.write_string(float_text(map_y(scale, top, plot_height, p.y())))
    if i + 1 < lower.length() {
      result.write_string(" ")
    }
  }
  result.to_string()
}

///|
fn append_fill_segment(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  upper : Array[@core.Point],
  lower : Array[@core.Point],
  style : @core.Style,
  source_start~ : Int32 = 0,
  on_segment~ : ((Array[@core.Point], Array[@core.Point], Int32) -> Unit)? = None,
) -> Unit {
  if upper.length() < 2 || lower.length() < 2 {
    return
  }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  try! writer.empty_element("polygon", [
    (
      "points",
      polygon_points_text(
        scale, left, top, plot_width, plot_height, upper, lower,
      ),
    ),
    ("fill", fill),
    ("stroke", "none"),
  ])
  if fill != "none" && fill != "transparent" && on_segment is Some(capture) {
    capture(upper, lower, source_start)
  }
}

///|
fn append_fill_between(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  upper : Array[@core.Point],
  lower : Array[@core.Point],
  style : @core.Style,
  on_segment~ : ((Array[@core.Point], Array[@core.Point], Int32) -> Unit)? = None,
) -> Unit {
  let mut upper_segment : Array[@core.Point] = []
  let mut lower_segment : Array[@core.Point] = []
  let mut source_start = 0
  let count = Int32::min(upper.length(), lower.length())
  for i in 0..<count {
    let up = upper[i]
    let low = lower[i]
    if valid_point(scale, up) && valid_point(scale, low) {
      upper_segment.push(up)
      lower_segment.push(low)
    } else {
      append_fill_segment(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        upper_segment,
        lower_segment,
        style,
        source_start~,
        on_segment~,
      )
      upper_segment = []
      lower_segment = []
      source_start = i + 1
    }
  }
  append_fill_segment(
    writer,
    scale,
    left,
    top,
    plot_width,
    plot_height,
    upper_segment,
    lower_segment,
    style,
    source_start~,
    on_segment~,
  )
}

///|
fn append_polygon(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  on_polygon~ : ((Array[@core.Point]) -> Unit)? = None,
) -> Unit {
  if points.length() < 3 {
    return
  }
  let visible = Array(capacity=points.length())
  for point in points {
    if valid_point(scale, point) {
      visible.push(point)
    }
  }
  if visible.length() < 3 {
    return
  }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  try! writer.empty_element("polygon", [
    ("points", points_text(scale, left, top, plot_width, plot_height, visible)),
    ("fill", fill),
    ("stroke", style.color()),
    ("stroke-width", float_text(style.width())),
  ])
  if on_polygon is Some(collect) {
    collect(visible)
  }
}

///|
/// Render several boundary loops as one even-odd filled path.
///
/// A compound path is required when a filled contour band contains a hole:
/// separate SVG polygons would paint the hole again, while an even-odd path
/// preserves the topology of the union.
fn append_compound_polygon(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  polygons : Array[Array[@core.Point]],
  style : @core.Style,
  on_polygons~ : ((Array[Array[@core.Point]]) -> Unit)? = None,
) -> Unit {
  let path = StringBuilder()
  let mut loop_count = 0
  let emitted = []
  for points in polygons {
    if points.length() < 3 {
      continue
    }
    let visible = Array(capacity=points.length())
    for point in points {
      if valid_point(scale, point) {
        visible.push(point)
      }
    }
    if visible.length() < 3 {
      continue
    }
    if loop_count > 0 {
      path.write_string(" ")
    }
    let first = visible[0]
    path.write_string("M ")
    path.write_string(float_text(map_x(scale, left, plot_width, first.x())))
    path.write_string(" ")
    path.write_string(float_text(map_y(scale, top, plot_height, first.y())))
    for index in 1..<visible.length() {
      let point = visible[index]
      path.write_string(" L ")
      path.write_string(float_text(map_x(scale, left, plot_width, point.x())))
      path.write_string(" ")
      path.write_string(float_text(map_y(scale, top, plot_height, point.y())))
    }
    path.write_string(" Z")
    if on_polygons is Some(_) {
      emitted.push(visible)
    }
    loop_count += 1
  }
  if loop_count == 0 {
    return
  }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  try! writer.empty_element("path", [
    ("d", path.to_string()),
    ("fill", fill),
    ("stroke", style.color()),
    ("stroke-width", float_text(style.width())),
    ("fill-rule", "evenodd"),
  ])
  if on_polygons is Some(collect) {
    collect(emitted)
  }
}

///|
/// Render one Gouraud triangle using an SVG user-space linear gradient.
///
/// SVG does not expose a portable barycentric gradient primitive.  The
/// gradient is therefore aligned with the first edge and receives a third
/// stop at the projection of the remaining vertex.  This preserves all three
/// vertex colors and gives a smooth, backend-native approximation of the
/// triangle interpolation used by `pcolor(..., shading="gouraud")`.
fn append_gouraud_triangle(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  colors : Array[String],
  gradient_id : String,
) -> Unit {
  if points.length() != 3 || colors.length() != 3 {
    return
  }
  let p0 = points[0]
  let p1 = points[1]
  let p2 = points[2]
  if !valid_point(scale, p0) ||
    !valid_point(scale, p1) ||
    !valid_point(scale, p2) {
    return
  }
  let s0 = @core.point(
    map_x(scale, left, plot_width, p0.x()),
    map_y(scale, top, plot_height, p0.y()),
  )
  let s1 = @core.point(
    map_x(scale, left, plot_width, p1.x()),
    map_y(scale, top, plot_height, p1.y()),
  )
  let s2 = @core.point(
    map_x(scale, left, plot_width, p2.x()),
    map_y(scale, top, plot_height, p2.y()),
  )
  let dx = s1.x() - s0.x()
  let dy = s1.y() - s0.y()
  let length_squared = dx * dx + dy * dy
  let projection = if length_squared == 0.0 {
    0.5
  } else {
    Double::clamp(
      ((s2.x() - s0.x()) * dx + (s2.y() - s0.y()) * dy) / length_squared,
      min=0.0,
      max=1.0,
    )
  }
  try! writer.start_element("defs", [])
  try! writer.start_element("linearGradient", [
    ("id", gradient_id),
    ("gradientUnits", "userSpaceOnUse"),
    ("x1", float_text(s0.x())),
    ("y1", float_text(s0.y())),
    ("x2", float_text(s1.x())),
    ("y2", float_text(s1.y())),
  ])
  try! writer.empty_element("stop", [
    ("offset", "0%"),
    ("stop-color", colors[0]),
  ])
  try! writer.empty_element("stop", [
    ("offset", "\{Double::to_string(projection * 100.0)}%"),
    ("stop-color", colors[2]),
  ])
  try! writer.empty_element("stop", [
    ("offset", "100%"),
    ("stop-color", colors[1]),
  ])
  try! writer.end_element("linearGradient")
  try! writer.end_element("defs")
  try! writer.empty_element("polygon", [
    ("points", points_text(scale, left, top, plot_width, plot_height, points)),
    ("fill", "url(#\{gradient_id})"),
    ("stroke", "none"),
  ])
}
