///|
// Liang-Barsky clipping keeps proximity attached to the visible centerline,
// so an off-panel segment cannot create a radius hit through an axes edge.
fn clip_segment(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  bounds : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double)? {
  let (left, top, width, height) = bounds
  let dx = x1 - x0
  let dy = y1 - y0
  if !valid_rect(bounds) || !finite(dx) || !finite(dy) {
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
    if !finite(q) {
      return None
    }
    if p == 0.0 {
      if q < 0.0 {
        return None
      }
    } else {
      let ratio = q / p
      if p < 0.0 {
        first = Double::max(first, ratio)
      } else {
        last = Double::min(last, ratio)
      }
      if first > last {
        return None
      }
    }
  }
  // Clamp the reconstructed points to remove roundoff at the clipping edge.
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
fn segment_distance(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  bounds : (Double, Double, Double, Double),
  x : Double,
  y : Double,
) -> Double? {
  guard clip_segment(x0, y0, x1, y1, bounds) is Some((x0, y0, x1, y1)) else {
    return None
  }
  let dx = x1 - x0
  let dy = y1 - y0
  let length = hit_distance(dx, dy)
  if length == 0.0 {
    return Some(hit_distance(x - x0, y - y0))
  }
  let ux = dx / length
  let uy = dy / length
  let along = (x - x0) * ux + (y - y0) * uy
  Some(
    if along <= 0.0 {
      hit_distance(x - x0, y - y0)
    } else if along >= length {
      hit_distance(x - x1, y - y1)
    } else {
      // The perpendicular distance avoids reconstructing a projected point and
      // introducing spurious distance at exact diagonal centerline coordinates.
      ((x - x0) * uy - (y - y0) * ux).abs()
    },
  )
}
