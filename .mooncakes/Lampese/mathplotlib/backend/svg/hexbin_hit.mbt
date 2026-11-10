///|
fn hexbin_cross(
  a : (Double, Double),
  b : (Double, Double),
  p : (Double, Double),
) -> Double {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  let qx = p.0 - a.0
  let qy = p.1 - a.1
  let scale = dx.abs().max(dy.abs()).max(qx.abs()).max(qy.abs())
  if scale == 0.0 {
    0.0
  } else {
    dx / scale * (qy / scale) - dy / scale * (qx / scale)
  }
}

///|
// Every other vertex must lie strictly on the same side of every edge. This
// proves the actual mapped face is convex, so the 0--3 diagonal splits it into
// precisely two quadrilaterals, with no hole, overlap, or self-crossing lobe.
fn valid_hexbin_screen(vertices : Array[(Double, Double)]) -> Bool {
  if vertices.length() != 6 {
    return false
  }
  for p in vertices {
    if !hexbin_screen_finite(p.0) || !hexbin_screen_finite(p.1) {
      return false
    }
    for q in vertices {
      if !hexbin_screen_finite(p.0 - q.0) || !hexbin_screen_finite(p.1 - q.1) {
        return false
      }
    }
  }
  let mut orientation = 0.0
  for i in 0..<6 {
    let next = (i + 1) % 6
    for j in 0..<6 {
      if j == i || j == next {
        continue
      }
      let cross = hexbin_cross(vertices[i], vertices[next], vertices[j])
      if cross == 0.0 {
        return false
      }
      if orientation == 0.0 {
        orientation = cross
      } else if (cross > 0.0) != (orientation > 0.0) {
        return false
      }
    }
  }
  true
}

///|
fn hexbin_screen_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
// append_polygon supplies exactly the valid source vertices it just emitted.
// Source bin semantics come from Scene; neither colors nor SVG text are read.
fn collect_drawing_hexbin(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  points : Array[@core.Point],
  scale : Scale,
  position : (Double, Double, Double, Double),
  metadata : @render.HitMetadata,
  style : @core.Style,
) -> Unit {
  guard metadata.hexbin() is Some(bin) else { return }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  if points.length() != 6 ||
    !statistics_paint_visible(fill) ||
    !valid_point(scale, bin.center) {
    return
  }
  let (left, top, width, height) = position
  let screen = points.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  if !valid_hexbin_screen(screen) {
    return
  }
  let mut xmin = screen[0].0
  let mut xmax = xmin
  let mut ymin = screen[0].1
  let mut ymax = ymin
  for (x, y) in screen {
    xmin = xmin.min(x)
    xmax = xmax.max(x)
    ymin = ymin.min(y)
    ymax = ymax.max(y)
  }
  // This is only a conservative visibility cull; true containment below still
  // uses both quadrilaterals. An off-panel center does not discard a face.
  if xmax <= left || xmin >= left + width || ymax <= top || ymin >= top + height {
    return
  }
  let screen_x = map_x(scale, left, width, bin.center.x())
  let screen_y = map_y(scale, top, height, bin.center.y())
  if !hexbin_screen_finite(screen_x) || !hexbin_screen_finite(screen_y) {
    return
  }
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    bin.index,
    bin.center.x(),
    bin.center.y(),
    screen_x,
    screen_y,
  )
  let info = @drawing.hit_info(
    point,
    Hexbin,
    value=bin.value,
    series=metadata.series(),
    hexbin=Some(bin.info),
  )
  output.points.push(point)
  let a = screen[0]
  let b = screen[1]
  let c = screen[2]
  let d = screen[3]
  let e = screen[4]
  let f = screen[5]
  for
    shape in [
      @drawing.HitShape::Quadrilateral(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1),
      @drawing.HitShape::Quadrilateral(a.0, a.1, d.0, d.1, e.0, e.1, f.0, f.1),
    ] {
    output.targets.push(@drawing.hit_target(info, shape, position))
  }
}
