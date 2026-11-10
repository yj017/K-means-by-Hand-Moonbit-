///|
fn violin_side_bounds(
  position : Double,
  width : Double,
  side : @render.ViolinSide,
) -> (Double, Double) {
  let half = width / 2.0
  match side {
    @render.ViolinSide::Both => (position - half, position + half)
    @render.ViolinSide::Low => (position - half, position)
    @render.ViolinSide::High => (position, position + half)
  }
}

///|
fn violin_polygon_points_text(
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  upper : Array[@core.Point],
  lower : Array[@core.Point],
) -> String {
  polygon_points_text(scale, left, top, plot_width, plot_height, upper, lower)
}

///|
fn append_violin_body(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  stat : @render.ViolinStats,
  position : Double,
  width : Double,
  horizontal : Bool,
  side : @render.ViolinSide,
  body_style : @core.Style,
  line_style : @core.Style,
  opacity : Double,
  on_body~ : ((Array[@core.Point], Array[@core.Point]) -> Unit)? = None,
) -> Unit {
  let coords = stat.coords()
  let vals = stat.vals()
  let count = Int32::min(coords.length(), vals.length())
  if count < 2 {
    return
  }
  let mut maximum = 0.0
  for index in 0..<count {
    if vals[index] > maximum {
      maximum = vals[index]
    }
  }
  if maximum <= 0.0 || maximum.is_nan() || maximum.is_inf() {
    return
  }
  let upper = Array(capacity=count)
  let lower = Array(capacity=count)
  let half = width / 2.0
  for index in 0..<count {
    let coordinate = coords[index]
    let ratio = Double::max(0.0, vals[index] / maximum)
    let offset = half * ratio
    let low = match side {
      @render.ViolinSide::Both | @render.ViolinSide::Low => position - offset
      @render.ViolinSide::High => position
    }
    let high = match side {
      @render.ViolinSide::Both | @render.ViolinSide::High => position + offset
      @render.ViolinSide::Low => position
    }
    if horizontal {
      upper.push(@core.point(coordinate, high))
      lower.push(@core.point(coordinate, low))
    } else {
      upper.push(@core.point(high, coordinate))
      lower.push(@core.point(low, coordinate))
    }
  }
  let mut valid = true
  for index in 0..<count {
    if !valid_point(scale, upper[index]) || !valid_point(scale, lower[index]) {
      valid = false
    }
  }
  if valid {
    try! writer.empty_element("polygon", [
      (
        "points",
        violin_polygon_points_text(
          scale, left, top, plot_width, plot_height, upper, lower,
        ),
      ),
      ("fill", body_style.fill()),
      ("fill-opacity", float_text(opacity)),
      ("stroke", line_style.color()),
      ("stroke-width", float_text(line_style.width())),
    ])
    if on_body is Some(collect) {
      collect(upper, lower)
    }
  }
}

///|
fn append_violin_perpendicular(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  value : Double,
  position : Double,
  width : Double,
  horizontal : Bool,
  side : @render.ViolinSide,
  style : @core.Style,
  on_line~ : (((Double, Double, Double, Double)) -> Unit)? = None,
) -> Unit {
  let segments : Array[(Double, Double, Double, Double)]? = on_line.map(_ => [])
  let (first, second) = violin_side_bounds(position, width, side)
  if horizontal {
    if scale.x_axis_scale.is_valid(value) &&
      scale.y_axis_scale.is_valid(first) &&
      scale.y_axis_scale.is_valid(second) {
      append_error_segment(
        writer,
        map_x(scale, left, plot_width, value),
        map_y(scale, top, plot_height, first),
        map_x(scale, left, plot_width, value),
        map_y(scale, top, plot_height, second),
        style,
        segments~,
      )
    }
  } else if scale.y_axis_scale.is_valid(value) &&
    scale.x_axis_scale.is_valid(first) &&
    scale.x_axis_scale.is_valid(second) {
    append_error_segment(
      writer,
      map_x(scale, left, plot_width, first),
      map_y(scale, top, plot_height, value),
      map_x(scale, left, plot_width, second),
      map_y(scale, top, plot_height, value),
      style,
      segments~,
    )
  }
  if on_line is Some(collect) {
    for segment in segments.unwrap() {
      collect(segment)
    }
  }
}

///|
fn append_violin_parallel(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  lower : Double,
  upper : Double,
  position : Double,
  horizontal : Bool,
  style : @core.Style,
  on_line~ : (((Double, Double, Double, Double)) -> Unit)? = None,
) -> Unit {
  let segments : Array[(Double, Double, Double, Double)]? = on_line.map(_ => [])
  if horizontal {
    if scale.x_axis_scale.is_valid(lower) &&
      scale.x_axis_scale.is_valid(upper) &&
      scale.y_axis_scale.is_valid(position) {
      append_error_segment(
        writer,
        map_x(scale, left, plot_width, lower),
        map_y(scale, top, plot_height, position),
        map_x(scale, left, plot_width, upper),
        map_y(scale, top, plot_height, position),
        style,
        segments~,
      )
    }
  } else if scale.y_axis_scale.is_valid(lower) &&
    scale.y_axis_scale.is_valid(upper) &&
    scale.x_axis_scale.is_valid(position) {
    append_error_segment(
      writer,
      map_x(scale, left, plot_width, position),
      map_y(scale, top, plot_height, lower),
      map_x(scale, left, plot_width, position),
      map_y(scale, top, plot_height, upper),
      style,
      segments~,
    )
  }
  if on_line is Some(collect) {
    for segment in segments.unwrap() {
      collect(segment)
    }
  }
}

///|
fn append_violin(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  stats : Array[@render.ViolinStats],
  positions : Array[Double],
  widths : Array[Double],
  horizontal : Bool,
  side : @render.ViolinSide,
  showmeans : Bool,
  showextrema : Bool,
  showmedians : Bool,
  body_style : @core.Style,
  line_style : @core.Style,
  opacity : Double,
  on_body~ : ((RenderedViolinBody) -> Unit)? = None,
  on_line~ : ((RenderedViolinLine) -> Unit)? = None,
) -> Unit {
  let count = Int32::min(
    stats.length(),
    Int32::min(positions.length(), widths.length()),
  )
  let mut base_index = 0
  for index in 0..<count {
    let stat = stats[index]
    let position = positions[index]
    let width = widths[index]
    let sample_count = Int32::min(stat.coords().length(), stat.vals().length())
    let group : RenderedViolinGroup = {
      index,
      base_index,
      stat,
      position,
      horizontal,
    }
    base_index += sample_count + 5 + stat.quantiles().length()
    append_violin_body(
      writer,
      scale,
      left,
      top,
      plot_width,
      plot_height,
      stat,
      position,
      width,
      horizontal,
      side,
      body_style,
      line_style,
      opacity,
      on_body=on_body.map(collect => {
        (upper, lower) => {
          collect({
            group,
            upper,
            lower,
            fill_visible: statistics_paint_visible(body_style.fill()) &&
            !(opacity <= 0.0),
            stroke_visible: statistics_stroke_visible(line_style),
          })
        }
      }),
    )
    if showmeans {
      append_violin_perpendicular(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        stat.mean(),
        position,
        width,
        horizontal,
        side,
        line_style,
        on_line=violin_line_callback(
          on_line,
          group,
          Mean,
          stat.mean(),
          sample_count,
          line_style,
        ),
      )
    }
    if showmedians {
      append_violin_perpendicular(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        stat.median(),
        position,
        width,
        horizontal,
        side,
        line_style,
        on_line=violin_line_callback(
          on_line,
          group,
          Median,
          stat.median(),
          sample_count + 1,
          line_style,
        ),
      )
    }
    if showextrema {
      append_violin_perpendicular(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        stat.min(),
        position,
        width,
        horizontal,
        side,
        line_style,
        on_line=violin_line_callback(
          on_line,
          group,
          Minimum,
          stat.min(),
          sample_count + 2,
          line_style,
        ),
      )
      append_violin_perpendicular(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        stat.max(),
        position,
        width,
        horizontal,
        side,
        line_style,
        on_line=violin_line_callback(
          on_line,
          group,
          Maximum,
          stat.max(),
          sample_count + 3,
          line_style,
        ),
      )
      append_violin_parallel(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        stat.min(),
        stat.max(),
        position,
        horizontal,
        line_style,
        on_line=violin_line_callback(
          on_line,
          group,
          Range,
          stat.median(),
          sample_count + 4,
          line_style,
        ),
      )
    }
    for quantile_index, quantile in stat.quantiles() {
      append_violin_perpendicular(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        quantile,
        position,
        width,
        horizontal,
        side,
        line_style,
        on_line=violin_line_callback(
          on_line,
          group,
          Quantile(quantile_index, quantile),
          quantile,
          sample_count + 5 + quantile_index,
          line_style,
        ),
      )
    }
  }
}
