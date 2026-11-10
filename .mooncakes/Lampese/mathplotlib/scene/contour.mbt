///|
/// The result of a contour or filled-contour calculation.
pub struct ContourSet {
  levels : Array[Double]
  filled : Bool
  segments : Array[Array[@core.Point]]
  segment_levels : Array[Double]
  extend_mode : String
  corner_mask : Bool
}

///|
/// Return the contour levels in ascending order.
pub fn ContourSet::levels(self : ContourSet) -> Array[Double] {
  self.levels.copy()
}

///|
/// Return whether this set contains filled bands.
pub fn ContourSet::filled(self : ContourSet) -> Bool {
  self.filled
}

///|
/// Return the filled-contour extension mode.
/// This corresponds to Matplotlib's extend property.
pub fn ContourSet::extend_mode(self : ContourSet) -> String {
  self.extend_mode
}

///|
/// Return whether masked quadrilateral corners are clipped independently.
pub fn ContourSet::corner_mask(self : ContourSet) -> Bool {
  self.corner_mask
}

///|
/// Return the rendered contour paths, grouped in deterministic artist order.
pub fn ContourSet::segments(self : ContourSet) -> Array[Array[@core.Point]] {
  let result : Array[Array[@core.Point]] = []
  for segment in self.segments {
    result.push(segment.copy())
  }
  result
}

///|
/// Return the level associated with each path returned by `segments`.
pub fn ContourSet::segment_levels(self : ContourSet) -> Array[Double] {
  self.segment_levels.copy()
}

///|
/// Return contour paths grouped by their level, like Matplotlib `allsegs`.
pub fn ContourSet::allsegs(
  self : ContourSet,
) -> Array[Array[Array[@core.Point]]] {
  let result : Array[Array[Array[@core.Point]]] = []
  for level in contour_set_group_levels(self) {
    let paths : Array[Array[@core.Point]] = []
    for index in 0..<self.segments.length() {
      if self.segment_levels[index] == level {
        paths.push(self.segments[index].copy())
      }
    }
    result.push(paths)
  }
  result
}

///|
/// Return the representative layer value for each filled band.
pub fn ContourSet::layers(self : ContourSet) -> Array[Double] {
  if !self.filled || self.levels.length() < 2 {
    return self.levels.copy()
  }
  if self.segment_levels.length() > 0 {
    return contour_unique_levels(self.segment_levels)
  }
  let result : Array[Double] = []
  for index in 0..<(self.levels.length() - 1) {
    result.push((self.levels[index] + self.levels[index + 1]) / 2.0)
  }
  result
}

///|
fn contour_unique_levels(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  for value in values {
    let mut present = false
    for existing in result {
      if existing == value {
        present = true
        break
      }
    }
    if !present {
      result.push(value)
    }
  }
  result
}

///|
fn contour_set_group_levels(set : ContourSet) -> Array[Double] {
  if set.filled && set.segment_levels.length() > 0 {
    contour_unique_levels(set.segment_levels)
  } else {
    set.levels.copy()
  }
}

///|
priv struct ContourVertex {
  point : @core.Point
  value : Double
}

///|
fn contour_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn validate_contour_extend(value : String) -> Unit raise @core.DataError {
  if value != "neither" && value != "min" && value != "max" && value != "both" {
    raise @core.DataError::InvalidContour(
      message="contour extend must be 'neither', 'min', 'max', or 'both'",
    )
  }
}

///|
fn contour_extend_min(value : String) -> Bool {
  value == "min" || value == "both"
}

///|
fn contour_extend_max(value : String) -> Bool {
  value == "max" || value == "both"
}

///|
fn contour_quad_allowed(
  first : ContourVertex,
  second : ContourVertex,
  third : ContourVertex,
  fourth : ContourVertex,
  corner_mask : Bool,
) -> Bool {
  corner_mask ||
  (
    contour_finite(first.value) &&
    contour_finite(second.value) &&
    contour_finite(third.value) &&
    contour_finite(fourth.value)
  )
}

///|
fn contour_axis(
  values : Array[Double],
  count : Int32,
  axis : String,
) -> Array[Double] raise @core.DataError {
  if values.length() == 0 {
    let result = Array(capacity=count)
    for index in 0..<count {
      result.push(Double::from_int(index))
    }
    result
  } else {
    if values.length() != count {
      raise @core.DataError::InvalidContour(
        message="contour coordinate length must match the grid",
      )
    }
    for value in values {
      if !contour_finite(value) {
        raise @core.DataError::NonFiniteLimit(axis~)
      }
    }
    if count > 1 {
      let increasing = values[1] > values[0]
      for index in 1..<count {
        let previous = values[index - 1]
        let current = values[index]
        if increasing {
          if current <= previous {
            raise @core.DataError::InvalidContour(
              message="contour coordinates must be strictly monotonic",
            )
          }
        } else if current >= previous {
          raise @core.DataError::InvalidContour(
            message="contour coordinates must be strictly monotonic",
          )
        }
      }
    }
    values.copy()
  }
}

///|
fn contour_grid(
  data : Array[Array[Double]],
  x : Array[Double],
  y : Array[Double],
) -> (Array[Array[Double]], Array[Double], Array[Double]) raise @core.DataError {
  if (x.length() == 0) != (y.length() == 0) {
    raise @core.DataError::InvalidContour(
      message="contour x and y coordinates must be supplied together",
    )
  }
  if data.length() < 2 || data[0].length() < 2 {
    raise @core.DataError::InvalidContour(
      message="contour data must have at least two rows and two columns",
    )
  }
  let columns = data[0].length()
  for row in data {
    if row.length() != columns {
      raise @core.DataError::InvalidContour(
        message="contour data rows must have equal length",
      )
    }
  }
  let xs = contour_axis(x, columns, "x")
  let ys = contour_axis(y, data.length(), "y")
  (data, xs, ys)
}

///|
fn contour_data_limits(
  data : Array[Array[Double]],
) -> (Double, Double) raise @core.DataError {
  let mut lower = 0.0
  let mut upper = 0.0
  let mut found = false
  for row in data {
    for value in row {
      if contour_finite(value) {
        if !found {
          lower = value
          upper = value
          found = true
        } else {
          lower = Double::min(lower, value)
          upper = Double::max(upper, value)
        }
      }
    }
  }
  if !found {
    raise @core.DataError::InvalidContour(
      message="contour data must contain at least one finite value",
    )
  }
  (lower, upper)
}

///|
fn contour_levels(
  data : Array[Array[Double]],
  requested : Array[Double],
  nlevels : Int32,
  filled : Bool,
  locator : @ticker.Locator?,
) -> Array[Double] raise @core.DataError {
  if nlevels < 1 {
    raise @core.DataError::InvalidContour(
      message="contour nlevels must be positive",
    )
  }
  if requested.length() > 0 {
    if filled && requested.length() < 2 {
      raise @core.DataError::InvalidContour(
        message="filled contours require at least two levels",
      )
    }
    for index, level in requested {
      if !contour_finite(level) {
        raise @core.DataError::InvalidContour(
          message="contour levels must be finite",
        )
      }
      if index > 0 && level <= requested[index - 1] {
        raise @core.DataError::InvalidContour(
          message="contour levels must be strictly increasing",
        )
      }
    }
    requested.copy()
  } else {
    let (lower, upper) = contour_data_limits(data)
    match locator {
      Some(locator) => {
        let resolved = locator.checked_tick_values(lower, upper)
        if resolved.length() == 0 {
          raise @core.DataError::InvalidContour(
            message="contour locator produced no finite levels",
          )
        }
        if filled && resolved.length() < 2 {
          raise @core.DataError::InvalidContour(
            message="filled contours require at least two locator levels",
          )
        }
        for index, level in resolved {
          if !contour_finite(level) ||
            (index > 0 && level <= resolved[index - 1]) {
            raise @core.DataError::InvalidContour(
              message="contour locator levels must be finite and increasing",
            )
          }
        }
        resolved
      }
      None =>
        if lower == upper {
          if filled {
            [lower - 0.5, upper + 0.5]
          } else {
            [lower]
          }
        } else {
          let count = if filled { nlevels + 1 } else { nlevels }
          let actual_count = Int32::max(count, 2)
          let result = Array(capacity=actual_count)
          for index in 0..<actual_count {
            let fraction = Double::from_int(index) /
              Double::from_int(actual_count - 1)
            result.push(lower + (upper - lower) * fraction)
          }
          result
        }
    }
  }
}

///|
fn contour_intersection(
  first : ContourVertex,
  second : ContourVertex,
  level : Double,
) -> @core.Point? {
  if !contour_finite(first.value) || !contour_finite(second.value) {
    None
  } else if (first.value < level && second.value >= level) ||
    (second.value < level && first.value >= level) {
    let denominator = second.value - first.value
    if denominator == 0.0 {
      Some(first.point)
    } else {
      let fraction = (level - first.value) / denominator
      Some(
        @core.point(
          first.point.x() + (second.point.x() - first.point.x()) * fraction,
          first.point.y() + (second.point.y() - first.point.y()) * fraction,
        ),
      )
    }
  } else {
    None
  }
}

///|
fn contour_push_unique(
  points : Array[@core.Point],
  point : @core.Point,
) -> Unit {
  for existing in points {
    if existing.x() == point.x() && existing.y() == point.y() {
      return
    }
  }
  points.push(point)
}

///|
fn contour_triangle_segments(
  first : ContourVertex,
  second : ContourVertex,
  third : ContourVertex,
  level : Double,
) -> Array[Array[@core.Point]] {
  let intersections = Array(capacity=3)
  match contour_intersection(first, second, level) {
    Some(point) => contour_push_unique(intersections, point)
    None => ()
  }
  match contour_intersection(second, third, level) {
    Some(point) => contour_push_unique(intersections, point)
    None => ()
  }
  match contour_intersection(third, first, level) {
    Some(point) => contour_push_unique(intersections, point)
    None => ()
  }
  let result : Array[Array[@core.Point]] = []
  if intersections.length() >= 2 {
    result.push([intersections[0], intersections[1]])
  }
  result
}

///|
/// A graph node used to join contour crossings from adjacent cells or faces.
///
/// Triangle interpolation can produce the same crossing twice with tiny
/// floating-point differences when two faces share an edge.  Building a
/// small tolerance graph lets the renderer emit one continuous polyline.
priv struct ContourGraphNode {
  point : @core.Point
  edges : Array[Int32]
}

///|
priv struct ContourGraphEdge {
  first : Int32
  second : Int32
}

///|
fn contour_points_close(first : @core.Point, second : @core.Point) -> Bool {
  let scale = Double::max(
    1.0,
    Double::max(
      Double::max(
        Double::max(Double::abs(first.x()), Double::abs(first.y())),
        Double::max(Double::abs(second.x()), Double::abs(second.y())),
      ),
      Double::max(
        Double::abs(first.x() - second.x()),
        Double::abs(first.y() - second.y()),
      ),
    ),
  )
  let tolerance = 1.0e-12 * scale
  Double::abs(first.x() - second.x()) <= tolerance &&
  Double::abs(first.y() - second.y()) <= tolerance
}

///|
fn contour_graph_node_index(
  nodes : Array[ContourGraphNode],
  point : @core.Point,
) -> Int32? {
  for index, node in nodes {
    if contour_points_close(node.point, point) {
      return Some(index)
    }
  }
  None
}

///|
fn contour_stitch_segments(
  segments : Array[Array[@core.Point]],
) -> Array[Array[@core.Point]] {
  let nodes : Array[ContourGraphNode] = []
  let edges : Array[ContourGraphEdge] = []
  for segment in segments {
    if segment.length() < 2 {
      continue
    }
    let first = segment[0]
    let second = segment[segment.length() - 1]
    if contour_points_close(first, second) {
      continue
    }
    let first_index = match contour_graph_node_index(nodes, first) {
      Some(index) => index
      None => {
        nodes.push({ point: first, edges: [], })
        nodes.length() - 1
      }
    }
    let second_index = match contour_graph_node_index(nodes, second) {
      Some(index) => index
      None => {
        nodes.push({ point: second, edges: [], })
        nodes.length() - 1
      }
    }
    let edge_index = edges.length()
    edges.push({ first: first_index, second: second_index, })
    nodes[first_index].edges.push(edge_index)
    nodes[second_index].edges.push(edge_index)
  }
  let visited : Array[Bool] = []
  for _ in edges {
    visited.push(false)
  }
  let result : Array[Array[@core.Point]] = []
  for edge_index in 0..<edges.length() {
    if visited[edge_index] {
      continue
    }
    let edge = edges[edge_index]
    let start = if nodes[edge.first].edges.length() != 2 {
      edge.first
    } else if nodes[edge.second].edges.length() != 2 {
      edge.second
    } else {
      edge.first
    }
    let path : Array[@core.Point] = []
    path.push(nodes[start].point)
    let mut current = start
    for _ in 0..<edges.length() {
      let next_edge : Int32? = {
        let mut found : Int32? = None
        for candidate in nodes[current].edges {
          if !visited[candidate] {
            found = Some(candidate)
            break
          }
        }
        found
      }
      match next_edge {
        None => break
        Some(candidate) => {
          visited[candidate] = true
          let candidate_edge = edges[candidate]
          let next = if candidate_edge.first == current {
            candidate_edge.second
          } else {
            candidate_edge.first
          }
          path.push(nodes[next].point)
          current = next
          if current == start {
            break
          }
        }
      }
    }
    if path.length() >= 2 {
      // Keep the repeated endpoint for closed contours so SVG can represent
      // the loop without a separate polygon artist.
      result.push(path)
    }
  }
  result
}

///|
priv struct ContourBoundaryEdge {
  first : Int32
  second : Int32
}

///|
fn contour_boundary_edge_matches(
  edge : ContourBoundaryEdge,
  first : Int32,
  second : Int32,
) -> Bool {
  (edge.first == first && edge.second == second) ||
  (edge.first == second && edge.second == first)
}

///|
/// Merge clipped triangle polygons into boundary loops for one filled band.
///
/// Each internal mesh edge occurs twice.  Removing those pairs leaves only
/// the outer boundary (and any holes), which can then be emitted as SVG
/// polygons without drawing one overlapping polygon per face.
fn contour_union_polygons(
  polygons : Array[Array[@core.Point]],
) -> Array[Array[@core.Point]] {
  let nodes : Array[ContourGraphNode] = []
  let mut boundary : Array[ContourBoundaryEdge] = []
  for polygon in polygons {
    if polygon.length() < 3 {
      continue
    }
    let polygon_nodes : Array[Int32] = []
    for point in polygon {
      let node_index = match contour_graph_node_index(nodes, point) {
        Some(index) => index
        None => {
          nodes.push({ point, edges: [], })
          nodes.length() - 1
        }
      }
      polygon_nodes.push(node_index)
    }
    for index in 0..<polygon_nodes.length() {
      let first = polygon_nodes[index]
      let second = polygon_nodes[(index + 1) % polygon_nodes.length()]
      if first == second {
        continue
      }
      let mut matched = false
      let remaining : Array[ContourBoundaryEdge] = []
      for edge in boundary {
        if !matched && contour_boundary_edge_matches(edge, first, second) {
          matched = true
        } else {
          remaining.push(edge)
        }
      }
      if matched {
        boundary = remaining
      } else {
        boundary.push({ first, second, })
      }
    }
  }
  let segments : Array[Array[@core.Point]] = []
  for edge in boundary {
    segments.push([nodes[edge.first].point, nodes[edge.second].point])
  }
  contour_stitch_segments(segments)
}

///|
fn contour_clip_polygon(
  polygon : Array[ContourVertex],
  level : Double,
  keep_above : Bool,
) -> Array[ContourVertex] {
  let result : Array[ContourVertex] = []
  if polygon.length() == 0 {
    return result
  }
  let inside = (value : Double) => {
    if keep_above {
      value >= level
    } else {
      value <= level
    }
  }
  for index in 0..<polygon.length() {
    let first = polygon[index]
    let second = polygon[(index + 1) % polygon.length()]
    let first_inside = inside(first.value)
    let second_inside = inside(second.value)
    if first_inside && second_inside {
      result.push(second)
    } else if first_inside && !second_inside {
      match contour_intersection(first, second, level) {
        Some(point) => result.push({ point, value: level, })
        None => ()
      }
    } else if !first_inside && second_inside {
      match contour_intersection(first, second, level) {
        Some(point) => result.push({ point, value: level, })
        None => ()
      }
      result.push(second)
    }
  }
  result
}

///|
fn contour_clipped_triangle(
  first : ContourVertex,
  second : ContourVertex,
  third : ContourVertex,
  lower : Double,
  upper : Double,
) -> Array[@core.Point] {
  let initial = [first, second, third]
  let above = contour_clip_polygon(initial, lower, true)
  let clipped = contour_clip_polygon(above, upper, false)
  let result = Array(capacity=clipped.length())
  for vertex in clipped {
    contour_push_unique(result, vertex.point)
  }
  result
}

///|
fn contour_palette_color(
  index : Int32,
  count : Int32,
  colors : Array[String],
  cmap : String,
) -> String raise @core.DataError {
  if colors.length() > 0 {
    colors[index % colors.length()]
  } else {
    let color_map = match @colors.find_colormap(cmap) {
      Some(value) => value
      None =>
        raise @core.DataError::InvalidContour(
          message="unknown contour colormap: \{cmap}",
        )
    }
    let fraction = (Double::from_int(index) + 0.5) /
      Double::from_int(Int32::max(count, 1))
    color_map.sample_extended(fraction).to_css()
  }
}

///|
fn contour_render_filled_band(
  axes : Axes,
  grid : Array[Array[Double]],
  xs : Array[Double],
  ys : Array[Double],
  lower : Double,
  upper : Double,
  style : @core.Style,
  slot : Int32,
  series : String,
  corner_mask : Bool,
) -> Array[Array[@core.Point]] {
  if lower >= upper {
    return []
  }
  let rows = grid.length()
  let columns = grid[0].length()
  let polygons : Array[Array[@core.Point]] = []
  for row in 0..<(rows - 1) {
    for column in 0..<(columns - 1) {
      let (first, second, third, fourth) = contour_triangles(
        grid, xs, ys, row, column,
      )
      if contour_quad_allowed(first, second, third, fourth, corner_mask) {
        let first_polygon = contour_clipped_triangle(
          first, second, third, lower, upper,
        )
        if first_polygon.length() >= 3 {
          polygons.push(first_polygon)
        }
        let second_polygon = contour_clipped_triangle(
          first, third, fourth, lower, upper,
        )
        if second_polygon.length() >= 3 {
          polygons.push(second_polygon)
        }
      }
    }
  }
  let merged = contour_union_polygons(polygons)
  axes.push_contourf_band(merged, style, slot, lower, upper, series)
  merged
}

///|
fn contour_triangles(
  data : Array[Array[Double]],
  xs : Array[Double],
  ys : Array[Double],
  row : Int32,
  column : Int32,
) -> (ContourVertex, ContourVertex, ContourVertex, ContourVertex) {
  let first = {
    point: @core.point(xs[column], ys[row]),
    value: data[row][column],
  }
  let second = {
    point: @core.point(xs[column + 1], ys[row]),
    value: data[row][column + 1],
  }
  let third = {
    point: @core.point(xs[column + 1], ys[row + 1]),
    value: data[row + 1][column + 1],
  }
  let fourth = {
    point: @core.point(xs[column], ys[row + 1]),
    value: data[row + 1][column],
  }
  (first, second, third, fourth)
}

///|
fn validate_contour_style(width : Double) -> Unit raise @core.DataError {
  if width.is_nan() || width.is_inf() || width < 0.0 {
    raise @core.DataError::InvalidContour(
      message="contour linewidth must be finite and non-negative",
    )
  }
}

///|
fn validate_contour_linewidths(
  linewidths : Array[Double],
) -> Unit raise @core.DataError {
  for width in linewidths {
    validate_contour_style(width)
  }
}

///|
fn contour_line_color(
  fallback : String,
  colors : Array[String],
  index : Int32,
) -> String {
  if colors.length() == 0 {
    fallback
  } else {
    colors[index % colors.length()]
  }
}

///|
fn contour_linewidth(
  fallback : Double,
  linewidths : Array[Double],
  index : Int32,
) -> Double {
  if linewidths.length() == 0 {
    fallback
  } else {
    linewidths[index % linewidths.length()]
  }
}

///|
/// Draw contour lines over a regular rectangular grid.
pub fn Figure::contour(
  self : Figure,
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  corner_mask~ : Bool = true,
  locator? : @ticker.Locator,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> ContourSet raise @core.DataError {
  self
  .axes()
  .contour(
    data,
    x~,
    y~,
    levels~,
    nlevels~,
    color~,
    linewidth~,
    label~,
    corner_mask~,
    locator~,
    colors~,
    linewidths~,
  )
}

///|
/// Draw contour lines over a regular rectangular grid on this axes.
pub fn Axes::contour(
  self : Axes,
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  corner_mask~ : Bool = true,
  locator~ : @ticker.Locator? = None,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> ContourSet raise @core.DataError {
  let (grid, xs, ys) = contour_grid(data, x, y)
  let resolved_levels = contour_levels(grid, levels, nlevels, false, locator)
  validate_contour_style(linewidth)
  validate_contour_linewidths(linewidths)
  let resolved_color = if colors.length() > 0 {
    if color == "" {
      colors[0]
    } else {
      color
    }
  } else {
    self.resolve_color(color)
  }
  let start = self.state.val.artists.length()
  let segments : Array[Array[@core.Point]] = []
  let segment_levels : Array[Double] = []
  let rows = grid.length()
  let columns = grid[0].length()
  for level_index, level in resolved_levels {
    let style = @core.style(
      contour_line_color(resolved_color, colors, level_index),
      width=contour_linewidth(linewidth, linewidths, level_index),
    )
    let raw_segments : Array[Array[@core.Point]] = []
    for row in 0..<(rows - 1) {
      for column in 0..<(columns - 1) {
        let (first, second, third, fourth) = contour_triangles(
          grid, xs, ys, row, column,
        )
        if contour_quad_allowed(first, second, third, fourth, corner_mask) {
          let first_segments = contour_triangle_segments(
            first, second, third, level,
          )
          for segment in first_segments {
            raw_segments.push(segment)
          }
          let second_segments = contour_triangle_segments(
            first, third, fourth, level,
          )
          for segment in second_segments {
            raw_segments.push(segment)
          }
        }
      }
    }
    for path in contour_stitch_segments(raw_segments) {
      self.push_contour_path(path, style, segments.length(), level, label)
      segments.push(path.copy())
      segment_levels.push(level)
    }
  }
  self.add_auto_legend(
    label,
    contour_line_color(resolved_color, colors, 0),
    LegendKind::Line,
    record_series=self.state.val.artists.length() > start,
  )
  self.add_container(ContainerKind::Contour, start, label)
  {
    levels: resolved_levels,
    filled: false,
    segments,
    segment_levels,
    extend_mode: "neither",
    corner_mask,
  }
}

///|
/// Draw filled contour bands over a regular rectangular grid.
pub fn Figure::contourf(
  self : Figure,
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  corner_mask~ : Bool = true,
  locator? : @ticker.Locator,
) -> ContourSet raise @core.DataError {
  self
  .axes()
  .contourf(
    data,
    x~,
    y~,
    levels~,
    nlevels~,
    colors~,
    cmap~,
    label~,
    extend_mode~,
    corner_mask~,
    locator~,
  )
}

///|
/// Draw filled contour bands over a regular rectangular grid on this axes.
pub fn Axes::contourf(
  self : Axes,
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  corner_mask~ : Bool = true,
  locator~ : @ticker.Locator? = None,
) -> ContourSet raise @core.DataError {
  let (grid, xs, ys) = contour_grid(data, x, y)
  validate_contour_extend(extend_mode)
  let resolved_levels = contour_levels(grid, levels, nlevels, true, locator)
  let bands = resolved_levels.length() - 1
  let (data_lower, data_upper) = contour_data_limits(grid)
  let extension_count = (if contour_extend_min(extend_mode) { 1 } else { 0 }) +
    (if contour_extend_max(extend_mode) { 1 } else { 0 })
  let rendered_bands = bands + extension_count
  let start = self.state.val.artists.length()
  let mut color_index = 0
  let filled_segments : Array[Array[@core.Point]] = []
  let filled_segment_levels : Array[Double] = []
  if contour_extend_min(extend_mode) {
    let fill_color = contour_palette_color(
      color_index, rendered_bands, colors, cmap,
    )
    let paths = contour_render_filled_band(
      self,
      grid,
      xs,
      ys,
      data_lower,
      resolved_levels[0],
      @core.style(fill_color, width=0.0, fill=fill_color),
      color_index,
      label,
      corner_mask,
    )
    for path in paths {
      filled_segments.push(path.copy())
      filled_segment_levels.push((data_lower + resolved_levels[0]) / 2.0)
    }
    color_index += 1
  }
  for band in 0..<bands {
    let fill_color = contour_palette_color(
      color_index, rendered_bands, colors, cmap,
    )
    let lower = resolved_levels[band]
    let upper = resolved_levels[band + 1]
    let paths = contour_render_filled_band(
      self,
      grid,
      xs,
      ys,
      lower,
      upper,
      @core.style(fill_color, width=0.0, fill=fill_color),
      color_index,
      label,
      corner_mask,
    )
    for path in paths {
      filled_segments.push(path.copy())
      filled_segment_levels.push((lower + upper) / 2.0)
    }
    color_index += 1
  }
  if contour_extend_max(extend_mode) {
    let fill_color = contour_palette_color(
      color_index, rendered_bands, colors, cmap,
    )
    let paths = contour_render_filled_band(
      self,
      grid,
      xs,
      ys,
      resolved_levels[resolved_levels.length() - 1],
      data_upper,
      @core.style(fill_color, width=0.0, fill=fill_color),
      color_index,
      label,
      corner_mask,
    )
    for path in paths {
      filled_segments.push(path.copy())
      filled_segment_levels.push(
        (resolved_levels[resolved_levels.length() - 1] + data_upper) / 2.0,
      )
    }
  }
  let legend_color = contour_palette_color(0, rendered_bands, colors, cmap)
  self.add_auto_legend(
    label,
    legend_color,
    LegendKind::Patch,
    record_series=self.state.val.artists.length() > start,
  )
  self.add_container(ContainerKind::Contour, start, label)
  {
    levels: resolved_levels,
    filled: true,
    segments: filled_segments,
    segment_levels: filled_segment_levels,
    extend_mode,
    corner_mask,
  }
}

///|
fn contour_interpolate(
  first : @core.Point,
  second : @core.Point,
  fraction : Double,
) -> @core.Point {
  @core.point(
    first.x() + (second.x() - first.x()) * fraction,
    first.y() + (second.y() - first.y()) * fraction,
  )
}

///|
fn contour_same_segment(
  first : Array[@core.Point],
  second : Array[@core.Point],
) -> Bool {
  if first.length() != second.length() {
    return false
  }
  for index in 0..<first.length() {
    if first[index].x() != second[index].x() ||
      first[index].y() != second[index].y() {
      return false
    }
  }
  true
}

///|
/// Split a representative contour segment around its label position.
fn contour_inline_parts(
  points : Array[@core.Point],
) -> Array[Array[@core.Point]] {
  if points.length() < 2 {
    return [points.copy()]
  }
  let segment_index = Int32::max(points.length() / 2 - 1, 0)
  let first = points[segment_index]
  let second = points[segment_index + 1]
  let dx = second.x() - first.x()
  let dy = second.y() - first.y()
  let length = (dx * dx + dy * dy).sqrt()
  if length == 0.0 {
    return [points.copy()]
  }
  let left : Array[@core.Point] = []
  for index in 0..<=segment_index {
    left.push(points[index])
  }
  left.push(contour_interpolate(first, second, 0.375))
  let right : Array[@core.Point] = []
  right.push(contour_interpolate(first, second, 0.625))
  for index in (segment_index + 1)..<points.length() {
    right.push(points[index])
  }
  [left, right]
}

///|
/// Remove a small gap from a matching contour line for an inline label.
fn Axes::erase_inline_contour_segment(
  self : Axes,
  target : Array[@core.Point],
) -> Unit {
  let updated : Array[Artist] = []
  let barb_intents = Map([])
  let contour_intents = Map([])
  let contourf_intents = Map([])
  let tricolor_intents = Map([])
  let streamplot_intents = Map([])
  for index, artist in self.state.val.artists {
    let barb_intent = self.state.val.barb_intents.get(index)
    let contour_intent = self.state.val.contour_intents.get(index)
    let contourf_intent = self.state.val.contourf_intents.get(index)
    let tricolor_intent = self.state.val.tricolor_intents.get(index)
    let streamplot_intent = self.state.val.streamplot_intents.get(index)
    match artist {
      Artist::Line(points, style) if contour_same_segment(points, target) =>
        for part in contour_inline_parts(points) {
          if barb_intent is Some(intent) {
            barb_intents[updated.length()] = intent
          }
          if contourf_intent is Some(intent) {
            contourf_intents[updated.length()] = intent
          }
          if tricolor_intent is Some(intent) {
            tricolor_intents[updated.length()] = intent
          }
          if streamplot_intent is Some(intent) {
            streamplot_intents[updated.length()] = intent
          }
          let fragment = Artist::Line(part, style)
          if contour_intent is Some(intent) {
            contour_intents[updated.length()] = intent.split(artist, fragment)
          }
          updated.push(fragment)
        }
      _ => {
        if barb_intent is Some(intent) {
          barb_intents[updated.length()] = intent
        }
        if contour_intent is Some(intent) {
          contour_intents[updated.length()] = intent
        }
        if contourf_intent is Some(intent) {
          contourf_intents[updated.length()] = intent
        }
        if tricolor_intent is Some(intent) {
          tricolor_intents[updated.length()] = intent
        }
        if streamplot_intent is Some(intent) {
          streamplot_intents[updated.length()] = intent
        }
        updated.push(artist)
      }
    }
  }
  self.state.val.artists.clear()
  for artist in updated {
    self.state.val.artists.push(artist)
  }
  self.state.val.barb_intents.clear()
  for index, intent in barb_intents {
    self.state.val.barb_intents[index] = intent
  }
  self.state.val.contour_intents.clear()
  for index, intent in contour_intents {
    self.state.val.contour_intents[index] = intent
  }
  self.state.val.contourf_intents.clear()
  for index, intent in contourf_intents {
    self.state.val.contourf_intents[index] = intent
  }
  self.state.val.tricolor_intents.clear()
  for index, intent in tricolor_intents {
    self.state.val.tricolor_intents[index] = intent
  }
  self.state.val.streamplot_intents.clear()
  for index, intent in streamplot_intents {
    self.state.val.streamplot_intents[index] = intent
  }
  self.prune_line_originals()
}

///|
/// Add one text label at a representative segment for each contour level.
///
/// `inline` removes a small gap from the representative segment before the
/// text is added. `fontsize` controls the SVG text style.
pub fn Figure::clabel(
  self : Figure,
  contours : ContourSet,
  inline~ : Bool = true,
  fontsize~ : Int32 = 10,
  color~ : String = "#111827",
) -> Unit raise @core.DataError {
  self.axes().clabel(contours, inline~, fontsize~, color~)
}

///|
/// Add one text label at a representative segment for each contour level.
pub fn Axes::clabel(
  self : Axes,
  contours : ContourSet,
  inline~ : Bool = true,
  fontsize~ : Int32 = 10,
  color~ : String = "#111827",
) -> Unit raise @core.DataError {
  if fontsize < 1 {
    raise @core.DataError::InvalidContour(
      message="contour label fontsize must be positive",
    )
  }
  if contours.filled() {
    return
  }
  let style = @core.style(color, font_size=Double::from_int(fontsize))
  for level in contours.levels {
    for index in 0..<contours.segments.length() {
      if contours.segment_levels[index] == level {
        let segment = contours.segments[index]
        if segment.length() > 0 {
          if inline {
            self.erase_inline_contour_segment(segment)
          }
          let point = segment[segment.length() / 2]
          self.push_artist(
            Artist::Text(point.x(), point.y(), Double::to_string(level), style),
          )
        }
        break
      }
    }
  }
}
