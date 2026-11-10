///|
fn stem_rod_for_paint(
  view : @render.StemHitView?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.StemHitView? {
  guard view is Some(data) else { return None }
  if data.rod() is Some(_) &&
    data.matches_points(points) &&
    discrete_line_visible(style) &&
    style.line_stroke().linestyle() == "-" &&
    style.line_stroke().dash_sequence() is None {
    Some(data)
  } else {
    None
  }
}

///|
fn stem_rod_capture(
  output : DrawingCapture?,
  source : @render.StemHitView?,
  panel_index : Int32,
  artist_index : Int32,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  series : String,
) -> ((Array[@core.Point], Int32) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(view) else { return None }
  guard view.rod() is Some(index) else { return None }
  guard view.datum(index) is Some(datum) else { return None }
  Some((points, _) => {
    let (left, top, width, height) = bounds
    for i in 0..<(points.length() - 1) {
      let a = points[i]
      let b = points[i + 1]
      let segment = (
        map_x(scale, left, width, a.x()),
        map_y(scale, top, height, a.y()),
        map_x(scale, left, width, b.x()),
        map_y(scale, top, height, b.y()),
      )
      if segment.0 == segment.2 && segment.1 == segment.3 {
        continue
      }
      guard violin_visible_segment(segment, bounds) is Some((x0, y0, x1, y1)) else {
        continue
      }
      let info = discrete_info(
        datum,
        Stem,
        panel_index,
        artist_index,
        series,
        x0 / 2.0 + x1 / 2.0,
        y0 / 2.0 + y1 / 2.0,
      )
      hits.points.push(info.point)
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

///|
fn stem_heads_for_paint(
  view : @render.StemHitView?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.StemHitView? {
  guard view is Some(data) else { return None }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  // The default circle writes only radius and fill; line alpha/width are
  // not its paint. Match that actual output rather than a stroke decision.
  if data.rod() is None &&
    data.matches_points(points) &&
    style.marker() == "o" &&
    violin_screen_finite(style.radius()) &&
    style.radius() > 0.0 &&
    discrete_effective_paint_visible(fill) {
    Some(data)
  } else {
    None
  }
}

///|
fn stem_head_capture(
  output : DrawingCapture?,
  source : @render.StemHitView?,
  panel_index : Int32,
  artist_index : Int32,
  bounds : (Double, Double, Double, Double),
  series : String,
) -> ((Int32, Double, Double) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(view) else { return None }
  Some((i, x, y) => {
    let (left, top, width, height) = bounds
    if !violin_screen_finite(x) ||
      !violin_screen_finite(y) ||
      x < left ||
      x > left + width ||
      y < top ||
      y > top + height {
      return
    }
    guard view.datum(i) is Some(datum) else { return }
    let info = discrete_info(
      datum,
      Stem,
      panel_index,
      artist_index,
      series,
      x,
      y,
    )
    hits.points.push(info.point)
    hits.targets.push(@drawing.hit_target(info, Point, bounds))
  })
}
