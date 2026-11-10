///|
fn append_quiver(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  vectors : Array[@core.Point],
  style : @core.Style,
  on_arrow~ : ((Int32, Array[(Double, Double, Double, Double)]) -> Unit)? = None,
) -> Unit {
  let count = Int32::min(points.length(), vectors.length())
  for index in 0..<count {
    let point = points[index]
    let vector = vectors[index]
    let end = @core.point(point.x() + vector.x(), point.y() + vector.y())
    if valid_point(scale, point) && valid_point(scale, end) {
      let x1 = map_x(scale, left, plot_width, point.x())
      let y1 = map_y(scale, top, plot_height, point.y())
      let x2 = map_x(scale, left, plot_width, end.x())
      let y2 = map_y(scale, top, plot_height, end.y())
      let dx = x2 - x1
      let dy = y2 - y1
      if dx != 0.0 || dy != 0.0 {
        let segments = on_arrow.map(_ => [])
        append_error_segment(writer, x1, y1, x2, y2, style, segments~)
        let angle = @math.atan2(dy, dx)
        let head = 7.0
        let wing = 0.55
        let left_x = x2 - head * @math.cos(angle - wing)
        let left_y = y2 - head * @math.sin(angle - wing)
        let right_x = x2 - head * @math.cos(angle + wing)
        let right_y = y2 - head * @math.sin(angle + wing)
        append_error_segment(writer, x2, y2, left_x, left_y, style, segments~)
        append_error_segment(writer, x2, y2, right_x, right_y, style, segments~)
        if on_arrow is Some(capture) && segments is Some(parts) {
          capture(index, parts)
        }
      }
    }
  }
}
