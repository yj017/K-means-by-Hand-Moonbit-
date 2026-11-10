///|
/// An edge record used while constructing a triangulation topology.
priv struct TriangulationEdge {
  a : Int32
  b : Int32
  mut count : Int32
  triangle : Int32
  side : Int32
}

///|
/// A triangle index triple used by the incremental Delaunay builder.
priv struct DelaunayTriangle {
  a : Int32
  b : Int32
  c : Int32
}

///|
/// A validated triangular mesh with derived edges and face neighbors.
///
/// `triangulation` accepts explicit triangle indices or constructs a
/// deterministic Delaunay triangulation when the indices are omitted.
pub struct Triangulation {
  x : Array[Double]
  y : Array[Double]
  triangles : Array[Array[Int32]]
  mask : Array[Bool]
  edges : Array[(Int32, Int32)]
  neighbors : Array[Array[Int32]]
  delaunay : Bool
}

///|
/// Validate coordinates independently from the face index list.
fn validate_tri_vertices(
  xs : Array[Double],
  ys : Array[Double],
) -> Unit raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  if xs.length() < 3 {
    raise @core.DataError::InvalidContour(
      message="triangular mesh requires at least three vertices",
    )
  }
  for index in 0..<xs.length() {
    if xs[index].is_nan() ||
      xs[index].is_inf() ||
      ys[index].is_nan() ||
      ys[index].is_inf() {
      raise @core.DataError::InvalidContour(
        message="triangular mesh coordinates must be finite",
      )
    }
  }
}

///|
/// Validate explicit triangle indices and reject repeated vertices.
fn validate_tri_indices(
  vertex_count : Int32,
  triangles : Array[Array[Int32]],
) -> Unit raise @core.DataError {
  if triangles.length() == 0 {
    raise @core.DataError::InvalidContour(
      message="triangular mesh requires at least one triangle",
    )
  }
  for triangle in triangles {
    if triangle.length() != 3 {
      raise @core.DataError::InvalidContour(
        message="each triangular mesh face must have three indices",
      )
    }
    let first = triangle[0]
    let second = triangle[1]
    let third = triangle[2]
    if first < 0 ||
      second < 0 ||
      third < 0 ||
      first >= vertex_count ||
      second >= vertex_count ||
      third >= vertex_count ||
      first == second ||
      first == third ||
      second == third {
      raise @core.DataError::InvalidContour(
        message="triangular mesh indices must be distinct and in range",
      )
    }
  }
}

///|
fn validate_tri_mesh_mask(
  mask : Array[Bool],
  triangle_count : Int32,
) -> Unit raise @core.DataError {
  if mask.length() != 0 && mask.length() != triangle_count {
    raise @core.DataError::LengthMismatch(
      expected=triangle_count,
      actual=mask.length(),
    )
  }
}

///|
fn tri_orientation(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  cx : Double,
  cy : Double,
) -> Double {
  (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
}

///|
fn tri_edge_vertices(triangle : Array[Int32], side : Int32) -> (Int32, Int32) {
  if side == 0 {
    (triangle[1], triangle[2])
  } else if side == 1 {
    (triangle[2], triangle[0])
  } else {
    (triangle[0], triangle[1])
  }
}

///|
fn canonical_tri_edge(a : Int32, b : Int32) -> (Int32, Int32) {
  if a < b {
    (a, b)
  } else {
    (b, a)
  }
}

///|
fn topology_edge_index(
  edges : Array[TriangulationEdge],
  a : Int32,
  b : Int32,
) -> Int32? {
  for index in 0..<edges.length() {
    if edges[index].a == a && edges[index].b == b {
      return Some(index)
    }
  }
  None
}

///|
fn build_tri_topology(
  triangles : Array[Array[Int32]],
  mask : Array[Bool],
) -> (Array[(Int32, Int32)], Array[Array[Int32]]) {
  let neighbors : Array[Array[Int32]] = []
  for _ in triangles {
    neighbors.push([-1, -1, -1])
  }
  let records : Array[TriangulationEdge] = []
  for triangle_index, triangle in triangles {
    if mask.length() != 0 && mask[triangle_index] {
      continue
    }
    for side in 0..<3 {
      let (first, second) = tri_edge_vertices(triangle, side)
      let (a, b) = canonical_tri_edge(first, second)
      match topology_edge_index(records, a, b) {
        Some(record_index) => {
          let record = records[record_index]
          neighbors[triangle_index][side] = record.triangle
          neighbors[record.triangle][record.side] = triangle_index
          records[record_index].count += 1
        }
        None =>
          records.push({ a, b, count: 1, triangle: triangle_index, side, })
      }
    }
  }
  let edges : Array[(Int32, Int32)] = []
  for record in records {
    edges.push((record.a, record.b))
  }
  (edges, neighbors)
}

///|
fn contains_int(values : Array[Int32], value : Int32) -> Bool {
  for candidate in values {
    if candidate == value {
      return true
    }
  }
  false
}

///|
fn add_delaunay_boundary_edge(
  edges : Array[TriangulationEdge],
  first : Int32,
  second : Int32,
) -> Unit {
  let (a, b) = canonical_tri_edge(first, second)
  match topology_edge_index(edges, a, b) {
    Some(index) => edges[index].count += 1
    None => edges.push({ a, b, count: 1, triangle: -1, side: -1, })
  }
}

///|
fn circumcircle_contains(
  triangle : DelaunayTriangle,
  xs : Array[Double],
  ys : Array[Double],
  point_x : Double,
  point_y : Double,
  tolerance : Double,
) -> Bool {
  let ax = xs[triangle.a] - point_x
  let ay = ys[triangle.a] - point_y
  let bx = xs[triangle.b] - point_x
  let by = ys[triangle.b] - point_y
  let cx = xs[triangle.c] - point_x
  let cy = ys[triangle.c] - point_y
  let determinant = (ax * ax + ay * ay) * (bx * cy - cx * by) -
    (bx * bx + by * by) * (ax * cy - cx * ay) +
    (cx * cx + cy * cy) * (ax * by - bx * ay)
  let orientation = tri_orientation(
    xs[triangle.a],
    ys[triangle.a],
    xs[triangle.b],
    ys[triangle.b],
    xs[triangle.c],
    ys[triangle.c],
  )
  if orientation > 0.0 {
    determinant > tolerance
  } else {
    determinant < -tolerance
  }
}

///|
/// Construct a Delaunay triangulation with the incremental Bowyer-Watson
/// algorithm. The implementation is intentionally deterministic: points are
/// inserted in input order and generated faces retain that order.
fn build_delaunay(
  xs : Array[Double],
  ys : Array[Double],
) -> Array[Array[Int32]] raise @core.DataError {
  let count = xs.length()
  for first in 0..<count {
    for second in (first + 1)..<count {
      if xs[first] == xs[second] && ys[first] == ys[second] {
        raise @core.DataError::InvalidContour(
          message="triangular mesh vertices must be unique",
        )
      }
    }
  }
  let mut xmin = xs[0]
  let mut xmax = xs[0]
  let mut ymin = ys[0]
  let mut ymax = ys[0]
  for index in 1..<count {
    xmin = Double::min(xmin, xs[index])
    xmax = Double::max(xmax, xs[index])
    ymin = Double::min(ymin, ys[index])
    ymax = Double::max(ymax, ys[index])
  }
  let span = Double::max(xmax - xmin, ymax - ymin)
  let scale = if span > 0.0 { span } else { 1.0 }
  let center_x = (xmin + xmax) / 2.0
  let center_y = (ymin + ymax) / 2.0
  let work_x = xs.copy()
  let work_y = ys.copy()
  let super_a = count
  let super_b = count + 1
  let super_c = count + 2
  work_x.push(center_x - 20.0 * scale)
  work_y.push(center_y - scale)
  work_x.push(center_x)
  work_y.push(center_y + 20.0 * scale)
  work_x.push(center_x + 20.0 * scale)
  work_y.push(center_y - scale)
  let mut work : Array[DelaunayTriangle] = [
    { a: super_a, b: super_b, c: super_c, },
  ]
  let tolerance = 1.0e-12 * scale * scale * scale * scale + 1.0e-15
  for point_index in 0..<count {
    let bad : Array[Int32] = []
    let boundary : Array[TriangulationEdge] = []
    for triangle_index, triangle in work {
      if circumcircle_contains(
          triangle,
          work_x,
          work_y,
          work_x[point_index],
          work_y[point_index],
          tolerance,
        ) {
        bad.push(triangle_index)
        add_delaunay_boundary_edge(boundary, triangle.a, triangle.b)
        add_delaunay_boundary_edge(boundary, triangle.b, triangle.c)
        add_delaunay_boundary_edge(boundary, triangle.c, triangle.a)
      }
    }
    let retained : Array[DelaunayTriangle] = []
    for triangle_index, triangle in work {
      if !contains_int(bad, triangle_index) {
        retained.push(triangle)
      }
    }
    work = retained
    for edge in boundary {
      if edge.count != 1 {
        continue
      }
      let orientation = tri_orientation(
        work_x[edge.a],
        work_y[edge.a],
        work_x[edge.b],
        work_y[edge.b],
        work_x[point_index],
        work_y[point_index],
      )
      if Double::abs(orientation) <= 1.0e-14 * scale * scale {
        continue
      }
      if orientation > 0.0 {
        work.push({ a: edge.a, b: edge.b, c: point_index, })
      } else {
        work.push({ a: edge.b, b: edge.a, c: point_index, })
      }
    }
  }
  let result : Array[Array[Int32]] = []
  for triangle in work {
    if triangle.a >= count || triangle.b >= count || triangle.c >= count {
      continue
    }
    let area = tri_orientation(
      xs[triangle.a],
      ys[triangle.a],
      xs[triangle.b],
      ys[triangle.b],
      xs[triangle.c],
      ys[triangle.c],
    )
    if Double::abs(area) > 1.0e-14 * scale * scale {
      result.push([triangle.a, triangle.b, triangle.c])
    }
  }
  if result.length() == 0 {
    raise @core.DataError::InvalidContour(
      message="triangular mesh vertices are collinear",
    )
  }
  result
}

///|
/// Construct a triangular mesh. If `triangles` is empty, a Delaunay mesh is
/// generated from the input vertices. A mask marks faces that remain in the
/// mesh data but are excluded from edges and neighbors.
pub fn triangulation(
  xs : Array[Double],
  ys : Array[Double],
  triangles~ : Array[Array[Int32]] = [],
  mask~ : Array[Bool] = [],
) -> Triangulation raise @core.DataError {
  validate_tri_vertices(xs, ys)
  let generated = triangles.length() == 0
  let actual_triangles = if generated {
    build_delaunay(xs, ys)
  } else {
    validate_tri_indices(xs.length(), triangles)
    let copy : Array[Array[Int32]] = []
    for triangle in triangles {
      copy.push(triangle.copy())
    }
    copy
  }
  validate_tri_mesh_mask(mask, actual_triangles.length())
  let actual_mask = mask.copy()
  let (edges, neighbors) = build_tri_topology(actual_triangles, actual_mask)
  {
    x: xs.copy(),
    y: ys.copy(),
    triangles: actual_triangles,
    mask: actual_mask,
    edges,
    neighbors,
    delaunay: generated,
  }
}

///|
/// Return a copy of the mesh x coordinates.
pub fn Triangulation::x(self : Triangulation) -> Array[Double] {
  self.x.copy()
}

///|
/// Return a copy of the mesh y coordinates.
pub fn Triangulation::y(self : Triangulation) -> Array[Double] {
  self.y.copy()
}

///|
/// Return a deep copy of the triangle index triples.
pub fn Triangulation::triangles(self : Triangulation) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  for triangle in self.triangles {
    result.push(triangle.copy())
  }
  result
}

///|
/// Return a copy of the per-face mask. An empty mask means every face is
/// visible.
pub fn Triangulation::mask(self : Triangulation) -> Array[Bool] {
  self.mask.copy()
}

///|
/// Return each visible mesh edge once as a pair of vertex indices.
pub fn Triangulation::edges(self : Triangulation) -> Array[(Int32, Int32)] {
  self.edges.copy()
}

///|
/// Return one neighbor index for each opposite triangle side, or `-1` for a
/// boundary edge or a masked face.
pub fn Triangulation::neighbors(self : Triangulation) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  for triangle in self.neighbors {
    result.push(triangle.copy())
  }
  result
}

///|
/// Whether the mesh was generated automatically from the vertices.
pub fn Triangulation::is_delaunay(self : Triangulation) -> Bool {
  self.delaunay
}

///|
/// Return a deep copy containing only unmasked triangle faces.
pub fn Triangulation::get_masked_triangles(
  self : Triangulation,
) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  for index, triangle in self.triangles {
    if self.mask.length() == 0 || !self.mask[index] {
      result.push(triangle.copy())
    }
  }
  result
}
