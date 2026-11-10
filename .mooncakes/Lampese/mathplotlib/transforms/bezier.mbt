///|
/// Errors raised by Bezier segment construction and sampling.
pub(all) suberror BezierError {
  InvalidControlPoints(message~ : String)
  InvalidParameter(message~ : String)
}

///|
/// A quadratic or cubic Bezier segment.
pub struct BezierSegment {
  control_points : Array[@core.Point]
}

///|
fn validate_controls(points : Array[@core.Point]) -> Unit raise BezierError {
  if points.length() != 3 && points.length() != 4 {
    raise BezierError::InvalidControlPoints(
      message="a Bezier segment needs three or four control points",
    )
  }
  for point in points {
    if !point.is_finite() {
      raise BezierError::InvalidControlPoints(
        message="Bezier control points must be finite",
      )
    }
  }
}

///|
/// Construct a quadratic Bezier segment.
pub fn quadratic_bezier(
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
) -> BezierSegment raise BezierError {
  let points = [start, control, end]
  validate_controls(points)
  { control_points: points, }
}

///|
/// Construct a cubic Bezier segment.
pub fn cubic_bezier(
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
) -> BezierSegment raise BezierError {
  let points = [start, control1, control2, end]
  validate_controls(points)
  { control_points: points, }
}

///|
pub fn BezierSegment::control_points(
  self : BezierSegment,
) -> Array[@core.Point] {
  self.control_points.copy()
}

///|
pub fn BezierSegment::degree(self : BezierSegment) -> Int32 {
  self.control_points.length() - 1
}

///|
fn lerp_point(
  first : @core.Point,
  second : @core.Point,
  t : Double,
) -> @core.Point {
  @core.point(
    first.x() + (second.x() - first.x()) * t,
    first.y() + (second.y() - first.y()) * t,
  )
}

///|
fn validate_parameter(value : Double) -> Unit raise BezierError {
  if value.is_nan() || value.is_inf() {
    raise BezierError::InvalidParameter(
      message="Bezier parameter must be finite",
    )
  }
}

///|
/// Evaluate the segment at parameter `t` using de Casteljau interpolation.
pub fn BezierSegment::evaluate(
  self : BezierSegment,
  t : Double,
) -> @core.Point raise BezierError {
  validate_parameter(t)
  let mut level = self.control_points.copy()
  while level.length() > 1 {
    let next = Array(capacity=level.length() - 1)
    for index in 0..<(level.length() - 1) {
      next.push(lerp_point(level[index], level[index + 1], t))
    }
    level = next
  }
  level[0]
}

///|
/// Split the segment into two segments at parameter `t`.
pub fn BezierSegment::split(
  self : BezierSegment,
  t : Double,
) -> (BezierSegment, BezierSegment) raise BezierError {
  validate_parameter(t)
  if t < 0.0 || t > 1.0 {
    raise BezierError::InvalidParameter(
      message="split parameter must be in [0, 1]",
    )
  }
  let p = self.control_points
  let first = lerp_point(p[0], p[1], t)
  if p.length() == 3 {
    let second = lerp_point(p[1], p[2], t)
    let middle = lerp_point(first, second, t)
    (
      quadratic_bezier(p[0], first, middle),
      quadratic_bezier(middle, second, p[2]),
    )
  } else {
    let second = lerp_point(p[1], p[2], t)
    let third = lerp_point(p[2], p[3], t)
    let first_middle = lerp_point(first, second, t)
    let second_middle = lerp_point(second, third, t)
    let middle = lerp_point(first_middle, second_middle, t)
    (
      cubic_bezier(p[0], first, first_middle, middle),
      cubic_bezier(middle, second_middle, third, p[3]),
    )
  }
}

///|
/// Sample a polyline approximation with `steps` equal intervals.
pub fn BezierSegment::sample(
  self : BezierSegment,
  steps : Int32,
) -> Array[@core.Point] raise BezierError {
  if steps <= 0 {
    raise BezierError::InvalidParameter(message="sample steps must be positive")
  }
  let result = Array(capacity=steps + 1)
  for index in 0..<=steps {
    result.push(
      self.evaluate(Double::from_int(index) / Double::from_int(steps)),
    )
  }
  result
}

///|
/// Approximate arc length by summing a sampled polyline.
pub fn BezierSegment::length(
  self : BezierSegment,
  steps~ : Int32 = 32,
) -> Double raise BezierError {
  let samples = self.sample(steps)
  let mut total = 0.0
  for index in 1..<samples.length() {
    let dx = samples[index].x() - samples[index - 1].x()
    let dy = samples[index].y() - samples[index - 1].y()
    total += (dx * dx + dy * dy).sqrt()
  }
  total
}
