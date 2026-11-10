///|
// Width is call configuration, independent of the source capture guard. The
// same final sector numbers are used by the SVG and its post-write callback.
fn append_polar_bars(
  writer : @xml.Writer,
  points : Array[@core.Point],
  style : @core.Style,
  config : @render.PolarProjection,
  maximum : Double,
  circle : (Double, Double, Double),
  angular_width : Double,
  on_bar~ : ((Int32, Double, Double, Double, Double, Double, Double, Double) -> Unit)? = None,
) -> Unit {
  let (cx, cy, outer) = circle
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  let whole = angular_width == 2.0 * @math.PI
  let sweep = if whole { 360.0 } else { angular_width * 180.0 / @math.PI }
  for index, raw in points {
    if !polar_raw_valid(raw) || raw.y() <= 0.0 {
      continue
    }
    // Clip before division so a finite raw value above max cannot overflow.
    let radius = outer * (raw.y().min(maximum) / maximum)
    let phi = polar_phi(config, raw.x())
    let start = (phi - angular_width / 2.0) * 180.0 / @math.PI % 360.0
    let start = if start < 0.0 { start + 360.0 } else { start }
    if !polar_finite(radius) ||
      radius <= 0.0 ||
      !polar_finite(sweep) ||
      sweep <= 0.0 {
      continue
    }
    if whole {
      try! writer.empty_element("circle", [
        ("cx", float_text(cx)),
        ("cy", float_text(cy)),
        ("r", float_text(radius)),
        ("fill", fill),
        ("stroke", "none"),
      ])
    } else {
      // A collapsed arc has no representable filled area to capture.
      if pie_point(cx, cy, radius, start) ==
        pie_point(cx, cy, radius, start + sweep) {
        continue
      }
      try! writer.empty_element("path", [
        ("d", pie_path(cx, cy, radius, start, start + sweep)),
        ("fill", fill),
        ("stroke", "none"),
      ])
    }
    if discrete_effective_paint_visible(fill) && on_bar is Some(capture) {
      capture(
        index,
        cx,
        cy,
        radius,
        start,
        sweep,
        cx + radius / 2.0 * @math.cos(phi),
        cy - radius / 2.0 * @math.sin(phi),
      )
    }
  }
}

///|
fn polar_bar_capture(
  output : DrawingCapture?,
  source : @render.PolarHitData?,
  panel_index : Int32,
  artist_index : Int32,
  bounds : (Double, Double, Double, Double),
) -> ((Int32, Double, Double, Double, Double, Double, Double, Double) -> Unit)? {
  guard output is Some(hits) && source is Some(data) else { return None }
  Some((index, cx, cy, radius, start, sweep, x, y) => {
    guard data.point(index) is Some(raw) else { return }
    let point = @drawing.hit_point(
      panel_index,
      artist_index,
      index,
      raw.x(),
      raw.y(),
      x,
      y,
    )
    let info = @drawing.hit_info(
      point,
      PolarBar,
      value=raw.y(),
      series=data.series(),
    )
    hits.points.push(point)
    hits.targets.push(
      @drawing.hit_target(info, Sector(cx, cy, radius, start, sweep), bounds),
    )
  })
}
