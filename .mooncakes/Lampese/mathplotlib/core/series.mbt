///|
/// Paired x/y samples with a length invariant.
pub struct Series {
  xs : Array[Double]
  ys : Array[Double]
}

///|
/// Construct a series. The two input arrays must have the same length.
pub fn series(xs : Array[Double], ys : Array[Double]) -> Series raise DataError {
  if xs.length() != ys.length() {
    raise DataError::LengthMismatch(expected=xs.length(), actual=ys.length())
  }
  { xs: xs.copy(), ys: ys.copy(), }
}

///|
/// Number of samples in a series.
pub fn Series::length(self : Series) -> Int32 {
  self.xs.length()
}

///|
/// Return the x samples in their original order, including non-finite values.
pub fn Series::x(self : Series) -> Array[Double] {
  self.xs.copy()
}

///|
/// Return the y samples in their original order, including non-finite values.
pub fn Series::y(self : Series) -> Array[Double] {
  self.ys.copy()
}

///|
/// Convert paired samples to points without dropping missing values.
pub fn Series::points(self : Series) -> Array[Point] {
  let points = Array(capacity=self.length())
  for i in 0..<self.length() {
    points.push(point(self.xs[i], self.ys[i]))
  }
  points
}

///|
/// Compute limits from finite samples only.
pub fn Series::finite_bounds(self : Series) -> Bounds? {
  bounds_from_points(self.points())
}

///|
/// Compute limits from finite points only. Missing points are ignored.
pub fn bounds_from_points(points : Array[Point]) -> Bounds? {
  let mut result : Bounds? = None
  for p in points {
    if p.is_finite() {
      result = match result {
        None => Some(bounds(p.x(), p.x(), p.y(), p.y()))
        Some(current) =>
          Some(
            bounds(
              Double::min(current.xmin(), p.x()),
              Double::max(current.xmax(), p.x()),
              Double::min(current.ymin(), p.y()),
              Double::max(current.ymax(), p.y()),
            ),
          )
      }
    }
  }
  result
}
