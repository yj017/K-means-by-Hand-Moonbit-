///|
// Keep spacing independent of the current viewport and of scale filtering.
// A nonfinite height must not leave a ghost bar baseline in the data limits.
fn bar_geometry_points(points : Array[@core.Point]) -> Array[@core.Point] {
  points.filter(point => point.is_finite())
}

///|
// The existing multi-bar spacing rule uses the next gap, or the previous gap
// for the final bar. A singleton uses one data unit rather than a view fraction.
fn bar_data_half_span(
  points : Array[@core.Point],
  index : Int32,
  horizontal : Bool,
) -> Double {
  let coordinate = fn(point : @core.Point) {
    if horizontal {
      point.y()
    } else {
      point.x()
    }
  }
  let value = coordinate(points[index])
  let gap = if index + 1 < points.length() {
    coordinate(points[index + 1]) - value
  } else if index > 0 {
    value - coordinate(points[index - 1])
  } else {
    1.0
  }
  Double::abs(gap) * 0.4
}

///|
// Clip a domain-crossing edge to the corresponding valid viewport boundary.
// In particular, never pass a nonpositive bar edge to a logarithmic transform.
fn bar_valid_edge(
  edge : Double,
  center : Double,
  first : Double,
  last : Double,
  axis_scale : @ticker_scale.Scale,
) -> Double {
  if axis_scale.is_valid(edge) {
    edge
  } else {
    let boundary = if edge < center {
      Double::min(first, last)
    } else {
      Double::max(first, last)
    }
    if axis_scale.is_valid(boundary) {
      boundary
    } else {
      center
    }
  }
}
