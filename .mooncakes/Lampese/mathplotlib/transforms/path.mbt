///|
/// Errors raised while constructing a geometric path.
pub(all) suberror PathError {
  InvalidCodes(message~ : String)
  InvalidVertex(message~ : String)
}

///|
/// Commands attached to vertices in a path.
pub(all) enum PathCode {
  Stop
  MoveTo
  LineTo
  Curve3
  Curve4
  ClosePoly
} derive(Eq, Debug)

///|
pub extend PathCode with Eq::{equal, not_equal}

///|
pub extend PathCode with @debug.Debug::{to_repr}

///|
/// A backend-independent sequence of line and curve vertices.
pub struct Path {
  vertices : Array[@core.Point]
  codes : Array[PathCode]
}

///|
/// The normalized geometric segments represented by a path's compact code
/// stream. Matplotlib stores the control points for a quadratic or cubic
/// curve as consecutive vertices with the same code; keeping that grouping
/// here prevents callers from accidentally treating control points as line
/// endpoints.
priv enum PathSegment {
  Move(@core.Point)
  Line(@core.Point, @core.Point)
  Quadratic(@core.Point, @core.Point, @core.Point)
  Cubic(@core.Point, @core.Point, @core.Point, @core.Point)
  Close(@core.Point, @core.Point)
  Stop
}

///|
/// One half-plane used by the rectangle clipper.
priv enum ClipBoundary {
  Left(Double)
  Right(Double)
  Bottom(Double)
  Top(Double)
  OutsideLeft(Double)
  OutsideRight(Double)
  Below(Double)
  Above(Double)
}

///|
fn valid_vertex(value : @core.Point) -> Bool {
  value.is_finite()
}

///|
/// Construct a path. Empty codes default to one move followed by line segments.
pub fn path(
  vertices : Array[@core.Point],
  codes~ : Array[PathCode] = [],
) -> Path raise PathError {
  let actual_codes = if codes.length() == 0 {
    let result = Array(capacity=vertices.length())
    for index in 0..<vertices.length() {
      result.push(if index == 0 { PathCode::MoveTo } else { PathCode::LineTo })
    }
    result
  } else {
    if codes.length() != vertices.length() {
      raise PathError::InvalidCodes(
        message="path vertices and codes must have equal length",
      )
    }
    codes.copy()
  }
  for vertex in vertices {
    if !valid_vertex(vertex) {
      raise PathError::InvalidVertex(message="path vertices must be finite")
    }
  }
  for index, code in actual_codes {
    if index == 0 && code is (LineTo | Curve3 | Curve4 | ClosePoly) {
      raise PathError::InvalidCodes(message="path must start with MoveTo")
    }
    if code is Stop && index + 1 != actual_codes.length() {
      raise PathError::InvalidCodes(message="Stop must be the final path code")
    }
    match code {
      Curve3 =>
        // CURVE3 consumes exactly two vertices: one control point and one
        // endpoint. Validate only the first code in each pair.
        if index == 0 ||
          actual_codes[index - 1]
          is (MoveTo | LineTo | Curve4 | ClosePoly | Stop) {
          if index + 1 >= actual_codes.length() ||
            actual_codes[index + 1]
            is (MoveTo | LineTo | Curve4 | ClosePoly | Stop) ||
            (
              index + 2 < actual_codes.length() &&
              actual_codes[index + 2] is Curve3
            ) {
            raise PathError::InvalidCodes(
              message="Curve3 must contain exactly two consecutive vertices",
            )
          }
        }
      Curve4 =>
        // CURVE4 consumes exactly three vertices: two controls and an
        // endpoint. As above, validate only the first code in each group.
        if index == 0 ||
          actual_codes[index - 1]
          is (MoveTo | LineTo | Curve3 | ClosePoly | Stop) {
          if index + 2 >= actual_codes.length() ||
            actual_codes[index + 1]
            is (MoveTo | LineTo | Curve3 | ClosePoly | Stop) ||
            actual_codes[index + 2]
            is (MoveTo | LineTo | Curve3 | ClosePoly | Stop) ||
            (
              index + 3 < actual_codes.length() &&
              actual_codes[index + 3] is Curve4
            ) {
            raise PathError::InvalidCodes(
              message="Curve4 must contain exactly three consecutive vertices",
            )
          }
        }
      _ => ()
    }
  }
  { vertices: vertices.copy(), codes: actual_codes, }
}

///|
/// Construct a polyline path.
pub fn line_path(vertices : Array[@core.Point]) -> Path raise PathError {
  path(vertices)
}

///|
/// Construct a closed polygon path.
pub fn polygon_path(vertices : Array[@core.Point]) -> Path raise PathError {
  if vertices.length() == 0 {
    raise PathError::InvalidCodes(message="polygon path cannot be empty")
  }
  let closed_vertices = vertices.copy()
  closed_vertices.push(vertices[0])
  let codes = Array(capacity=closed_vertices.length())
  codes.push(PathCode::MoveTo)
  for _ in 1..<vertices.length() {
    codes.push(PathCode::LineTo)
  }
  codes.push(PathCode::ClosePoly)
  path(closed_vertices, codes~)
}

///|
/// Construct a rectangular closed path.
pub fn rectangle_path(box : BBox) -> Path raise PathError {
  polygon_path(box.corners())
}

///|
pub fn Path::vertices(self : Path) -> Array[@core.Point] {
  self.vertices.copy()
}

///|
pub fn Path::codes(self : Path) -> Array[PathCode] {
  self.codes.copy()
}

///|
pub fn Path::length(self : Path) -> Int32 {
  self.vertices.length()
}

///|
/// Return the axis-aligned bounds of the geometry represented by the path.
///
/// For quadratic and cubic segments this includes the interior extrema of
/// the Bezier polynomial, rather than merely the control points. This is the
/// behavior required by Matplotlib's `Path.get_extents` and is important for
/// clipping and layout calculations.
pub fn Path::extents(self : Path) -> BBox? {
  let candidates : Array[@core.Point] = []
  for segment in self.path_segments() {
    match segment {
      PathSegment::Move(point) => candidates.push(point)
      PathSegment::Line(start, end) => {
        candidates.push(start)
        candidates.push(end)
      }
      PathSegment::Quadratic(start, control, end) => {
        candidates.push(start)
        candidates.push(end)
        append_quadratic_extrema(candidates, start, control, end)
      }
      PathSegment::Cubic(start, control1, control2, end) => {
        candidates.push(start)
        candidates.push(end)
        append_cubic_extrema(candidates, start, control1, control2, end)
      }
      PathSegment::Close(start, end) => {
        candidates.push(start)
        candidates.push(end)
      }
      PathSegment::Stop => ()
    }
  }
  if candidates.length() == 0 {
    return None
  }
  let first = candidates[0]
  let mut x0 = first.x()
  let mut x1 = first.x()
  let mut y0 = first.y()
  let mut y1 = first.y()
  for point in candidates[1:] {
    x0 = Double::min(x0, point.x())
    x1 = Double::max(x1, point.x())
    y0 = Double::min(y0, point.y())
    y1 = Double::max(y1, point.y())
  }
  Some(bbox(x0, y0, x1, y1))
}

///|
/// Apply an affine transform without mutating the path.
pub fn Path::transformed(
  self : Path,
  transform : Affine2D,
) -> Path raise PathError {
  path(transform.apply_all(self.vertices), codes=self.codes)
}

///|
/// Clip closed path components to an axis-aligned rectangle.
///
/// Curves are flattened with the same deterministic sampling used by
/// `contains_point`; the result is therefore a valid line-only path. With
/// `inside=false`, the rectangle complement is emitted as four disjoint
/// half-plane pieces so points in the rectangle are removed without relying
/// on a backend-specific fill rule.
pub fn Path::clip_to_bbox(
  self : Path,
  clip_box : BBox,
  inside~ : Bool = true,
) -> Path raise PathError {
  let boundaries_inside = [
    ClipBoundary::Left(clip_box.xmin()),
    ClipBoundary::Right(clip_box.xmax()),
    ClipBoundary::Bottom(clip_box.ymin()),
    ClipBoundary::Top(clip_box.ymax()),
  ]
  let vertices : Array[@core.Point] = []
  let codes : Array[PathCode] = []
  for polygon in self.flattened_subpaths() {
    if polygon.length() >= 3 {
      if inside {
        append_clipped_polygon(
          vertices,
          codes,
          clip_polygon_many(polygon, boundaries_inside),
        )
      } else {
        append_clipped_polygon(
          vertices,
          codes,
          clip_polygon_many(polygon, [
            ClipBoundary::OutsideLeft(clip_box.xmin()),
          ]),
        )
        append_clipped_polygon(
          vertices,
          codes,
          clip_polygon_many(polygon, [
            ClipBoundary::OutsideRight(clip_box.xmax()),
          ]),
        )
        append_clipped_polygon(
          vertices,
          codes,
          clip_polygon_many(polygon, [
            ClipBoundary::Left(clip_box.xmin()),
            ClipBoundary::Right(clip_box.xmax()),
            ClipBoundary::Below(clip_box.ymin()),
          ]),
        )
        append_clipped_polygon(
          vertices,
          codes,
          clip_polygon_many(polygon, [
            ClipBoundary::Left(clip_box.xmin()),
            ClipBoundary::Right(clip_box.xmax()),
            ClipBoundary::Above(clip_box.ymax()),
          ]),
        )
      }
    }
  }
  path(vertices, codes~)
}

///|
fn Path::path_segments(self : Path) -> Array[PathSegment] {
  let segments = Array(capacity=self.vertices.length())
  let mut current : @core.Point? = None
  let mut start : @core.Point? = None
  let mut index = 0
  while index < self.codes.length() {
    let code = self.codes[index]
    let vertex = self.vertices[index]
    match code {
      PathCode::MoveTo => {
        segments.push(PathSegment::Move(vertex))
        current = Some(vertex)
        start = Some(vertex)
        index += 1
      }
      PathCode::LineTo => {
        match current {
          Some(previous) => segments.push(PathSegment::Line(previous, vertex))
          None => ()
        }
        current = Some(vertex)
        index += 1
      }
      PathCode::Curve3 =>
        if index + 1 < self.codes.length() {
          let endpoint = self.vertices[index + 1]
          match current {
            Some(previous) =>
              segments.push(PathSegment::Quadratic(previous, vertex, endpoint))
            None => ()
          }
          current = Some(endpoint)
          index += 2
        } else {
          index += 1
        }
      PathCode::Curve4 =>
        if index + 2 < self.codes.length() {
          let control2 = self.vertices[index + 1]
          let endpoint = self.vertices[index + 2]
          match current {
            Some(previous) =>
              segments.push(
                PathSegment::Cubic(previous, vertex, control2, endpoint),
              )
            None => ()
          }
          current = Some(endpoint)
          index += 3
        } else {
          index += 1
        }
      PathCode::ClosePoly => {
        match (current, start) {
          (Some(previous), Some(first)) => {
            segments.push(PathSegment::Close(previous, first))
            current = Some(first)
          }
          _ => ()
        }
        index += 1
      }
      PathCode::Stop => {
        segments.push(PathSegment::Stop)
        break
      }
    }
  }
  segments
}

///|
/// Test whether a point lies inside the path using the even-odd rule.
pub fn Path::contains_point(self : Path, point : @core.Point) -> Bool {
  let mut inside = false
  for (first, second) in self.flattened_segments() {
    let crosses = (first.y() > point.y()) != (second.y() > point.y())
    if crosses {
      let x_at_y = first.x() +
        (point.y() - first.y()) *
        (second.x() - first.x()) /
        (second.y() - first.y())
      if point.x() < x_at_y {
        inside = !inside
      }
    }
  }
  inside
}

///|
/// Flatten curved segments into short line segments for point-in-path tests.
/// The renderer uses the same deterministic approximation on every backend;
/// 32 intervals are enough to keep the winding result stable at normal plot
/// scales while avoiding a dependency on a native curve library.
fn Path::flattened_segments(self : Path) -> Array[(@core.Point, @core.Point)] {
  let result : Array[(@core.Point, @core.Point)] = []
  let mut current : @core.Point? = None
  let mut start : @core.Point? = None
  let mut closed = false
  let steps = 32
  for segment in self.path_segments() {
    match segment {
      PathSegment::Move(point) => {
        append_implicit_close(result, current, start, closed)
        current = Some(point)
        start = Some(point)
        closed = false
      }
      PathSegment::Line(segment_start, end) => {
        result.push((segment_start, end))
        current = Some(end)
      }
      PathSegment::Quadratic(segment_start, control, end) => {
        append_quadratic_lines(result, segment_start, control, end, steps)
        current = Some(end)
      }
      PathSegment::Cubic(segment_start, control1, control2, end) => {
        append_cubic_lines(
          result, segment_start, control1, control2, end, steps,
        )
        current = Some(end)
      }
      PathSegment::Close(segment_start, end) => {
        result.push((segment_start, end))
        current = Some(end)
        closed = true
      }
      PathSegment::Stop => {
        append_implicit_close(result, current, start, closed)
        current = None
        start = None
        closed = false
      }
    }
  }
  append_implicit_close(result, current, start, closed)
  result
}

///|
/// Return one sampled polygon per path subpath. Curves are represented by
/// line samples, and open components are implicitly closed for clipping just
/// as Matplotlib's path clipper expects closed polygons.
fn Path::flattened_subpaths(self : Path) -> Array[Array[@core.Point]] {
  let result : Array[Array[@core.Point]] = []
  let mut current : Array[@core.Point]? = None
  let mut closed = false
  for segment in self.path_segments() {
    match segment {
      PathSegment::Move(point) => {
        append_subpath(result, current, closed)
        current = Some([point])
        closed = false
      }
      PathSegment::Line(_, end) =>
        match current {
          Some(points) => points.push(end)
          None => ()
        }
      PathSegment::Quadratic(start, control, end) =>
        match current {
          Some(points) =>
            append_quadratic_points(points, start, control, end, 32)
          None => ()
        }
      PathSegment::Cubic(start, control1, control2, end) =>
        match current {
          Some(points) =>
            append_cubic_points(points, start, control1, control2, end, 32)
          None => ()
        }
      PathSegment::Close(_, end) =>
        match current {
          Some(points) => {
            points.push(end)
            closed = true
          }
          None => ()
        }
      PathSegment::Stop => {
        append_subpath(result, current, closed)
        current = None
        closed = false
      }
    }
  }
  append_subpath(result, current, closed)
  result
}

///|
fn append_subpath(
  result : Array[Array[@core.Point]],
  points : Array[@core.Point]?,
  closed : Bool,
) -> Unit {
  match points {
    Some(values) =>
      if values.length() >= 2 {
        let polygon = Array(capacity=values.length())
        for point in values {
          polygon.push(point)
        }
        if !closed {
          polygon.push(values[0])
        }
        if polygon.length() >= 4 {
          result.push(polygon)
        }
      }
    None => ()
  }
}

///|
fn append_quadratic_points(
  result : Array[@core.Point],
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
  steps : Int32,
) -> Unit {
  for index in 1..<=steps {
    let t = Double::from_int(index) / Double::from_int(steps)
    result.push(quadratic_value(start, control, end, t))
  }
}

///|
fn append_cubic_points(
  result : Array[@core.Point],
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
  steps : Int32,
) -> Unit {
  for index in 1..<=steps {
    let t = Double::from_int(index) / Double::from_int(steps)
    result.push(cubic_value(start, control1, control2, end, t))
  }
}

///|
fn clip_polygon_many(
  polygon : Array[@core.Point],
  boundaries : Array[ClipBoundary],
) -> Array[@core.Point] {
  let mut current = without_duplicate_endpoint(polygon)
  for boundary in boundaries {
    current = clip_polygon_boundary(current, boundary)
  }
  current
}

///|
fn without_duplicate_endpoint(
  polygon : Array[@core.Point],
) -> Array[@core.Point] {
  if polygon.length() > 1 {
    let first = polygon[0]
    let last = polygon[polygon.length() - 1]
    if first.x() == last.x() && first.y() == last.y() {
      let result = Array(capacity=polygon.length() - 1)
      for index in 0..<(polygon.length() - 1) {
        result.push(polygon[index])
      }
      return result
    }
  }
  polygon.copy()
}

///|
fn clip_polygon_boundary(
  polygon : Array[@core.Point],
  boundary : ClipBoundary,
) -> Array[@core.Point] {
  if polygon.length() == 0 {
    return []
  }
  let result : Array[@core.Point] = []
  let mut previous = polygon[polygon.length() - 1]
  let mut previous_inside = inside_boundary(previous, boundary)
  for current in polygon {
    let current_inside = inside_boundary(current, boundary)
    if current_inside {
      if !previous_inside {
        result.push(boundary_intersection(previous, current, boundary))
      }
      result.push(current)
    } else if previous_inside {
      result.push(boundary_intersection(previous, current, boundary))
    }
    previous = current
    previous_inside = current_inside
  }
  without_duplicate_endpoint(result)
}

///|
fn inside_boundary(point : @core.Point, boundary : ClipBoundary) -> Bool {
  match boundary {
    ClipBoundary::Left(value) => point.x() >= value
    ClipBoundary::Right(value) => point.x() <= value
    ClipBoundary::Bottom(value) => point.y() >= value
    ClipBoundary::Top(value) => point.y() <= value
    ClipBoundary::OutsideLeft(value) => point.x() <= value
    ClipBoundary::OutsideRight(value) => point.x() >= value
    ClipBoundary::Below(value) => point.y() <= value
    ClipBoundary::Above(value) => point.y() >= value
  }
}

///|
fn boundary_intersection(
  previous : @core.Point,
  current : @core.Point,
  boundary : ClipBoundary,
) -> @core.Point {
  match boundary {
    ClipBoundary::Left(value)
    | ClipBoundary::Right(value)
    | ClipBoundary::OutsideLeft(value)
    | ClipBoundary::OutsideRight(value) => {
      let denominator = current.x() - previous.x()
      let t = if denominator == 0.0 {
        0.0
      } else {
        (value - previous.x()) / denominator
      }
      @core.point(value, previous.y() + t * (current.y() - previous.y()))
    }
    ClipBoundary::Bottom(value)
    | ClipBoundary::Top(value)
    | ClipBoundary::Below(value)
    | ClipBoundary::Above(value) => {
      let denominator = current.y() - previous.y()
      let t = if denominator == 0.0 {
        0.0
      } else {
        (value - previous.y()) / denominator
      }
      @core.point(previous.x() + t * (current.x() - previous.x()), value)
    }
  }
}

///|
fn append_clipped_polygon(
  vertices : Array[@core.Point],
  codes : Array[PathCode],
  polygon : Array[@core.Point],
) -> Unit {
  let values = without_duplicate_endpoint(polygon)
  if values.length() < 3 {
    return
  }
  let first = values[0]
  vertices.push(first)
  codes.push(PathCode::MoveTo)
  for point in values[1:] {
    vertices.push(point)
    codes.push(PathCode::LineTo)
  }
  vertices.push(first)
  codes.push(PathCode::ClosePoly)
}

///|
fn append_implicit_close(
  result : Array[(@core.Point, @core.Point)],
  current : @core.Point?,
  start : @core.Point?,
  closed : Bool,
) -> Unit {
  if !closed {
    match (current, start) {
      (Some(last), Some(first)) =>
        if last.x() != first.x() || last.y() != first.y() {
          result.push((last, first))
        }
      _ => ()
    }
  }
}

///|
fn append_quadratic_lines(
  result : Array[(@core.Point, @core.Point)],
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
  steps : Int32,
) -> Unit {
  let mut previous = start
  for index in 1..<=steps {
    let t = Double::from_int(index) / Double::from_int(steps)
    let next = quadratic_value(start, control, end, t)
    result.push((previous, next))
    previous = next
  }
}

///|
fn append_cubic_lines(
  result : Array[(@core.Point, @core.Point)],
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
  steps : Int32,
) -> Unit {
  let mut previous = start
  for index in 1..<=steps {
    let t = Double::from_int(index) / Double::from_int(steps)
    let next = cubic_value(start, control1, control2, end, t)
    result.push((previous, next))
    previous = next
  }
}

///|
fn quadratic_value(
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
  t : Double,
) -> @core.Point {
  let u = 1.0 - t
  @core.point(
    u * u * start.x() + 2.0 * u * t * control.x() + t * t * end.x(),
    u * u * start.y() + 2.0 * u * t * control.y() + t * t * end.y(),
  )
}

///|
fn cubic_value(
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
  t : Double,
) -> @core.Point {
  let u = 1.0 - t
  let uu = u * u
  let tt = t * t
  @core.point(
    uu * u * start.x() +
    3.0 * uu * t * control1.x() +
    3.0 * u * tt * control2.x() +
    tt * t * end.x(),
    uu * u * start.y() +
    3.0 * uu * t * control1.y() +
    3.0 * u * tt * control2.y() +
    tt * t * end.y(),
  )
}

///|
fn append_quadratic_extrema(
  candidates : Array[@core.Point],
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
) -> Unit {
  append_quadratic_root(candidates, start, control, end, true)
  append_quadratic_root(candidates, start, control, end, false)
}

///|
fn append_quadratic_root(
  candidates : Array[@core.Point],
  start : @core.Point,
  control : @core.Point,
  end : @core.Point,
  x_axis : Bool,
) -> Unit {
  let p0 = if x_axis { start.x() } else { start.y() }
  let p1 = if x_axis { control.x() } else { control.y() }
  let p2 = if x_axis { end.x() } else { end.y() }
  let denominator = p0 - 2.0 * p1 + p2
  if Double::abs(denominator) > 1.0e-12 {
    let t = (p0 - p1) / denominator
    if t > 0.0 && t < 1.0 {
      candidates.push(quadratic_value(start, control, end, t))
    }
  }
}

///|
fn append_cubic_extrema(
  candidates : Array[@core.Point],
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
) -> Unit {
  append_cubic_axis_extrema(candidates, start, control1, control2, end, true)
  append_cubic_axis_extrema(candidates, start, control1, control2, end, false)
}

///|
fn append_cubic_axis_extrema(
  candidates : Array[@core.Point],
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
  x_axis : Bool,
) -> Unit {
  let p0 = if x_axis { start.x() } else { start.y() }
  let p1 = if x_axis { control1.x() } else { control1.y() }
  let p2 = if x_axis { control2.x() } else { control2.y() }
  let p3 = if x_axis { end.x() } else { end.y() }
  let a = -p0 + 3.0 * p1 - 3.0 * p2 + p3
  let b = 2.0 * (p0 - 2.0 * p1 + p2)
  let c = p1 - p0
  let epsilon = 1.0e-12
  if Double::abs(a) <= epsilon {
    if Double::abs(b) > epsilon {
      append_cubic_root(candidates, start, control1, control2, end, -c / b)
    }
  } else {
    let discriminant = b * b - 4.0 * a * c
    if discriminant >= 0.0 {
      let root = discriminant.sqrt()
      append_cubic_root(
        candidates,
        start,
        control1,
        control2,
        end,
        (-b - root) / (2.0 * a),
      )
      append_cubic_root(
        candidates,
        start,
        control1,
        control2,
        end,
        (-b + root) / (2.0 * a),
      )
    }
  }
}

///|
fn append_cubic_root(
  candidates : Array[@core.Point],
  start : @core.Point,
  control1 : @core.Point,
  control2 : @core.Point,
  end : @core.Point,
  t : Double,
) -> Unit {
  if t > 0.0 && t < 1.0 {
    candidates.push(cubic_value(start, control1, control2, end, t))
  }
}
