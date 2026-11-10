///|
fn vector_for_paint(
  source : @render.VectorHitData?,
  points : Array[@core.Point],
  vectors : Array[@core.Point],
  style : @core.Style,
) -> @render.VectorHitData? {
  guard source is Some(data) else { return None }
  // The Quiver writer emits only stroke and stroke-width. It does not emit
  // line alpha/dashes/fill/linestyle, so none of those veto actual paint.
  if data.matches(points, vectors) &&
    style.width() != 0.0 &&
    discrete_effective_paint_visible(style.color()) {
    Some(data)
  } else {
    None
  }
}

///|
fn vector_capture(
  output : DrawingCapture?,
  source : @render.VectorHitData?,
  panel_index : Int32,
  artist_index : Int32,
  bounds : (Double, Double, Double, Double),
  series : String,
) -> ((Int32, Array[(Double, Double, Double, Double)]) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(data) else { return None }
  Some((i, parts) => {
    guard data.datum(i) is Some(datum) else { return }
    for segment in parts {
      guard violin_visible_segment(segment, bounds) is Some((x0, y0, x1, y1)) else {
        continue
      }
      let point = @drawing.hit_point(
        panel_index,
        artist_index,
        datum.index,
        datum.point.x(),
        datum.point.y(),
        x0 / 2.0 + x1 / 2.0,
        y0 / 2.0 + y1 / 2.0,
      )
      let info = @drawing.hit_info(
        point,
        Quiver,
        value=datum.vector.v,
        vector=Some(datum.vector),
        series~,
      )
      hits.points.push(point)
      hits.targets.push(
        @drawing.hit_target(
          info,
          Segment(segment.0, segment.1, segment.2, segment.3),
          bounds,
        ),
      )
    }
  })
}
