///|
/// Errors raised by transform operations.
pub(all) suberror TransformError {
  Singular
}

///|
/// A two-dimensional affine transform represented as
/// x' = a*x + c*y + e and y' = b*x + d*y + f.
pub struct Affine2D {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
}

///|
/// Construct the identity transform.
pub fn identity() -> Affine2D {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0, }
}

///|
/// Construct a translation transform.
pub fn translation(x : Double, y : Double) -> Affine2D {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: x, f: y, }
}

///|
/// Construct a scaling transform.
pub fn scaling(x : Double, y : Double) -> Affine2D {
  { a: x, b: 0.0, c: 0.0, d: y, e: 0.0, f: 0.0, }
}

///|
/// Construct an affine transform directly from the six non-trivial matrix
/// values. The matrix is
/// `[[a, c, e], [b, d, f], [0, 0, 1]]`.
pub fn affine_from_values(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> Affine2D {
  { a, b, c, d, e, f, }
}

///|
/// Construct a counter-clockwise rotation in radians around the origin.
pub fn rotation(radians : Double) -> Affine2D {
  let cosine = @math.cos(radians)
  let sine = @math.sin(radians)
  { a: cosine, b: sine, c: -sine, d: cosine, e: 0.0, f: 0.0, }
}

///|
/// Construct a rotation in degrees around the origin.
pub fn rotation_degrees(degrees : Double) -> Affine2D {
  rotation(degrees * @math.PI / 180.0)
}

///|
/// Construct an x/y shear transform. The arguments are shear angles in
/// radians, matching Matplotlib's `Affine2D.skew` convention.
pub fn skew(x_radians : Double, y_radians : Double) -> Affine2D {
  {
    a: 1.0,
    b: @math.tan(y_radians),
    c: @math.tan(x_radians),
    d: 1.0,
    e: 0.0,
    f: 0.0,
  }
}

///|
/// Construct an x/y shear transform from degree angles.
pub fn skew_degrees(x_degrees : Double, y_degrees : Double) -> Affine2D {
  skew(x_degrees * @math.PI / 180.0, y_degrees * @math.PI / 180.0)
}

///|
/// Compose transforms so the returned transform applies `other` first.
pub fn Affine2D::then(self : Affine2D, other : Affine2D) -> Affine2D {
  {
    a: self.a * other.a + self.c * other.b,
    b: self.b * other.a + self.d * other.b,
    c: self.a * other.c + self.c * other.d,
    d: self.b * other.c + self.d * other.d,
    e: self.a * other.e + self.c * other.f + self.e,
    f: self.b * other.e + self.d * other.f + self.f,
  }
}

///|
/// Compose two transforms using the same order as `then`.
pub fn Affine2D::compose(self : Affine2D, other : Affine2D) -> Affine2D {
  self.then(other)
}

///|
/// Return the six affine matrix values in `(a, b, c, d, e, f)` order.
pub fn Affine2D::to_values(
  self : Affine2D,
) -> (Double, Double, Double, Double, Double, Double) {
  (self.a, self.b, self.c, self.d, self.e, self.f)
}

///|
/// Return the affine matrix as three row-major rows.
pub fn Affine2D::matrix(self : Affine2D) -> Array[Array[Double]] {
  [[self.a, self.c, self.e], [self.b, self.d, self.f], [0.0, 0.0, 1.0]]
}

///|
/// Whether x and y are transformed independently.
pub fn Affine2D::is_separable(self : Affine2D) -> Bool {
  self.b == 0.0 && self.c == 0.0
}

///|
/// Apply a transform to one point.
pub fn Affine2D::apply(self : Affine2D, value : @core.Point) -> @core.Point {
  @core.point(
    self.a * value.x() + self.c * value.y() + self.e,
    self.b * value.x() + self.d * value.y() + self.f,
  )
}

///|
/// Apply only the linear part of a transform to a displacement vector.
pub fn Affine2D::apply_delta(
  self : Affine2D,
  value : @core.Point,
) -> @core.Point {
  @core.point(
    self.a * value.x() + self.c * value.y(),
    self.b * value.x() + self.d * value.y(),
  )
}

///|
/// Return a transform with an additional translation applied after `self`.
pub fn Affine2D::translated(
  self : Affine2D,
  x : Double,
  y : Double,
) -> Affine2D {
  translation(x, y).then(self)
}

///|
/// Return a transform with an additional scale applied after `self`.
pub fn Affine2D::scaled(self : Affine2D, x : Double, y : Double) -> Affine2D {
  scaling(x, y).then(self)
}

///|
/// Return a transform with an additional rotation applied after `self`.
pub fn Affine2D::rotated(self : Affine2D, radians : Double) -> Affine2D {
  rotation(radians).then(self)
}

///|
/// Return a transform with an additional shear applied after `self`.
pub fn Affine2D::skewed(
  self : Affine2D,
  x_radians : Double,
  y_radians : Double,
) -> Affine2D {
  skew(x_radians, y_radians).then(self)
}

///|
/// Apply a transform to an array without mutating the input.
pub fn Affine2D::apply_all(
  self : Affine2D,
  values : Array[@core.Point],
) -> Array[@core.Point] {
  let result = Array(capacity=values.length())
  for value in values {
    result.push(self.apply(value))
  }
  result
}

///|
/// Return the linear-part determinant.
pub fn Affine2D::determinant(self : Affine2D) -> Double {
  self.a * self.d - self.b * self.c
}

///|
/// Compute the inverse transform.
pub fn Affine2D::inverse(self : Affine2D) -> Affine2D raise TransformError {
  let determinant = self.determinant()
  if determinant == 0.0 || determinant.is_nan() || determinant.is_inf() {
    raise TransformError::Singular
  }
  let inverse_determinant = 1.0 / determinant
  let a = self.d * inverse_determinant
  let b = -self.b * inverse_determinant
  let c = -self.c * inverse_determinant
  let d = self.a * inverse_determinant
  { a, b, c, d, e: -(a * self.e + c * self.f), f: -(b * self.e + d * self.f), }
}
