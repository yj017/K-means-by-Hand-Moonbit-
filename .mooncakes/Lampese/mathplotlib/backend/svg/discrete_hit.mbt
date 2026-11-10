///|
fn discrete_line_visible(style : @core.Style) -> Bool {
  style.width() > 0.0 &&
  style.line_stroke().linestyle() != "None" &&
  style.line_alpha().unwrap_or(1.0) > 0.0 &&
  discrete_effective_paint_visible(style.color())
}

///|
// A Line2D color setter resolves to Rgba::to_css at draw time. The small
// color parser does not read its generated rgba(r,g,b,a) spelling.
fn discrete_effective_paint_visible(paint : String) -> Bool {
  let color = paint.trim().to_owned().to_lower()
  if color.split_once("rgba(") is Some((prefix, body)) &&
    prefix.is_empty() &&
    body.split_once(")") is Some((components, suffix)) &&
    suffix.is_empty() {
    match components.split(",").to_array() {
      [_, _, _, alpha] =>
        return try
          @ticker.parse_float_text(alpha.trim().to_owned()) > 0.0
        catch {
          _ => true
        }
      _ => ()
    }
  }
  statistics_paint_visible(color)
}

///|
fn discrete_line_for_paint(
  data : @render.DiscreteLineHitData?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.DiscreteLineHitData? {
  guard data is Some(source) else { return None }
  if discrete_line_visible(style) &&
    style.line_stroke().linestyle() == "-" &&
    style.line_stroke().dash_sequence() is None &&
    source.matches_path(points) {
    Some(source)
  } else {
    None
  }
}

///|
fn discrete_line_capture(
  output : DrawingCapture?,
  source : @render.DiscreteLineHitData?,
  panel_index : Int32,
  artist_index : Int32,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  series : String,
) -> ((Array[@core.Point], Int32) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(data) else { return None }
  let used : Map[Int32, Bool] = Map([])
  Some((points, start) => {
    collect_drawing_discrete_line(
      hits, used, panel_index, artist_index, points, start, data, scale, bounds,
      series,
    )
  })
}

///|
fn discrete_info(
  datum : @render.DiscreteDatum,
  kind : @drawing.HitKind,
  panel_index : Int32,
  artist_index : Int32,
  series : String,
  x : Double,
  y : Double,
) -> @drawing.HitInfo {
  @drawing.hit_info(
    @drawing.hit_point(
      panel_index,
      artist_index,
      datum.index,
      datum.point.x(),
      datum.point.y(),
      x,
      y,
    ),
    kind,
    value=datum.value,
    series~,
    interval=datum.interval,
    fraction=datum.fraction,
    band=datum.band,
  )
}

///|
fn collect_discrete_source_point(
  output : DrawingCapture,
  used : Map[Int32, Bool],
  source : @render.DiscreteLineHitData,
  slot : Int32,
  panel_index : Int32,
  artist_index : Int32,
  series : String,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  segment : (Double, Double, Double, Double),
) -> Unit {
  if used.get(slot) is Some(_) {
    return
  }
  guard source.datum(slot) is Some(datum) else { return }
  if !valid_point(scale, datum.point) {
    return
  }
  let (left, top, width, height) = bounds
  let x = map_x(scale, left, width, datum.point.x())
  let y = map_y(scale, top, height, datum.point.y())
  let (x0, y0, x1, y1) = segment
  if x < left ||
    x > left + width ||
    y < top ||
    y > top + height ||
    !violin_screen_finite(x) ||
    !violin_screen_finite(y) ||
    !((x0 == x1 && x == x0 && y >= y0.min(y1) && y <= y0.max(y1)) ||
    (y0 == y1 && y == y0 && x >= x0.min(x1) && x <= x0.max(x1))) {
    return
  }
  let info = discrete_info(
    datum,
    source.kind,
    panel_index,
    artist_index,
    series,
    x,
    y,
  )
  used[slot] = true
  output.points.push(info.point)
  output.targets.push(@drawing.hit_target(info, Point, bounds))
}

///|
// Called only after this exact valid run has been written. source_start is
// the original complete-path index, never an index in a filtered array.
fn collect_drawing_discrete_line(
  output : DrawingCapture,
  used : Map[Int32, Bool],
  panel_index : Int32,
  artist_index : Int32,
  points : Array[@core.Point],
  source_start : Int32,
  source : @render.DiscreteLineHitData,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  series : String,
) -> Unit {
  let (left, top, width, height) = bounds
  let screen = points.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let mut has_stroke = false
  for i in 0..<(screen.length() - 1) {
    let a = screen[i]
    let b = screen[i + 1]
    if violin_screen_finite(a.0) &&
      violin_screen_finite(a.1) &&
      violin_screen_finite(b.0) &&
      violin_screen_finite(b.1) &&
      a != b {
      has_stroke = true
      break
    }
  }
  if !has_stroke {
    return
  }
  for i in 0..<(points.length() - 1) {
    guard source.owner(source_start + i) is Some(owner) else { continue }
    guard source.datum(owner) is Some(datum) else { continue }
    if !valid_point(scale, datum.point) || !violin_screen_finite(datum.value) {
      continue
    }
    let a = screen[i]
    let b = screen[i + 1]
    let segment = (a.0, a.1, b.0, b.1)
    if segment.0 == segment.2 && segment.1 == segment.3 {
      // A zero-weight/duplicate return slot can lie on a zero edge of a
      // connected painted run. Keep its real endpoint, never a zero-length
      // Segment. A wholly zero run was rejected above.
      collect_discrete_source_point(
        output, used, source, owner, panel_index, artist_index, series, scale, bounds,
        segment,
      )
      if owner > 0 {
        collect_discrete_source_point(
          output,
          used,
          source,
          owner - 1,
          panel_index,
          artist_index,
          series,
          scale,
          bounds,
          segment,
        )
      }
      collect_discrete_source_point(
        output,
        used,
        source,
        owner + 1,
        panel_index,
        artist_index,
        series,
        scale,
        bounds,
        segment,
      )
      continue
    }
    guard violin_visible_segment(segment, bounds) is Some((x0, y0, x1, y1)) else {
      continue
    }
    let info = discrete_info(
      datum,
      source.kind,
      panel_index,
      artist_index,
      series,
      x0 / 2.0 + x1 / 2.0,
      y0 / 2.0 + y1 / 2.0,
    )
    output.targets.push(
      @drawing.hit_target(
        info,
        Segment(segment.0, segment.1, segment.2, segment.3),
        bounds,
      ),
    )
    collect_discrete_source_point(
      output, used, source, owner, panel_index, artist_index, series, scale, bounds,
      segment,
    )
    // Adjacent canonical slots may be endpoints of this edge: pre steps
    // begin a jump at the previous sample, and a zero-weight ECDF slot can
    // end the preceding plateau. Their source indices remain selectable.
    if owner > 0 {
      collect_discrete_source_point(
        output,
        used,
        source,
        owner - 1,
        panel_index,
        artist_index,
        series,
        scale,
        bounds,
        segment,
      )
    }
    collect_discrete_source_point(
      output,
      used,
      source,
      owner + 1,
      panel_index,
      artist_index,
      series,
      scale,
      bounds,
      segment,
    )
  }
}
