///|
fn violin_screen_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
// The same visible-centerline convention as Drawing's general Segment hit.
// Violin outlines are diagonal, unlike the axis-aligned error-bar helper.
fn violin_visible_segment(
  segment : (Double, Double, Double, Double),
  bounds : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double)? {
  let (x0, y0, x1, y1) = segment
  let (left, top, width, height) = bounds
  let dx = x1 - x0
  let dy = y1 - y0
  for value in [x0, y0, x1, y1, left, top, width, height, dx, dy] {
    if !violin_screen_finite(value) {
      return None
    }
  }
  if width <= 0.0 || height <= 0.0 {
    return None
  }
  let mut first = 0.0
  let mut last = 1.0
  for
    (p, q) in [
      (-dx, x0 - left),
      (dx, left + width - x0),
      (-dy, y0 - top),
      (dy, top + height - y0),
    ] {
    if !violin_screen_finite(q) {
      return None
    }
    if p == 0.0 {
      if q < 0.0 {
        return None
      }
    } else {
      let ratio = q / p
      if p < 0.0 {
        first = first.max(ratio)
      } else {
        last = last.min(ratio)
      }
      if first > last {
        return None
      }
    }
  }
  Some(
    (
      (x0 + first * dx).max(left).min(left + width),
      (y0 + first * dy).max(top).min(top + height),
      (x0 + last * dx).max(left).min(left + width),
      (y0 + last * dy).max(top).min(top + height),
    ),
  )
}

///|
// Clip a convex strip only to find a genuinely visible interior anchor. The
// hit target keeps the original Quad; clipping does not create outline edges.
fn violin_visible_quad_anchor(
  vertices : Array[(Double, Double)],
  bounds : (Double, Double, Double, Double),
) -> (Double, Double)? {
  for (x, y) in vertices {
    if !violin_screen_finite(x) || !violin_screen_finite(y) {
      return None
    }
  }
  let (left, top, width, height) = bounds
  let mut polygon = vertices
  for
    (axis, edge, keep_high) in [
      (0, left, true),
      (0, left + width, false),
      (1, top, true),
      (1, top + height, false),
    ] {
    if polygon.length() == 0 {
      return None
    }
    let result = []
    let coordinate = (p : (Double, Double)) => if axis == 0 { p.0 } else { p.1 }
    let inside = (p : (Double, Double)) => {
      if keep_high {
        coordinate(p) >= edge
      } else {
        coordinate(p) <= edge
      }
    }
    let mut previous = polygon[polygon.length() - 1]
    let mut previous_inside = inside(previous)
    for current in polygon {
      let current_inside = inside(current)
      if current_inside != previous_inside {
        let t = (edge - coordinate(previous)) /
          (coordinate(current) - coordinate(previous))
        let intersection = (
          previous.0 + (current.0 - previous.0) * t,
          previous.1 + (current.1 - previous.1) * t,
        )
        result.push(
          if axis == 0 {
            (edge, intersection.1)
          } else {
            (intersection.0, edge)
          },
        )
      }
      if current_inside {
        result.push(current)
      }
      previous = current
      previous_inside = current_inside
    }
    polygon = result
  }
  if polygon.length() < 3 {
    return None
  }
  let origin = polygon[0]
  let mut area = 0.0
  let mut x = 0.0
  let mut y = 0.0
  for index, p in polygon {
    let q = polygon[(index + 1) % polygon.length()]
    area += (p.0 - origin.0) * (q.1 - origin.1) -
      (p.1 - origin.1) * (q.0 - origin.0)
    x += p.0 / polygon.length().to_double()
    y += p.1 / polygon.length().to_double()
  }
  if area == 0.0 ||
    !violin_screen_finite(area) ||
    !violin_screen_finite(x) ||
    !violin_screen_finite(y) {
    None
  } else {
    Some((x.max(left).min(left + width), y.max(top).min(top + height)))
  }
}
