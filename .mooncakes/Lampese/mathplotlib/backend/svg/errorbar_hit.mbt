///|
// Error-bar lines and caps are axis-aligned. Capture only the visible part of
// each actually painted segment while retaining its source sample unchanged.
fn visible_error_segment(
  segment : (Double, Double, Double, Double),
  bounds : (Double, Double, Double, Double),
) -> (Double, Double, Double, Double)? {
  let (x0, y0, x1, y1) = segment
  let (left, top, width, height) = bounds
  for coordinate in [x0, y0, x1, y1] {
    if coordinate.is_nan() || coordinate.is_inf() {
      return None
    }
  }
  if x0 == x1 && x0 >= left && x0 <= left + width {
    let low = y0.min(y1).max(top)
    let high = y0.max(y1).min(top + height)
    if low <= high {
      Some((x0, low, x1, high))
    } else {
      None
    }
  } else if y0 == y1 && y0 >= top && y0 <= top + height {
    let low = x0.min(x1).max(left)
    let high = x0.max(x1).min(left + width)
    if low <= high {
      Some((low, y0, high, y1))
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn collect_drawing_errorbar(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  sample : RenderedErrorBar,
  metadata : @render.HitMetadata,
  position : (Double, Double, Double, Double),
) -> Unit {
  for
    coordinate in [
      sample.screen_x,
      sample.screen_y,
      sample.x_range.0,
      sample.x_range.1,
      sample.y_range.0,
      sample.y_range.1,
    ] {
    if coordinate.is_nan() || coordinate.is_inf() {
      return
    }
  }
  let visible = []
  for segment in sample.segments {
    if visible_error_segment(segment, position) is Some(clipped) {
      visible.push(clipped)
    }
  }
  let (left, top, width, height) = position
  let center_visible = sample.screen_x >= left &&
    sample.screen_x <= left + width &&
    sample.screen_y >= top &&
    sample.screen_y <= top + height
  if !center_visible && visible.is_empty() {
    return
  }
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    sample.source_index,
    sample.point.x(),
    sample.point.y(),
    sample.screen_x,
    sample.screen_y,
  )
  let info = @drawing.hit_info(
    point,
    ErrorBar,
    value=sample.point.y(),
    series=metadata.series(),
    error=Some(@drawing.error_info(sample.x_range, sample.y_range)),
  )
  output.points.push(point)
  // Retain the real center as the sole XNearest candidate. A center outside
  // this panel is deliberately skipped by point proximity and XNearest.
  output.targets.push(@drawing.hit_target(info, Point, position))
  for (x0, y0, x1, y1) in visible {
    output.targets.push(
      @drawing.hit_target(info, Segment(x0, y0, x1, y1), position),
    )
  }
}
