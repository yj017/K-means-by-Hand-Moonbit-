///|
priv struct RenderedBar {
  source_index : Int32
  point : @core.Point
  segment : @core.BarSegment?
  left : Double
  top : Double
  width : Double
  height : Double
}

///|
// Painting and hit geometry share the same scale, NaN filtering, baseline and
// spacing. Keep original source indices even when nonfinite bars are skipped.
fn bar_rectangles(
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  horizontal : Bool,
) -> Array[RenderedBar] {
  let visible = bar_geometry_points(points)
  let source_indices = []
  for index, point in points {
    if point.is_finite() {
      source_indices.push(index)
    }
  }
  let axis_scale = if horizontal {
    scale.x_axis_scale
  } else {
    scale.y_axis_scale
  }
  let category_scale = if horizontal {
    scale.y_axis_scale
  } else {
    scale.x_axis_scale
  }
  let minimum = if horizontal { scale.xmin } else { scale.ymin }
  let maximum = if horizontal { scale.xmax } else { scale.ymax }
  let baseline_value = if axis_scale.is_log() {
    minimum
  } else {
    clamp_to_limits(0.0, minimum, maximum)
  }
  let baseline = if horizontal {
    map_x(scale, left, plot_width, baseline_value)
  } else {
    map_y(scale, top, plot_height, baseline_value)
  }
  let result = []
  for i in 0..<visible.length() {
    let p = visible[i]
    if !category_scale.is_valid(if horizontal { p.y() } else { p.x() }) {
      continue
    }
    let raw_value = if horizontal { p.x() } else { p.y() }
    let value_endpoint = if axis_scale.is_valid(raw_value) {
      raw_value
    } else {
      // A probability interval can cover the valid viewport even though its
      // raw value and zero baseline are both outside Logit's open domain.
      // Keep the old mapping untouched for all valid value endpoints.
      if !axis_scale.is_logit() {
        continue
      }
      guard bar_segment_axis_edges(
          Double::min(0.0, raw_value),
          Double::max(0.0, raw_value),
          minimum,
          maximum,
          axis_scale,
        )
        is Some((_, endpoint)) else {
        continue
      }
      endpoint
    }
    let half = bar_data_half_span(visible, i, horizontal)
    let (first, last) = if horizontal {
      (
        map_y(
          scale,
          top,
          plot_height,
          bar_valid_edge(
            p.y() - half,
            p.y(),
            scale.ymin,
            scale.ymax,
            scale.y_axis_scale,
          ),
        ),
        map_y(
          scale,
          top,
          plot_height,
          bar_valid_edge(
            p.y() + half,
            p.y(),
            scale.ymin,
            scale.ymax,
            scale.y_axis_scale,
          ),
        ),
      )
    } else {
      (
        map_x(
          scale,
          left,
          plot_width,
          bar_valid_edge(
            p.x() - half,
            p.x(),
            scale.xmin,
            scale.xmax,
            scale.x_axis_scale,
          ),
        ),
        map_x(
          scale,
          left,
          plot_width,
          bar_valid_edge(
            p.x() + half,
            p.x(),
            scale.xmin,
            scale.xmax,
            scale.x_axis_scale,
          ),
        ),
      )
    }
    let thickness = Double::max(Double::abs(last - first), 1.0)
    let value = if horizontal {
      map_x(scale, left, plot_width, value_endpoint)
    } else {
      map_y(scale, top, plot_height, value_endpoint)
    }
    let (x, y, width, height) = if horizontal {
      (
        Double::min(value, baseline),
        (first + last - thickness) / 2.0,
        Double::abs(value - baseline),
        thickness,
      )
    } else {
      (
        (first + last - thickness) / 2.0,
        Double::min(value, baseline),
        thickness,
        Double::abs(value - baseline),
      )
    }
    result.push({
      source_index: source_indices[i],
      point: p,
      segment: None,
      left: x,
      top: y,
      width,
      height,
    })
  }
  result
}

///|
fn append_bar_rectangles(
  writer : @xml.Writer,
  rectangles : Array[RenderedBar],
  style : @core.Style,
  on_bar : ((RenderedBar) -> Unit)?,
) -> Unit {
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  for rectangle in rectangles {
    try! writer.empty_element("rect", [
      ("x", float_text(rectangle.left)),
      ("y", float_text(rectangle.top)),
      ("width", float_text(rectangle.width)),
      ("height", float_text(rectangle.height)),
      ("fill", fill),
    ])
    if on_bar is Some(collect) {
      collect(rectangle)
    }
  }
}

///|
fn append_bars(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  on_bar~ : ((RenderedBar) -> Unit)? = None,
) -> Unit {
  append_bar_rectangles(
    writer,
    bar_rectangles(scale, left, top, plot_width, plot_height, points, false),
    style,
    on_bar,
  )
}

///|
fn append_barh(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  on_bar~ : ((RenderedBar) -> Unit)? = None,
) -> Unit {
  append_bar_rectangles(
    writer,
    bar_rectangles(scale, left, top, plot_width, plot_height, points, true),
    style,
    on_bar,
  )
}
