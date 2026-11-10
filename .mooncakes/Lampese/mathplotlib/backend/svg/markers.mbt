///|
fn marker_polygon_points(values : Array[Double]) -> String {
  let result = StringBuilder()
  let count = values.length() / 2
  for index in 0..<count {
    if index > 0 {
      result.write_string(" ")
    }
    result.write_string(float_text(values[index * 2]))
    result.write_string(",")
    result.write_string(float_text(values[index * 2 + 1]))
  }
  result.to_string()
}

///|
fn marker_cross_path(x : Double, y : Double, radius : Double) -> String {
  let result = StringBuilder()
  result.write_string("M ")
  result.write_string(float_text(x - radius))
  result.write_string(" ")
  result.write_string(float_text(y - radius))
  result.write_string(" L ")
  result.write_string(float_text(x + radius))
  result.write_string(" ")
  result.write_string(float_text(y + radius))
  result.write_string(" M ")
  result.write_string(float_text(x + radius))
  result.write_string(" ")
  result.write_string(float_text(y - radius))
  result.write_string(" L ")
  result.write_string(float_text(x - radius))
  result.write_string(" ")
  result.write_string(float_text(y + radius))
  result.to_string()
}

///|
fn marker_plus_path(x : Double, y : Double, radius : Double) -> String {
  let result = StringBuilder()
  result.write_string("M ")
  result.write_string(float_text(x - radius))
  result.write_string(" ")
  result.write_string(float_text(y))
  result.write_string(" L ")
  result.write_string(float_text(x + radius))
  result.write_string(" ")
  result.write_string(float_text(y))
  result.write_string(" M ")
  result.write_string(float_text(x))
  result.write_string(" ")
  result.write_string(float_text(y - radius))
  result.write_string(" L ")
  result.write_string(float_text(x))
  result.write_string(" ")
  result.write_string(float_text(y + radius))
  result.to_string()
}

///|
fn append_marker(
  writer : @xml.Writer,
  x : Double,
  y : Double,
  style : @core.Style,
  marker : String,
) -> Unit {
  let radius = style.radius()
  let color = style.color()
  let fill = if style.fill() == "" { color } else { style.fill() }
  let stroke_width = Double::max(1.0, style.width())
  match marker {
    "o" =>
      try! writer.empty_element("circle", [
        ("cx", float_text(x)),
        ("cy", float_text(y)),
        ("r", float_text(radius)),
        ("fill", fill),
      ])
    "." =>
      try! writer.empty_element("circle", [
        ("cx", float_text(x)),
        ("cy", float_text(y)),
        ("r", float_text(Double::max(0.75, radius / 2.0))),
        ("fill", fill),
      ])
    "," =>
      try! writer.empty_element("circle", [
        ("cx", float_text(x)),
        ("cy", float_text(y)),
        ("r", "0.75"),
        ("fill", fill),
      ])
    "s" =>
      try! writer.empty_element("rect", [
        ("x", float_text(x - radius)),
        ("y", float_text(y - radius)),
        ("width", float_text(radius * 2.0)),
        ("height", float_text(radius * 2.0)),
        ("fill", fill),
      ])
    "^" =>
      try! writer.empty_element("polygon", [
        (
          "points",
          marker_polygon_points([
            x,
            y - radius,
            x + radius,
            y + radius,
            x - radius,
            y + radius,
          ]),
        ),
        ("fill", fill),
      ])
    "v" =>
      try! writer.empty_element("polygon", [
        (
          "points",
          marker_polygon_points([
            x - radius,
            y - radius,
            x + radius,
            y - radius,
            x,
            y + radius,
          ]),
        ),
        ("fill", fill),
      ])
    "D" =>
      try! writer.empty_element("polygon", [
        (
          "points",
          marker_polygon_points([
            x,
            y - radius,
            x + radius,
            y,
            x,
            y + radius,
            x - radius,
            y,
          ]),
        ),
        ("fill", fill),
      ])
    "x" =>
      try! writer.empty_element("path", [
        ("d", marker_cross_path(x, y, radius)),
        ("fill", "none"),
        ("stroke", color),
        ("stroke-width", float_text(stroke_width)),
      ])
    "+" =>
      try! writer.empty_element("path", [
        ("d", marker_plus_path(x, y, radius)),
        ("fill", "none"),
        ("stroke", color),
        ("stroke-width", float_text(stroke_width)),
      ])
    "|" =>
      try! writer.empty_element("line", [
        ("x1", float_text(x)),
        ("y1", float_text(y - radius)),
        ("x2", float_text(x)),
        ("y2", float_text(y + radius)),
        ("stroke", color),
        ("stroke-width", float_text(stroke_width)),
      ])
    "_" =>
      try! writer.empty_element("line", [
        ("x1", float_text(x - radius)),
        ("y1", float_text(y)),
        ("x2", float_text(x + radius)),
        ("y2", float_text(y)),
        ("stroke", color),
        ("stroke-width", float_text(stroke_width)),
      ])
    _ =>
      try! writer.empty_element("circle", [
        ("cx", float_text(x)),
        ("cy", float_text(y)),
        ("r", float_text(radius)),
        ("fill", fill),
      ])
  }
}

///|
fn append_scatter(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  on_circle~ : ((Int32, Double, Double) -> Unit)? = None,
) -> Unit {
  for i, p in points {
    if valid_point(scale, p) {
      let x = map_x(scale, left, plot_width, p.x())
      let y = map_y(scale, top, plot_height, p.y())
      append_marker(writer, x, y, style, style.marker())
      if style.marker() == "o" && on_circle is Some(capture) {
        capture(i, x, y)
      }
    }
  }
}

///|
fn append_path_collection(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  styles : Array[@core.Style],
) -> Unit {
  let count = Int32::min(points.length(), styles.length())
  for i in 0..<count {
    let p = points[i]
    let style = styles[i]
    if valid_point(scale, p) {
      append_marker(
        writer,
        map_x(scale, left, plot_width, p.x()),
        map_y(scale, top, plot_height, p.y()),
        style,
        style.marker(),
      )
    }
  }
}
