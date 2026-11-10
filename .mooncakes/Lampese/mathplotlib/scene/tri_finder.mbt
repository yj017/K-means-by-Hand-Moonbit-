///|
/// A point-to-triangle lookup built from a validated triangulation.
///
/// `find` returns the index of the first visible triangle containing the
/// query point. Points outside the mesh, points in masked faces, and
/// non-finite query coordinates return `-1`, matching Matplotlib's
/// `TriFinder` sentinel convention.
pub struct TriFinder {
  x : Array[Double]
  y : Array[Double]
  triangles : Array[Array[Int32]]
  mask : Array[Bool]
}

///|
fn copy_tri_finder_triangles(
  triangles : Array[Array[Int32]],
) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  for triangle in triangles {
    result.push(triangle.copy())
  }
  result
}

///|
/// Construct a finder from a triangulation, copying the mesh data so later
/// changes to caller-owned arrays cannot affect lookup results.
pub fn trifinder(mesh : Triangulation) -> TriFinder {
  {
    x: mesh.x.copy(),
    y: mesh.y.copy(),
    triangles: copy_tri_finder_triangles(mesh.triangles),
    mask: mesh.mask.copy(),
  }
}

///|
/// Return a point finder for this triangulation.
pub fn Triangulation::get_trifinder(self : Triangulation) -> TriFinder {
  trifinder(self)
}

///|
fn finder_orientation(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  px : Double,
  py : Double,
) -> Double {
  (bx - ax) * (py - ay) - (by - ay) * (px - ax)
}

///|
fn finder_contains(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  cx : Double,
  cy : Double,
  px : Double,
  py : Double,
) -> Bool {
  let area = finder_orientation(ax, ay, bx, by, cx, cy)
  if area == 0.0 {
    return false
  }
  let first = finder_orientation(ax, ay, bx, by, px, py)
  let second = finder_orientation(bx, by, cx, cy, px, py)
  let third = finder_orientation(cx, cy, ax, ay, px, py)
  let epsilon = 1.0e-12 * Double::max(1.0, Double::abs(area))
  if area > 0.0 {
    first >= -epsilon && second >= -epsilon && third >= -epsilon
  } else {
    first <= epsilon && second <= epsilon && third <= epsilon
  }
}

///|
/// Find the index of the first visible triangle containing `(x, y)`.
///
/// The return value is `-1` when the point is outside the triangulation, lies
/// in a masked face, or has a non-finite coordinate. Points on a shared edge
/// use the first visible face in mesh order, making the result deterministic.
pub fn TriFinder::find(self : TriFinder, x : Double, y : Double) -> Int32 {
  if x.is_nan() || x.is_inf() || y.is_nan() || y.is_inf() {
    return -1
  }
  for index, triangle in self.triangles {
    if self.mask.length() != 0 && self.mask[index] {
      continue
    }
    if finder_contains(
        self.x[triangle[0]],
        self.y[triangle[0]],
        self.x[triangle[1]],
        self.y[triangle[1]],
        self.x[triangle[2]],
        self.y[triangle[2]],
        x,
        y,
      ) {
      return index
    }
  }
  -1
}

///|
/// Find triangles for parallel arrays of query coordinates.
pub fn TriFinder::find_many(
  self : TriFinder,
  xs : Array[Double],
  ys : Array[Double],
) -> Array[Int32] raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  let result = Array(capacity=xs.length())
  for index in 0..<xs.length() {
    result.push(self.find(xs[index], ys[index]))
  }
  result
}

///|
/// Return the index of the triangle containing a point, or `-1` outside the
/// mesh. This is a convenience wrapper around `get_trifinder().find`.
pub fn Triangulation::find_triangle(
  self : Triangulation,
  x : Double,
  y : Double,
) -> Int32 {
  self.get_trifinder().find(x, y)
}
