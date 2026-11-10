///|
fn quad_cross(
  a : (Double, Double),
  b : (Double, Double),
  c : (Double, Double),
) -> Double {
  let dx = b.0 - a.0
  let dy = b.1 - a.1
  let qx = c.0 - a.0
  let qy = c.1 - a.1
  // Normalize before multiplying, so ordinary large finite coordinates do not
  // overflow the cross product. Nonfinite differences are rejected by callers.
  let scale = dx.abs().max(dy.abs()).max(qx.abs()).max(qy.abs())
  if scale == 0.0 {
    0.0
  } else {
    dx / scale * (qy / scale) - dy / scale * (qx / scale)
  }
}

///|
fn valid_quad(
  a : (Double, Double),
  b : (Double, Double),
  c : (Double, Double),
  d : (Double, Double),
) -> Bool {
  let vertices = [a, b, c, d]
  for p in vertices {
    if !finite(p.0) || !finite(p.1) {
      return false
    }
    for q in vertices {
      if !finite(p.0 - q.0) || !finite(p.1 - q.1) {
        return false
      }
    }
  }
  // A crossing band can have zero signed polygon area while both lobes are
  // visible. Reject only collinear geometry, rather than cancelling its lobes.
  quad_cross(a, b, c) != 0.0 ||
  quad_cross(a, b, d) != 0.0 ||
  quad_cross(a, c, d) != 0.0
}

///|
fn quad_contains(
  a : (Double, Double),
  b : (Double, Double),
  c : (Double, Double),
  d : (Double, Double),
  x : Double,
  y : Double,
) -> Bool {
  let vertices = [a, b, c, d]
  let mut inside = false
  for index in 0..<4 {
    let a = vertices[index]
    let b = vertices[(index + 1) % 4]
    // Include true edges, including the shared split between real samples.
    if quad_cross(a, b, (x, y)) == 0.0 &&
      x >= a.0.min(b.0) &&
      x <= a.0.max(b.0) &&
      y >= a.1.min(b.1) &&
      y <= a.1.max(b.1) {
      return true
    }
    if (a.1 > y) != (b.1 > y) {
      let crossing = a.0 + (y - a.1) / (b.1 - a.1) * (b.0 - a.0)
      if x < crossing {
        inside = !inside
      }
    }
  }
  inside
}
