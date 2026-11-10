///|
fn polar_error(message : String) -> @core.DataError {
  @core.DataError::InvalidReference(message="polar: " + message)
}

///|
fn polar_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn polar_display_scale() -> Scale {
  {
    xmin: -1.0,
    xmax: 1.0,
    ymin: -1.0,
    ymax: 1.0,
    x_axis_scale: @ticker_scale.linear_scale(),
    y_axis_scale: @ticker_scale.linear_scale(),
  }
}

///|
fn validate_polar_panel(panel : @render.Panel) -> Unit raise @core.DataError {
  guard panel.polar() is Some(p) else { return }
  if !p.cartesian_compatible() ||
    !panel.show_x_tick_labels() ||
    !panel.show_y_tick_labels() ||
    panel.anchor() != (0.5, 0.5) {
    raise polar_error(
      "Cartesian grids, margins, tick-label visibility and anchors are unsupported",
    )
  }
  for spine in panel.spines() {
    if !spine.visible() ||
      spine.color() != "#374151" ||
      spine.linewidth() != 1.2 ||
      !(spine.position() is @render.SpinePosition::Axes) ||
      spine.bounds() is Some(_) {
      raise polar_error("Cartesian spine settings are unsupported")
    }
  }
  if panel.explicit_bounds() is Some(_) ||
    !panel.frame_visible() ||
    panel.share_x_group() is Some(_) ||
    panel.share_y_group() is Some(_) ||
    panel.aspect() is Some(_) ||
    panel.box_aspect() is Some(_) ||
    panel.adjustable() != "box" ||
    !panel.secondary_x().is_empty() ||
    !panel.secondary_y().is_empty() {
    raise polar_error(
      "Cartesian bounds, axis-off, sharing, aspects and secondary axes are unsupported",
    )
  }
  for axis in [panel.x_axis(), panel.y_axis()] {
    if axis.coordinate_scale_name() != "linear" ||
      axis.limits() is Some(_) ||
      axis.inverted() ||
      axis.label() is Some(_) ||
      axis.have_units() ||
      !axis.is_default_locator() ||
      !axis.is_default_formatter() ||
      axis.ticks() is Some(_) ||
      axis.tick_position() is Some(_) ||
      !axis.is_default_locator(minor=true) ||
      !axis.is_default_formatter(minor=true) {
      raise polar_error(
        "Cartesian scales, limits, units and tick settings are unsupported",
      )
    }
  }
  if panel.artists().length() != p.series_count() {
    raise polar_error("only typed polar series are supported")
  }
  for i, artist in panel.artists() {
    match artist {
      @render.Artist::Line(_, _) | @render.Artist::Scatter(_, _) => ()
      @render.Artist::Bar(_, _) =>
        match p.hit_data(i).bind(data => data.bar_width()) {
          Some(width) =>
            if !polar_finite(width) || width <= 0.0 || width > 2.0 * @math.PI {
              raise polar_error("invalid bar angular width")
            }
          None => raise polar_error("bar needs typed polar angular width")
        }
      _ => raise polar_error("unsupported artist")
    }
  }
  if !polar_finite(p.theta_offset()) {
    raise polar_error("nonfinite theta offset")
  }
  if p.radius_max() is Some(value) && (!polar_finite(value) || value <= 0.0) {
    raise polar_error("radius maximum must be finite and positive")
  }
  for
    (values, labels, radial) in [
      (p.theta_ticks(), p.theta_labels(), false),
      (p.radius_ticks().unwrap_or([]), p.radius_labels(), true),
    ] {
    if !labels.is_empty() && labels.length() != values.length() {
      raise polar_error("tick labels must match positions")
    }
    for value in values {
      if !polar_finite(value) || (radial && value < 0.0) {
        raise polar_error("invalid tick")
      }
    }
  }
}

///|
// Allow room for actual theta labels and the title, independently of XY aspect.
fn polar_panel_rect(
  figure : @render.Figure,
  panel : @render.Panel,
) -> (Double, Double, Double, Double) {
  let (left, top, width, height) = panel_rect(figure, panel)
  let labels = panel.polar().unwrap().theta_labels()
  let mut label_width = 0.0
  for label in labels {
    label_width = label_width.max(label.length().to_double() * 8.0)
  }
  let horizontal_pad = 30.0.max(label_width + 14.0)
  let top_pad = if panel.title() is Some(_) { 42.0 } else { 24.0 }
  let bottom_pad = 24.0
  let diameter = (width - 2.0 * horizontal_pad)
    .min(height - top_pad - bottom_pad)
    .max(0.0)
  let cx = left + width / 2.0
  let cy = top + top_pad + (height - top_pad - bottom_pad) / 2.0
  (cx - diameter / 2.0, cy - diameter / 2.0, diameter, diameter)
}

///|
fn polar_raw_valid(point : @core.Point) -> Bool {
  point.is_finite() && point.y() >= 0.0
}

///|
fn polar_radius_max(
  panel : @render.Panel,
  config : @render.PolarProjection,
) -> Double {
  if config.radius_max() is Some(value) {
    return value
  }
  let mut maximum = 0.0
  for artist in panel.artists() {
    let points = match artist {
      @render.Artist::Line(points, _)
      | @render.Artist::Scatter(points, _)
      | @render.Artist::Bar(points, _) => points
      _ => []
    }
    for point in points {
      if polar_raw_valid(point) {
        maximum = maximum.max(point.y())
      }
    }
  }
  if maximum > 0.0 {
    maximum
  } else {
    1.0
  }
}

///|
fn polar_phi(config : @render.PolarProjection, theta : Double) -> Double {
  let tau = 2.0 * @math.PI
  let reduced = theta % tau
  config.theta_offset() % tau +
  (if config.clockwise() { -reduced } else { reduced })
}

///|
// One retained slot per raw sample. Missing or unrepresentable projections
// become run breaks; no abs(radius), index compaction, or synthetic observation.
fn polar_project_points(
  points : Array[@core.Point],
  config : @render.PolarProjection,
  maximum : Double,
  position : (Double, Double, Double, Double),
  closed : Bool,
) -> Array[@core.Point] {
  let result = []
  let mut complete = true
  let scale = polar_display_scale()
  let (left, top, width, height) = position
  for point in points {
    let invalid = @core.point(0.0 / 0.0, 0.0 / 0.0)
    if !polar_raw_valid(point) {
      result.push(invalid)
      complete = false
      continue
    }
    let radius = point.y() / maximum
    let phi = polar_phi(config, point.x())
    let p = @core.point(radius * @math.cos(phi), radius * @math.sin(phi))
    if !p.is_finite() ||
      !polar_finite(map_x(scale, left, width, p.x())) ||
      !polar_finite(map_y(scale, top, height, p.y())) {
      result.push(invalid)
      complete = false
    } else {
      result.push(p)
    }
  }
  if closed && complete && points.length() > 1 {
    result.push(result[0])
  }
  result
}

///|
fn polar_circle(
  writer : @xml.Writer,
  cx : Double,
  cy : Double,
  radius : Double,
  stroke : String,
  width : Double,
) -> Unit {
  try! writer.empty_element("circle", [
    ("cx", float_text(cx)),
    ("cy", float_text(cy)),
    ("r", float_text(radius)),
    ("fill", "none"),
    ("stroke", stroke),
    ("stroke-width", float_text(width)),
  ])
}

///|
fn append_polar_panel(
  writer : @xml.Writer,
  figure : @render.Figure,
  panel : @render.Panel,
  config : @render.PolarProjection,
  panel_index : Int32,
  position : (Double, Double, Double, Double),
  capture~ : DrawingCapture? = None,
) -> Unit raise @core.DataError {
  let (left, top, width, height) = position
  let cx = left + width / 2.0
  let cy = top + height / 2.0
  let radius = width / 2.0
  let circle = (cx, cy, radius)
  if capture is Some(hits) {
    hits.polar_circles.push((panel_index, circle))
  }
  let maximum = polar_radius_max(panel, config)
  let (raw_left, raw_top, raw_width, raw_height) = panel_rect(figure, panel)
  if panel.title() is Some(title) {
    append_text(
      writer,
      raw_left + raw_width / 2.0,
      raw_top + 18.0,
      title,
      "middle",
      14.0,
    )
  }
  if radius > 0.0 {
    let radial_ticks = config
      .radius_ticks()
      .unwrap_or([ for i in 1..<=5 => maximum * (i.to_double() / 5.0) ])
    let radial_labels = config.radius_labels()
    for i, value in radial_ticks {
      if value <= 0.0 || value > maximum {
        continue
      }
      let r = radius * (value / maximum)
      polar_circle(writer, cx, cy, r, "#d1d5db", 0.8)
      let label = radial_labels.get(i).unwrap_or(float_text(value))
      append_text(
        writer,
        cx + r * 0.7071067811865476 + 4.0,
        cy - r * 0.7071067811865476 - 3.0,
        label,
        "start",
        10.0,
      )
    }
    let theta_labels = config.theta_labels()
    for i, theta in config.theta_ticks() {
      let phi = polar_phi(config, theta)
      let cosine = @math.cos(phi)
      let sine = @math.sin(phi)
      try! writer.empty_element("line", [
        ("x1", float_text(cx)),
        ("y1", float_text(cy)),
        ("x2", float_text(cx + radius * cosine)),
        ("y2", float_text(cy - radius * sine)),
        ("stroke", "#d1d5db"),
        ("stroke-width", "0.8"),
      ])
      let label = theta_labels.get(i).unwrap_or(float_text(theta))
      append_text(
        writer,
        cx + (radius + 12.0) * cosine,
        cy - (radius + 12.0) * sine + 4.0,
        label,
        if cosine > 0.2 {
          "start"
        } else if cosine < -0.2 {
          "end"
        } else {
          "middle"
        },
        11.0,
      )
    }
    polar_circle(writer, cx, cy, radius, "#6b7280", 1.2)
    // Geometry in the ID also avoids collisions between differently sized
    // SVG roots mounted together; identical IDs then have identical circles.
    let id = "moonplot-polar-clip-\{panel_index}-\{float_text(cx)}-\{float_text(cy)}-\{float_text(radius)}"
    try! writer.start_element("defs", [])
    try! writer.start_element("clipPath", [
      ("id", id),
      ("clipPathUnits", "userSpaceOnUse"),
    ])
    try! writer.empty_element("circle", [
      ("cx", float_text(cx)),
      ("cy", float_text(cy)),
      ("r", float_text(radius)),
    ])
    try! writer.end_element("clipPath")
    try! writer.end_element("defs")
    try! writer.start_element("g", [("clip-path", "url(#\{id})")])
    let scale = polar_display_scale()
    for i, artist in panel.artists() {
      match artist {
        @render.Artist::Line(points, style) => {
          let source = config
            .hit_data(i)
            .filter(data => capture is Some(_) && data.matches_points(points))
          let mapped = polar_project_points(
            points,
            config,
            maximum,
            position,
            config.closed(i),
          )
          append_line_artist(
            writer,
            scale,
            left,
            top,
            width,
            height,
            mapped,
            style,
            on_segment=polar_line_capture(
              capture,
              source,
              style,
              panel_index,
              i,
              position,
              circle,
              maximum,
              config.closed(i),
            ),
          )
        }
        @render.Artist::Scatter(points, style) => {
          let source = config
            .hit_data(i)
            .filter(data => {
              capture is Some(_) && data.matches_points(points, scatter=true)
            })
          let mapped = polar_project_points(
            points, config, maximum, position, false,
          )
          append_scatter(
            writer,
            scale,
            left,
            top,
            width,
            height,
            mapped,
            style,
            on_circle=polar_marker_capture(
              capture, source, style, panel_index, i, position, circle, maximum,
            ),
          )
        }
        @render.Artist::Bar(points, style) => {
          let data = config.hit_data(i).unwrap()
          let source = if capture is Some(_) && data.matches_bar(points) {
            Some(data)
          } else {
            None
          }
          append_polar_bars(
            writer,
            points,
            style,
            config,
            maximum,
            circle,
            data.bar_width().unwrap(),
            on_bar=polar_bar_capture(capture, source, panel_index, i, position),
          )
        }
        _ => () // validate_polar_panel already rejects unsupported input.
      }
    }
    try! writer.end_element("g")
  }
  append_legend(
    writer,
    raw_left,
    raw_top,
    raw_width,
    raw_height,
    panel.legend(),
    panel.legend_position(),
  )
}
