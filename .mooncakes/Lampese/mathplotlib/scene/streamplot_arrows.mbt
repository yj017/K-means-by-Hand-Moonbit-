///|
fn streamplot_plot_size(axes : Axes) -> (Double, Double) {
  let figure = axes.figure()
  let (width, height) = match axes.rect() {
    Some(rect) => (rect.width(), rect.height())
    None =>
      (
        Double::from_int(figure.width() - figure.margin() * 2),
        Double::from_int(figure.height() - figure.margin() * 2),
      )
  }
  (width, height)
}

///|
fn streamplot_arrow_data_point(
  tail : @core.Point,
  screen_x : Double,
  screen_y : Double,
  x_pixels : Double,
  y_pixels : Double,
) -> @core.Point {
  @core.point(tail.x() + screen_x / x_pixels, tail.y() - screen_y / y_pixels)
}

///|
fn streamplot_arrow_vertices(
  tail : @core.Point,
  tip : @core.Point,
  direction_x : Double,
  direction_y : Double,
  head_length : Double,
  head_width : Double,
  x_pixels : Double,
  y_pixels : Double,
) -> (@core.Point, @core.Point, @core.Point) {
  let screen_length = (direction_x * direction_x + direction_y * direction_y).sqrt()
  let base_screen_x = direction_x - direction_x / screen_length * head_length
  let base_screen_y = direction_y - direction_y / screen_length * head_length
  let perpendicular_x = -direction_y / screen_length * head_width / 2.0
  let perpendicular_y = direction_x / screen_length * head_width / 2.0
  let left = streamplot_arrow_data_point(
    tail,
    base_screen_x + perpendicular_x,
    base_screen_y + perpendicular_y,
    x_pixels,
    y_pixels,
  )
  let right = streamplot_arrow_data_point(
    tail,
    base_screen_x - perpendicular_x,
    base_screen_y - perpendicular_y,
    x_pixels,
    y_pixels,
  )
  (left, tip, right)
}

///|
fn streamplot_arrowhead(
  tail : @core.Point,
  tip : @core.Point,
  direction_x : Double,
  direction_y : Double,
  head_length : Double,
  head_width : Double,
  x_pixels : Double,
  y_pixels : Double,
  style : @core.Style,
) -> Artist {
  let (left, _, right) = streamplot_arrow_vertices(
    tail, tip, direction_x, direction_y, head_length, head_width, x_pixels, y_pixels,
  )
  Artist::Polygon([left, tip, right], style)
}

///|
fn streamplot_open_arrowhead(
  tail : @core.Point,
  tip : @core.Point,
  direction_x : Double,
  direction_y : Double,
  head_length : Double,
  head_width : Double,
  x_pixels : Double,
  y_pixels : Double,
  style : @core.Style,
) -> Artist {
  let (left, _, right) = streamplot_arrow_vertices(
    tail, tip, direction_x, direction_y, head_length, head_width, x_pixels, y_pixels,
  )
  Artist::Line([left, tip, right], style)
}

///|
fn streamplot_arrow_bar(
  endpoint : @core.Point,
  direction_x : Double,
  direction_y : Double,
  width : Double,
  x_pixels : Double,
  y_pixels : Double,
  style : @core.Style,
) -> Artist {
  let screen_length = (direction_x * direction_x + direction_y * direction_y).sqrt()
  let perpendicular_x = -direction_y / screen_length * width / 2.0
  let perpendicular_y = direction_x / screen_length * width / 2.0
  let left = streamplot_arrow_data_point(
    endpoint, perpendicular_x, perpendicular_y, x_pixels, y_pixels,
  )
  let right = streamplot_arrow_data_point(
    endpoint,
    -perpendicular_x,
    -perpendicular_y,
    x_pixels,
    y_pixels,
  )
  Artist::Line([left, right], style)
}

///|
/// Add arrows at equal arc-length fractions of one streamline.
///
/// Arrowhead dimensions are computed in display units, matching Matplotlib's
/// `mutation_scale=10*arrowsize`, then converted back to data coordinates for
/// the backend-independent scene graph.
fn add_stream_arrows(
  axes : Axes,
  line : Array[@core.Point],
  count : Int32,
  color : String,
  linewidth : Double,
  arrow_size : Double,
  arrowstyle : String,
  x_span : Double,
  y_span : Double,
  xs : Array[Double],
  ys : Array[Double],
  linewidth_grid : Array[Array[Double]]?,
  color_grid : Array[Array[Double]]?,
  color_norm : @colors.ColorNorm?,
  color_map : @colors.ColorMap?,
  series : String,
) -> Array[Artist] raise @core.DataError {
  let result : Array[Artist] = []
  if count <= 0 || line.length() < 2 {
    return result
  }
  let distances = Array(capacity=line.length())
  distances.push(0.0)
  for index in 1..<line.length() {
    let previous = line[index - 1]
    let current = line[index]
    let dx = current.x() - previous.x()
    let dy = current.y() - previous.y()
    distances.push(distances[index - 1] + (dx * dx + dy * dy).sqrt())
  }
  let total = distances[distances.length() - 1]
  if total <= 0.0 || !stream_finite(total) {
    return result
  }
  let (plot_width, plot_height) = streamplot_plot_size(axes)
  let mut x_pixels = plot_width / x_span
  let mut y_pixels = plot_height / y_span
  if axes.get_adjustable() == "datalim" &&
    (axes.get_aspect() is Some(_) || axes.get_box_aspect() is Some(_)) {
    let view = axes.resolve_aspect_view()
    axes.commit_aspect_view(view)
    x_pixels = view.0.2 / (view.1.upper() - view.1.lower()).abs()
    y_pixels = view.0.3 / (view.2.upper() - view.2.lower()).abs()
  } else if axes.get_aspect() is Some(aspect) {
    let units_x = plot_width / x_span
    let units_y = plot_height / y_span / aspect
    if units_x > units_y {
      x_pixels = units_y
      y_pixels = units_y * aspect
    } else {
      y_pixels = units_x * aspect
    }
  }
  for arrow_index in 1..<=count {
    let target = total *
      Double::from_int(arrow_index) /
      Double::from_int(count + 1)
    let mut segment = distances.length() - 2
    for index in 1..<distances.length() {
      if distances[index] >= target {
        segment = index - 1
        break
      }
    }
    let tail = line[segment]
    let next = line[Int32::min(segment + 1, line.length() - 1)]
    let (arrow_color, arrow_width) = match
      stream_style_at(
        xs, ys, tail, linewidth, color, linewidth_grid, color_grid, color_norm, color_map,
      ) {
      Some((color, width, _)) => (color, width)
      None => continue
    }
    let line_style = @core.style(arrow_color, width=arrow_width)
    let direction_x = (next.x() - tail.x()) * x_pixels / 2.0
    let direction_y = -(next.y() - tail.y()) * y_pixels / 2.0
    let screen_length = (direction_x * direction_x + direction_y * direction_y).sqrt()
    if screen_length == 0.0 {
      continue
    }
    let tip = streamplot_arrow_data_point(
      tail, direction_x, direction_y, x_pixels, y_pixels,
    )
    let requested_head = 10.0 * arrow_size
    let head_length = Double::min(requested_head, screen_length)
    let head_width = head_length * 0.65
    let (start_head, end_head, start_filled, end_filled, start_bar, end_bar) = match
      arrowstyle {
      "<-" => (true, false, false, false, false, false)
      "->" => (false, true, false, false, false, false)
      "<->" => (true, true, false, false, false, false)
      "<|-" => (true, false, true, false, false, false)
      "-|>" => (false, true, false, true, false, false)
      "<|-|>" => (true, true, true, true, false, false)
      "]-" => (false, false, false, false, true, false)
      "-[" => (false, false, false, false, false, true)
      "]-[" => (false, false, false, false, true, true)
      "|-|" => (false, false, false, false, true, true)
      // FancyArrowPatch's named styles are curved path styles in
      // Matplotlib.  A filled display-space wedge is the closest scene
      // representation available without introducing a path artist.
      "fancy" | "simple" | "wedge" => (false, true, false, true, false, false)
      _ => (false, false, false, false, false, false)
    }
    let base_screen_x = direction_x - direction_x / screen_length * head_length
    let base_screen_y = direction_y - direction_y / screen_length * head_length
    let base_end = streamplot_arrow_data_point(
      tail, base_screen_x, base_screen_y, x_pixels, y_pixels,
    )
    let reverse_direction_x = -direction_x
    let reverse_direction_y = -direction_y
    let reverse_base_screen_x = reverse_direction_x -
      reverse_direction_x / screen_length * head_length
    let reverse_base_screen_y = reverse_direction_y -
      reverse_direction_y / screen_length * head_length
    let base_start = streamplot_arrow_data_point(
      tip, reverse_base_screen_x, reverse_base_screen_y, x_pixels, y_pixels,
    )
    let shaft_start = if start_head { base_start } else { tail }
    let shaft_end = if end_head { base_end } else { tip }
    let line_artist = Artist::Line([shaft_start, shaft_end], line_style)
    axes.push_streamplot_arrow(line_artist, series)
    if arrowstyle == "-" {
      result.push(line_artist)
    }
    if arrowstyle != "-" && head_width > 0.0 && head_length > 0.0 {
      if start_head {
        let head_style = @core.style(
          arrow_color,
          width=arrow_width,
          fill=if start_filled { arrow_color } else { "" },
        )
        let head = if start_filled {
          streamplot_arrowhead(
            tip, tail, reverse_direction_x, reverse_direction_y, head_length, head_width,
            x_pixels, y_pixels, head_style,
          )
        } else {
          streamplot_open_arrowhead(
            tip, tail, reverse_direction_x, reverse_direction_y, head_length, head_width,
            x_pixels, y_pixels, head_style,
          )
        }
        axes.push_streamplot_arrow(head, series)
        result.push(head)
      }
      if end_head {
        let head_style = @core.style(
          arrow_color,
          width=arrow_width,
          fill=if end_filled { arrow_color } else { "" },
        )
        let head = if end_filled {
          streamplot_arrowhead(
            tail, tip, direction_x, direction_y, head_length, head_width, x_pixels,
            y_pixels, head_style,
          )
        } else {
          streamplot_open_arrowhead(
            tail, tip, direction_x, direction_y, head_length, head_width, x_pixels,
            y_pixels, head_style,
          )
        }
        axes.push_streamplot_arrow(head, series)
        result.push(head)
      }
    }
    if start_bar {
      let bar = streamplot_arrow_bar(
        tail, direction_x, direction_y, head_width, x_pixels, y_pixels, line_style,
      )
      axes.push_streamplot_arrow(bar, series)
      result.push(bar)
    }
    if end_bar {
      let bar = streamplot_arrow_bar(
        tip, direction_x, direction_y, head_width, x_pixels, y_pixels, line_style,
      )
      axes.push_streamplot_arrow(bar, series)
      result.push(bar)
    }
  }
  result
}
