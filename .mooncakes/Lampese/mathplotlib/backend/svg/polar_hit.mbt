///|
fn polar_inside_circle(
  x : Double,
  y : Double,
  circle : (Double, Double, Double),
) -> Bool {
  let (cx, cy, radius) = circle
  let dx = (x - cx).abs()
  let dy = (y - cy).abs()
  let high = dx.max(dy)
  let low = dx.min(dy)
  let distance = if high == 0.0 {
    0.0
  } else {
    let ratio = low / high
    high * (1.0 + ratio * ratio).sqrt()
  }
  // Affine projection and subtraction can move a mathematical boundary by a
  // few binary64 rounding steps. This matches Drawing admission, independently
  // of CSS scale and hover radius. The raw radial domain is checked separately.
  let roundoff = 4.0 *
    2.220446049250313e-16 *
    x.abs().max(y.abs()).max(cx.abs()).max(cy.abs()).max(radius.abs())
  radius > 0.0 &&
  polar_finite(dx) &&
  polar_finite(dy) &&
  polar_finite(distance) &&
  (distance <= radius || distance - radius <= roundoff)
}

///|
fn collect_polar_point(
  output : DrawingCapture,
  used : Array[Bool],
  source : @render.PolarHitData,
  index : Int32,
  panel_index : Int32,
  artist_index : Int32,
  x : Double,
  y : Double,
  circle : (Double, Double, Double),
  bounds : (Double, Double, Double, Double),
  maximum : Double,
) -> Unit {
  if index < 0 || index >= used.length() || used[index] {
    return
  }
  guard source.point(index) is Some(raw) else { return }
  if !polar_raw_valid(raw) ||
    raw.y() > maximum ||
    !polar_inside_circle(x, y, circle) {
    return
  }
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
    Polar,
    value=raw.y(),
    series=source.series(),
    category=source.category(index),
  )
  used[index] = true
  output.points.push(point)
  output.targets.push(@drawing.hit_target(info, Point, bounds))
}

///|
// Actual valid runs retain original indices. Only the renderer's one appended
// closing vertex can give original sample zero an additional painted endpoint.
fn polar_line_capture(
  output : DrawingCapture?,
  source : @render.PolarHitData?,
  style : @core.Style,
  panel_index : Int32,
  artist_index : Int32,
  position : (Double, Double, Double, Double),
  circle : (Double, Double, Double),
  maximum : Double,
  closed : Bool,
) -> ((Array[@core.Point], Int32) -> Unit)? {
  guard output is Some(hits) && source is Some(data) else { return None }
  if !discrete_line_visible(style) ||
    style.line_stroke().linestyle() != "-" ||
    style.line_stroke().dash_sequence() is Some(_) {
    return None
  }
  let used = [ for _ in 0..<data.length() => false ]
  let (left, top, width, height) = position
  let scale = polar_display_scale()
  Some((points, start) => {
    let screen = points.map(p => {
      (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
    })
    let painted = [ for _ in 0..<screen.length() => false ]
    for i in 0..<(screen.length() - 1) {
      let a = screen[i]
      let b = screen[i + 1]
      if a == b ||
        !polar_finite(a.0) ||
        !polar_finite(a.1) ||
        !polar_finite(b.0) ||
        !polar_finite(b.1) {
        continue
      }
      painted[i] = true
      painted[i + 1] = true
    }
    if closed &&
      start == 0 &&
      screen.length() == data.length() + 1 &&
      screen.length() > 1 &&
      screen[0] == screen[screen.length() - 1] &&
      painted[painted.length() - 1] {
      painted[0] = true
    }
    // Emit original order to preserve first-point ties at coincident anchors.
    for i in 0..<screen.length() {
      if painted[i] {
        let (x, y) = screen[i]
        collect_polar_point(
          hits,
          used,
          data,
          start + i,
          panel_index,
          artist_index,
          x,
          y,
          circle,
          position,
          maximum,
        )
      }
    }
  })
}

///|
fn polar_marker_capture(
  output : DrawingCapture?,
  source : @render.PolarHitData?,
  style : @core.Style,
  panel_index : Int32,
  artist_index : Int32,
  position : (Double, Double, Double, Double),
  circle : (Double, Double, Double),
  maximum : Double,
) -> ((Int32, Double, Double) -> Unit)? {
  guard output is Some(hits) && source is Some(data) else { return None }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  if style.marker() != "o" ||
    style.radius() <= 0.0 ||
    !polar_finite(style.radius()) ||
    !discrete_effective_paint_visible(fill) {
    return None
  }
  let used = [ for _ in 0..<data.length() => false ]
  Some((index, x, y) => {
    collect_polar_point(
      hits, used, data, index, panel_index, artist_index, x, y, circle, position,
      maximum,
    )
  })
}
