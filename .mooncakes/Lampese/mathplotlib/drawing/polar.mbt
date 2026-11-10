///|
fn valid_polar_circle(circle : (Double, Double, Double)) -> Bool {
  finite(circle.0) && finite(circle.1) && finite(circle.2) && circle.2 > 0.0
}

///|
fn copy_polar_circles(
  records : Array[(Int32, (Double, Double, Double))],
) -> Map[Int32, (Double, Double, Double)?] {
  let result : Map[Int32, (Double, Double, Double)?] = Map([])
  for (panel, circle) in records {
    let value = if panel >= 0 && valid_polar_circle(circle) {
      Some(circle)
    } else {
      None
    }
    match result.get(panel) {
      None => result[panel] = value
      Some(previous) => if previous != value { result[panel] = None }
    }
  }
  result
}

///|
/// The exact immutable data-clip circle for this prepared polar panel.
/// Invalid or conflicting records return None and keep their panel unselectable.
pub fn Drawing::polar_circle(
  self : Drawing,
  panel_index : Int32,
) -> (Double, Double, Double)? {
  self.polar_circles.get(panel_index).bind(value => value)
}

///|
fn Drawing::polar_admits(
  self : Drawing,
  panel_index : Int32,
  x : Double,
  y : Double,
  required : Bool,
) -> Bool {
  match self.polar_circles.get(panel_index) {
    None => !required
    Some(None) => false
    Some(Some((cx, cy, radius))) => {
      let dx = x - cx
      let dy = y - cy
      let distance = hit_distance(dx, dy)
      // Use the same projection-roundoff bound as the polar collector. It is
      // intrinsic numeric error, never a CSS or caller-supplied hit tolerance.
      let roundoff = 4.0 *
        2.220446049250313e-16 *
        x.abs().max(y.abs()).max(cx.abs()).max(cy.abs()).max(radius.abs())
      finite(dx) &&
      finite(dy) &&
      finite(distance) &&
      (distance <= radius || distance - radius <= roundoff)
    }
  }
}

///|
fn HitKind::requires_polar_circle(self : HitKind) -> Bool {
  self is (Polar | PolarBar)
}
