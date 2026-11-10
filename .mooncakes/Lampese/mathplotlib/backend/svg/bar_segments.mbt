///|
// Shared data rectangle used by both range collection and the actual draw loop.
fn bar_segment_extent(
  segment : @core.BarSegment,
  horizontal : Bool,
) -> (Double, Double, Double, Double)? {
  let lower = segment.position - segment.width / 2.0
  let upper = segment.position + segment.width / 2.0
  let end = segment.baseline + segment.value
  for value in [lower, upper, segment.baseline, end, segment.width] {
    if value.is_nan() || value.is_inf() {
      return None
    }
  }
  if segment.width <= 0.0 || upper <= lower {
    return None
  }
  let minimum = Double::min(segment.baseline, end)
  let maximum = Double::max(segment.baseline, end)
  Some(
    if horizontal {
      (minimum, maximum, lower, upper)
    } else {
      (lower, upper, minimum, maximum)
    },
  )
}

///|
// A segment can cross one or both scale-domain boundaries. A bounded domain
// such as Logit may lie entirely between two invalid endpoints; retain its real
// intersection with the valid viewport. Single-edge clipping keeps its existing
// geometry, including inverted axes and ordinary Log bars.
fn bar_segment_axis_edges(
  first : Double,
  last : Double,
  view_first : Double,
  view_last : Double,
  axis_scale : @ticker_scale.Scale,
) -> (Double, Double)? {
  let first_valid = axis_scale.is_valid(first)
  let last_valid = axis_scale.is_valid(last)
  if !first_valid && !last_valid {
    let lower = Double::max(first, Double::min(view_first, view_last))
    let upper = Double::min(last, Double::max(view_first, view_last))
    if lower >= upper ||
      !axis_scale.is_valid(lower) ||
      !axis_scale.is_valid(upper) {
      return None
    }
    return Some((lower, upper))
  }
  let valid = if first_valid { first } else { last }
  Some(
    (
      bar_valid_edge(first, valid, view_first, view_last, axis_scale),
      bar_valid_edge(last, valid, view_first, view_last, axis_scale),
    ),
  )
}

///|
fn bar_segment_rectangles(
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  segments : Array[@core.BarSegment],
  horizontal : Bool,
) -> Array[RenderedBar] {
  let result = []
  for source_index, segment in segments {
    guard bar_segment_extent(segment, horizontal)
      is Some((xmin, xmax, ymin, ymax)) else {
      continue
    }
    guard bar_segment_axis_edges(
        xmin,
        xmax,
        scale.xmin,
        scale.xmax,
        scale.x_axis_scale,
      )
      is Some((x0, x1)) else {
      continue
    }
    guard bar_segment_axis_edges(
        ymin,
        ymax,
        scale.ymin,
        scale.ymax,
        scale.y_axis_scale,
      )
      is Some((y0, y1)) else {
      continue
    }
    let first_x = map_x(scale, left, plot_width, x0)
    let last_x = map_x(scale, left, plot_width, x1)
    let first_y = map_y(scale, top, plot_height, y0)
    let last_y = map_y(scale, top, plot_height, y1)
    let point = if horizontal {
      @core.point(segment.baseline + segment.value, segment.position)
    } else {
      @core.point(segment.position, segment.baseline + segment.value)
    }
    result.push({
      source_index,
      point,
      segment: Some(segment),
      left: Double::min(first_x, last_x),
      top: Double::min(first_y, last_y),
      width: Double::abs(last_x - first_x),
      height: Double::abs(last_y - first_y),
    })
  }
  result
}

///|
fn append_bar_segments(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  segments : Array[@core.BarSegment],
  horizontal : Bool,
  style : @core.Style,
  on_bar~ : ((RenderedBar) -> Unit)? = None,
) -> Unit {
  append_bar_rectangles(
    writer,
    bar_segment_rectangles(
      scale, left, top, plot_width, plot_height, segments, horizontal,
    ),
    style,
    on_bar,
  )
}
