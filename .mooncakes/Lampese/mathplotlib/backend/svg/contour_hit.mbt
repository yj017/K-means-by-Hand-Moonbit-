///|
fn contour_line_for_paint(
  view : @render.ContourHitView?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.ContourHitView? {
  guard view is Some(source) else { return None }
  if discrete_line_visible(style) &&
    style.line_stroke().linestyle() == "-" &&
    style.line_stroke().dash_sequence() is None &&
    source.matches_points(points) {
    Some(source)
  } else {
    None
  }
}

///|
// The writer supplies actual valid runs. This callback never searches or
// revalidates the complete path and never identifies a grid observation.
fn contour_line_capture(
  output : DrawingCapture?,
  source : @render.ContourHitView?,
  panel_index : Int32,
  artist_index : Int32,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
) -> ((Array[@core.Point], Int32) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(view) else { return None }
  Some((points, _) => {
    let (left, top, width, height) = bounds
    for i in 0..<(points.length() - 1) {
      let a = points[i]
      let b = points[i + 1]
      let x0 = map_x(scale, left, width, a.x())
      let y0 = map_y(scale, top, height, a.y())
      let x1 = map_x(scale, left, width, b.x())
      let y1 = map_y(scale, top, height, b.y())
      if x0 == x1 && y0 == y1 {
        continue
      }
      guard violin_visible_segment((x0, y0, x1, y1), bounds)
        is Some((cx0, cy0, cx1, cy1)) else {
        continue
      }
      let data_x = a.x() / 2.0 + b.x() / 2.0
      let data_y = a.y() / 2.0 + b.y() / 2.0
      if !violin_screen_finite(data_x) || !violin_screen_finite(data_y) {
        continue
      }
      let point = @drawing.hit_point(
        panel_index,
        artist_index,
        view.slot(),
        data_x,
        data_y,
        cx0 / 2.0 + cx1 / 2.0,
        cy0 / 2.0 + cy1 / 2.0,
      )
      let info = @drawing.hit_info(
        point,
        Contour,
        value=view.level(),
        series=view.series(),
      )
      hits.points.push(point)
      hits.targets.push(
        @drawing.hit_target(info, Segment(x0, y0, x1, y1), bounds),
      )
    }
  })
}
