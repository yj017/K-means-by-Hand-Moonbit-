///|
fn filled_region_noncollinear(
  a : (Double, Double),
  b : (Double, Double),
  c : (Double, Double),
) -> Bool {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  let qx = c.0 - a.0
  let qy = c.1 - a.1
  let magnitude = dx.abs().max(dy.abs()).max(qx.abs()).max(qy.abs())
  magnitude != 0.0 &&
  dx / magnitude * (qy / magnitude) - dy / magnitude * (qx / magnitude) != 0.0
}

///|
// Shared actual fill geometry only. Semantic ownership stays with each caller.
fn collect_filled_region(
  hits : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  point_index : Int32,
  rings : Array[Array[@core.Point]],
  even_odd : Bool,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  style : @core.Style,
  figure_width : Int32,
  figure_height : Int32,
  make_info : (@drawing.HitPoint) -> @drawing.HitInfo,
) -> Unit {
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  if !discrete_effective_paint_visible(fill) {
    return
  }
  let (left, top, width, height) = bounds
  let screen = []
  let mut first_data : (Double, Double)? = None
  let mut anchor : (Double, Double, Double, Double)? = None
  let mut noncollinear = false
  let mut xmin = 1.0 / 0.0
  let mut xmax = -1.0 / 0.0
  let mut ymin = 1.0 / 0.0
  let mut ymax = -1.0 / 0.0
  for ring in rings {
    if ring.length() < 3 {
      continue
    }
    let mapped = ring.map(p => {
      (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
    })
    let first = mapped[0]
    let mut second = first
    for p in mapped {
      if !violin_screen_finite(p.0) || !violin_screen_finite(p.1) {
        return
      }
      xmin = xmin.min(p.0)
      xmax = xmax.max(p.0)
      ymin = ymin.min(p.1)
      ymax = ymax.max(p.1)
      if second == first && p != first {
        second = p
      }
    }
    let ring_area = mapped.any(p => filled_region_noncollinear(first, second, p))
    noncollinear = noncollinear || ring_area
    if !ring_area {
      screen.push(mapped)
      continue
    }
    for i, a in mapped {
      let b = mapped[(i + 1) % mapped.length()]
      if a == b {
        continue
      }
      let from = ring[i]
      let to = ring[(i + 1) % ring.length()]
      let dx = from.x() / 2.0 + to.x() / 2.0
      let dy = from.y() / 2.0 + to.y() / 2.0
      if !violin_screen_finite(dx) || !violin_screen_finite(dy) {
        return
      }
      if first_data is None {
        first_data = Some((dx, dy))
      }
      if anchor is None {
        if violin_visible_segment((a.0, a.1, b.0, b.1), bounds)
          is Some((x0, y0, x1, y1)) {
          anchor = Some((dx, dy, x0 / 2.0 + x1 / 2.0, y0 / 2.0 + y1 / 2.0))
        }
      }
    }
    screen.push(mapped)
  }
  if !noncollinear ||
    !violin_screen_finite(xmax - xmin) ||
    !violin_screen_finite(ymax - ymin) {
    return
  }
  guard first_data is Some(first) else { return }
  let region = @drawing.filled_region(screen, even_odd~)
  let (dx, dy, x, y) = anchor.unwrap_or(
    (first.0, first.1, left + width / 2.0, top + height / 2.0),
  )
  let point = @drawing.hit_point(
    panel_index, artist_index, point_index, dx, dy, x, y,
  )
  let info = make_info(point)
  let target = @drawing.hit_target(info, FilledRegion(region), bounds)
  if anchor is None {
    // Reuse Drawing's private cached-region containment exactly once. There
    // is no second winding implementation or whole-region copy here.
    let probe = @drawing.drawing(figure_width, figure_height, "", [], targets=[
      target,
    ])
    if probe.hit_test(x, y, radius=0.0) is None {
      return
    }
  }
  hits.points.push(point)
  hits.targets.push(target)
}
