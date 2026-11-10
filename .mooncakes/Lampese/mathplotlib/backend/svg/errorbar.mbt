///|
priv struct RenderedErrorBar {
  source_index : Int32
  point : @core.Point
  screen_x : Double
  screen_y : Double
  x_range : (Double, Double)
  y_range : (Double, Double)
  segments : Array[(Double, Double, Double, Double)]
}

///|
// Only discard paints whose transparency is known. Other valid CSS paints
// (named colors, currentColor, variables) need not use our small color parser.
fn statistics_paint_visible(value : String) -> Bool {
  let color = value.trim().to_owned().to_lower()
  if color == "none" {
    return false
  }
  // SVG also accepts CSS's four-digit RGBA shorthand.
  let color = match color.to_array() {
    ['#', r, g, b, a] => "#\{r}\{r}\{g}\{g}\{b}\{b}\{a}\{a}"
    _ => color
  }
  try @colors.parse_color(color).alpha() > 0.0 catch {
    _ => true
  }
}

///|
fn statistics_stroke_visible(style : @core.Style) -> Bool {
  // Invalid CSS widths retain SVG's fallback behavior; an explicit zero width
  // is the value that reliably disables the stroke without changing output.
  style.width() != 0.0 && statistics_paint_visible(style.color())
}

///|
fn append_error_segment(
  writer : @xml.Writer,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  style : @core.Style,
  segments~ : Array[(Double, Double, Double, Double)]? = None,
) -> Unit {
  try! writer.empty_element("line", [
    ("x1", float_text(x1)),
    ("y1", float_text(y1)),
    ("x2", float_text(x2)),
    ("y2", float_text(y2)),
    ("stroke", style.color()),
    ("stroke-width", float_text(style.width())),
  ])
  if segments is Some(captured) {
    captured.push((x1, y1, x2, y2))
  }
}

///|
fn append_errorbar(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  yerr : Array[Double],
  xerr : Array[Double],
  style : @core.Style,
  on_sample~ : ((RenderedErrorBar) -> Unit)? = None,
) -> Unit {
  append_line(writer, scale, left, top, plot_width, plot_height, points, style)
  let on_sample = if statistics_stroke_visible(style) {
    on_sample
  } else {
    None
  }
  let cap = 4.0
  for i in 0..<points.length() {
    let p = points[i]
    if valid_point(scale, p) {
      let x = map_x(scale, left, plot_width, p.x())
      let y = map_y(scale, top, plot_height, p.y())
      let segments : Array[(Double, Double, Double, Double)]? = on_sample.map(_ => {
        []
      })
      let y_error = if yerr.length() == 0 { 0.0 } else { yerr[i] }
      let x_error = if xerr.length() == 0 { 0.0 } else { xerr[i] }
      if y_error > 0.0 &&
        scale.y_axis_scale.is_valid(p.y() - y_error) &&
        scale.y_axis_scale.is_valid(p.y() + y_error) {
        let low = map_y(scale, top, plot_height, p.y() - y_error)
        let high = map_y(scale, top, plot_height, p.y() + y_error)
        append_error_segment(writer, x, low, x, high, style, segments~)
        append_error_segment(
          writer,
          x - cap,
          low,
          x + cap,
          low,
          style,
          segments~,
        )
        append_error_segment(
          writer,
          x - cap,
          high,
          x + cap,
          high,
          style,
          segments~,
        )
      }
      if x_error > 0.0 &&
        scale.x_axis_scale.is_valid(p.x() - x_error) &&
        scale.x_axis_scale.is_valid(p.x() + x_error) {
        let low = map_x(scale, left, plot_width, p.x() - x_error)
        let high = map_x(scale, left, plot_width, p.x() + x_error)
        append_error_segment(writer, low, y, high, y, style, segments~)
        append_error_segment(
          writer,
          low,
          y - cap,
          low,
          y + cap,
          style,
          segments~,
        )
        append_error_segment(
          writer,
          high,
          y - cap,
          high,
          y + cap,
          style,
          segments~,
        )
      }
      if on_sample is Some(collect) {
        collect({
          source_index: i,
          point: p,
          screen_x: x,
          screen_y: y,
          x_range: (p.x() - x_error, p.x() + x_error),
          y_range: (p.y() - y_error, p.y() + y_error),
          segments: segments.unwrap(),
        })
      }
    }
  }
}
