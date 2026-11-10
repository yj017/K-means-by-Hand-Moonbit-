///|
// Only polar-bar area geometry needs projection-roundoff allowance. Keep the
// legacy Sector/Pie policy unchanged, and never widen a face by hit_radius.
fn HitTarget::area_contains(self : HitTarget, x : Double, y : Double) -> Bool {
  guard self.info.kind == PolarBar &&
    self.shape is Sector(cx, cy, radius, start, sweep) else {
    return shape_contains(self.shape, x, y)
  }
  let dx = x - cx
  let dy = cy - y
  let distance = hit_distance(dx, dy)
  let radial_roundoff = 4.0 *
    2.220446049250313e-16 *
    x.abs().max(y.abs()).max(cx.abs()).max(cy.abs()).max(radius.abs())
  if !finite(dx) ||
    !finite(dy) ||
    !finite(distance) ||
    (distance > radius && distance - radius > radial_roundoff) {
    return false
  }
  if (dx == 0.0 && dy == 0.0) || sweep >= 360.0 {
    return true
  }
  let angle = @math.atan2(dy, dx) * 180.0 / @math.PI
  let offset = degrees_normalized(
    degrees_normalized(angle) - degrees_normalized(start),
  )
  let angular_roundoff = 4.0 * 360.0 * 2.220446049250313e-16
  offset <= sweep ||
  offset - sweep <= angular_roundoff ||
  360.0 - offset <= angular_roundoff
}

///|
// The circle center and rectangle's right edge are independently rounded.
// Admit only that numeric discrepancy before testing the actual polar sector.
fn HitTarget::area_bounds_contains(
  self : HitTarget,
  x : Double,
  y : Double,
) -> Bool {
  if self.info.kind != PolarBar {
    return rect_contains(self.bounds, x, y)
  }
  guard valid_rect(self.bounds) else { return false }
  let (left, top, width, height) = self.bounds
  let right = left + width
  let bottom = top + height
  let roundoff = 4.0 *
    2.220446049250313e-16 *
    x
    .abs()
    .max(y.abs())
    .max(left.abs())
    .max(top.abs())
    .max(right.abs())
    .max(bottom.abs())
  (x >= left || left - x <= roundoff) &&
  (x <= right || x - right <= roundoff) &&
  (y >= top || top - y <= roundoff) &&
  (y <= bottom || y - bottom <= roundoff)
}
