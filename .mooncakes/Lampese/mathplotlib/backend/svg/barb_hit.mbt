///|
fn barb_stroke_for_paint(
  view : @render.BarbHitView?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.BarbHitView? {
  guard view is Some(data) else { return None }
  if data.component() is @render.BarbComponent::Stroke &&
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
fn push_barb_target(
  hits : DrawingCapture,
  view : @render.BarbHitView,
  panel_index : Int32,
  artist_index : Int32,
  bounds : (Double, Double, Double, Double),
  shape : @drawing.HitShape,
  x : Double,
  y : Double,
) -> Unit {
  guard view.datum() is Some(datum) else { return }
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    datum.index,
    datum.point.x(),
    datum.point.y(),
    x,
    y,
  )
  let info = @drawing.hit_info(
    point,
    Barbs,
    value=datum.vector.v,
    vector=Some(datum.vector),
    series=view.series(),
  )
  hits.points.push(point)
  hits.targets.push(@drawing.hit_target(info, shape, bounds))
}

///|
fn collect_barb_segment(
  hits : DrawingCapture,
  view : @render.BarbHitView,
  panel_index : Int32,
  artist_index : Int32,
  bounds : (Double, Double, Double, Double),
  segment : (Double, Double, Double, Double),
) -> Unit {
  if segment.0 == segment.2 && segment.1 == segment.3 {
    return
  }
  guard violin_visible_segment(segment, bounds) is Some((x0, y0, x1, y1)) else {
    return
  }
  push_barb_target(
    hits,
    view,
    panel_index,
    artist_index,
    bounds,
    Segment(segment.0, segment.1, segment.2, segment.3),
    x0 / 2.0 + x1 / 2.0,
    y0 / 2.0 + y1 / 2.0,
  )
}

///|
fn barb_stroke_capture(
  output : DrawingCapture?,
  source : @render.BarbHitView?,
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
      collect_barb_segment(
        hits,
        view,
        panel_index,
        artist_index,
        bounds,
        (
          map_x(scale, left, width, a.x()),
          map_y(scale, top, height, a.y()),
          map_x(scale, left, width, b.x()),
          map_y(scale, top, height, b.y()),
        ),
      )
    }
  })
}

///|
fn collect_barb_flag(
  hits : DrawingCapture,
  source : @render.BarbHitView?,
  panel_index : Int32,
  artist_index : Int32,
  points : Array[@core.Point],
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  style : @core.Style,
) -> Unit {
  guard source is Some(view) else { return }
  if !(view.component() is @render.BarbComponent::Flag) ||
    !view.matches_points(points) {
    return
  }
  let (left, top, width, height) = bounds
  let screen = points.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let a = screen[0]
  let b = screen[1]
  let c = screen[2]
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  let mut finite = true
  for p in screen {
    for q in screen {
      if !violin_screen_finite(p.0) ||
        !violin_screen_finite(p.1) ||
        !violin_screen_finite(p.0 - q.0) ||
        !violin_screen_finite(p.1 - q.1) {
        finite = false
      }
    }
  }
  if finite && discrete_effective_paint_visible(fill) {
    if violin_visible_quad_anchor(screen, bounds) is Some((x, y)) {
      push_barb_target(
        hits,
        view,
        panel_index,
        artist_index,
        bounds,
        Quadrilateral(a.0, a.1, b.0, b.1, c.0, c.1, c.0, c.1),
        x,
        y,
      )
    }
  }
  // Polygon writes its own stroke, independently of its fill or Line alpha.
  if style.width() != 0.0 && discrete_effective_paint_visible(style.color()) {
    for i in 0..<3 {
      let a = screen[i]
      let b = screen[(i + 1) % 3]
      collect_barb_segment(
        hits,
        view,
        panel_index,
        artist_index,
        bounds,
        (a.0, a.1, b.0, b.1),
      )
    }
  }
}

///|
fn barb_calm_for_paint(
  view : @render.BarbHitView?,
  points : Array[@core.Point],
  style : @core.Style,
) -> @render.BarbHitView? {
  guard view is Some(data) else { return None }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  if data.component() is @render.BarbComponent::Calm &&
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
fn barb_calm_capture(
  output : DrawingCapture?,
  source : @render.BarbHitView?,
  panel_index : Int32,
  artist_index : Int32,
  bounds : (Double, Double, Double, Double),
  radius : Double,
) -> ((Int32, Double, Double) -> Unit)? {
  guard output is Some(hits) else { return None }
  guard source is Some(view) else { return None }
  Some((_, cx, cy) => {
    if !violin_screen_finite(cx) || !violin_screen_finite(cy) {
      return
    }
    let (left, top, width, height) = bounds
    let x = cx.max(left).min(left + width)
    let y = cy.max(top).min(top + height)
    let dx = (x - cx).abs()
    let dy = (y - cy).abs()
    let scale = dx.max(dy)
    let distance = if scale == 0.0 {
      0.0
    } else {
      scale * (dx / scale * (dx / scale) + dy / scale * (dy / scale)).sqrt()
    }
    if !violin_screen_finite(distance) || distance > radius {
      return
    }
    push_barb_target(
      hits,
      view,
      panel_index,
      artist_index,
      bounds,
      Sector(cx, cy, radius, 0.0, 360.0),
      x,
      y,
    )
  })
}
