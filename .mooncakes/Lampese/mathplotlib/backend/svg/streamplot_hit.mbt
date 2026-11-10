///|
fn streamplot_line_for_paint(
  view : @render.StreamplotHitView?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.StreamplotHitView? {
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
// Actual valid-run source_start plus a constant view offset identifies the edge.
fn streamplot_line_capture(
  output : DrawingCapture?,
  source : @render.StreamplotHitView?,
  panel_index : Int32,
  artist_index : Int32,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
) -> ((Array[@core.Point], Int32) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(view) else { return None }
  Some((points, start) => {
    let (left, top, width, height) = bounds
    for i in 0..<(points.length() - 1) {
      guard view.datum(start + i) is Some(datum) else { continue }
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
      let info = @drawing.hit_info(
        @drawing.hit_point(
          panel_index,
          artist_index,
          datum.index,
          datum.point.x(),
          datum.point.y(),
          cx0 / 2.0 + cx1 / 2.0,
          cy0 / 2.0 + cy1 / 2.0,
        ),
        Streamplot,
        value=datum.info.v,
        series=view.series(),
        streamplot=Some(datum.info),
      )
      hits.points.push(info.point)
      hits.targets.push(
        @drawing.hit_target(info, Segment(x0, y0, x1, y1), bounds),
      )
    }
  })
}
