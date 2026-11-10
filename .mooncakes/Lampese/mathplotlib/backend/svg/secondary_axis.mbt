///|
fn secondary_value_label(value : Double) -> String {
  float_text(value)
}

///|
fn secondary_primary_ticks(
  primary_ticks : Array[Double],
  count : Int32,
) -> Array[Double] {
  if primary_ticks.length() < 2 || count < 2 {
    primary_ticks.copy()
  } else {
    let result = Array(capacity=count)
    let first = primary_ticks[0]
    let last = primary_ticks[primary_ticks.length() - 1]
    for index in 0..<count {
      result.push(
        first +
        (last - first) * Double::from_int(index) / Double::from_int(count - 1),
      )
    }
    result
  }
}

///|
fn secondary_axis_ticks(
  axis : @render.SecondaryAxis,
  primary_ticks : Array[Double],
  primary_lower : Double,
  primary_upper : Double,
) -> Array[(Double, Double)] raise @core.DataError {
  if axis.tick_group_is_null() {
    return []
  }
  match axis.fixed_ticks() {
    Some(values) => values.map(value => (axis.inverse()(value), value))
    None =>
      match axis.locator() {
        Some(locator) => {
          let values = locator.tick_values_for_axis(
            axis.forward()(primary_lower),
            axis.forward()(primary_upper),
          )
          values.map(value => (axis.inverse()(value), value))
        }
        None =>
          secondary_primary_ticks(primary_ticks, axis.tick_count()).map(primary => {
            (primary, axis.forward()(primary))
          })
      }
  }
}

///|
fn secondary_axis_tick_labels(
  axis : @render.SecondaryAxis,
  values : Array[Double],
  primary_lower : Double,
  primary_upper : Double,
) -> Array[String] raise @core.DataError {
  if axis.tick_group_is_null() {
    return []
  }
  if axis.named_formatter() is Some(formatter) {
    return formatter.format_ticks(values)
  }
  match axis.formatter() {
    Some(formatter) => {
      let view = if axis.has_placement_provider() {
        // An owned child's source interval may include nonsingular expansion,
        // or still precede a later function sync. Do not remap parent bounds.
        axis
        .formatter_view_interval()
        .map(bounds => @core.limits(bounds.0, bounds.1))
      } else {
        Some(
          @core.limits(
            axis.forward()(primary_lower),
            axis.forward()(primary_upper),
          ),
        )
      }
      formatter.format_values_with_view(values, view)
    }
    None => values.map(secondary_value_label)
  }
}

///|
// SecondaryAxis only inherits a logarithmic parent scale. Other parents use
// function(inverse) and normalize the inverse coordinates linearly.
fn secondary_display_scale(scale : Scale, horizontal : Bool) -> Scale {
  let parent = if horizontal { scale.x_axis_scale } else { scale.y_axis_scale }
  let secondary = if parent.is_log() {
    @ticker_scale.Scale::Log
  } else {
    @ticker_scale.Scale::Linear
  }
  {
    xmin: scale.xmin,
    xmax: scale.xmax,
    ymin: scale.ymin,
    ymax: scale.ymax,
    x_axis_scale: if horizontal {
      secondary
    } else {
      scale.x_axis_scale
    },
    y_axis_scale: if horizontal {
      scale.y_axis_scale
    } else {
      secondary
    },
  }
}

///|
fn append_secondary_x_axis(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  primary_ticks : Array[Double],
  axis : @render.SecondaryAxis,
  prepared~ : SecondaryTickBundle? = None,
) -> Unit raise @core.DataError {
  let scale = secondary_display_scale(scale, true)
  let bundle = match prepared {
    Some(bundle) => bundle
    None => secondary_axis_bundle(axis, primary_ticks, scale.xmin, scale.xmax)
  }
  let (left, top, right, bottom, plot_width, alignment) = match bundle.drawing {
    Some(context) =>
      (
        context.left(),
        context.top(),
        context.right(),
        context.bottom(),
        context.right() - context.left(),
        context.alignment(),
      )
    None =>
      (
        left,
        top,
        left + plot_width,
        top + plot_height,
        plot_width,
        axis.location(),
      )
  }
  let at_top = alignment is @render.SecondaryLocation::Top
  let axis_y = if at_top { top } else { bottom }
  try! writer.empty_element("line", [
    ("x1", float_text(left)),
    ("y1", float_text(axis_y)),
    ("x2", float_text(right)),
    ("y2", float_text(axis_y)),
    ("stroke", "#374151"),
    ("stroke-width", "1"),
  ])
  let ticks = bundle.major
  let labels = bundle.major_labels
  for index, (primary, value) in bundle.minor {
    if secondary_tick_fraction(
        bundle,
        primary,
        value,
        scale.x_axis_scale,
        scale.xmin,
        scale.xmax,
      )
      is Some(fraction) {
      let x = match bundle.placement {
        Some(_) => left + fraction * plot_width
        None => map_x(scale, left, plot_width, primary)
      }
      let direction = if at_top { -1.0 } else { 1.0 }
      try! writer.empty_element("line", [
        ("x1", float_text(x)),
        ("y1", float_text(axis_y)),
        ("x2", float_text(x)),
        ("y2", float_text(axis_y + direction * 3.0)),
        ("stroke", "#374151"),
        ("stroke-width", "0.7"),
      ])
      if index < bundle.minor_labels.length() {
        append_text(
          writer,
          x,
          axis_y + direction * 17.0,
          bundle.minor_labels[index],
          "middle",
          axis.tick_label_size(),
        )
      }
    }
  }
  for index, tick in ticks {
    let (primary, value) = tick
    if secondary_tick_fraction(
        bundle,
        primary,
        value,
        scale.x_axis_scale,
        scale.xmin,
        scale.xmax,
      )
      is Some(fraction) {
      let x = match bundle.placement {
        Some(_) => left + fraction * plot_width
        None => map_x(scale, left, plot_width, primary)
      }
      let direction = if at_top { -1.0 } else { 1.0 }
      try! writer.empty_element("line", [
        ("x1", float_text(x)),
        ("y1", float_text(axis_y)),
        ("x2", float_text(x)),
        ("y2", float_text(axis_y + direction * 5.0)),
        ("stroke", "#374151"),
        ("stroke-width", "1"),
      ])
      append_text(
        writer,
        x,
        axis_y + direction * 17.0 + (if at_top { 0.0 } else { 1.0 }),
        labels[index],
        "middle",
        axis.tick_label_size(),
      )
    }
  }
  if bundle.offset != "" {
    append_text(
      writer,
      right,
      axis_y + (if at_top { -8.0 } else { 30.0 }),
      bundle.offset,
      "end",
      9,
    )
  }
  match axis.label() {
    Some(value) =>
      append_text(
        writer,
        left + plot_width / 2.0,
        axis_y + (if at_top { -34.0 } else { 38.0 }),
        value,
        "middle",
        13,
      )
    None => ()
  }
}

///|
fn append_secondary_y_axis(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  primary_ticks : Array[Double],
  axis : @render.SecondaryAxis,
  prepared~ : SecondaryTickBundle? = None,
) -> Unit raise @core.DataError {
  let scale = secondary_display_scale(scale, false)
  let bundle = match prepared {
    Some(bundle) => bundle
    None => secondary_axis_bundle(axis, primary_ticks, scale.ymin, scale.ymax)
  }
  let (left, top, right, bottom, plot_height, alignment) = match
    bundle.drawing {
    Some(context) =>
      (
        context.left(),
        context.top(),
        context.right(),
        context.bottom(),
        context.bottom() - context.top(),
        context.alignment(),
      )
    None =>
      (
        left,
        top,
        left + plot_width,
        top + plot_height,
        plot_height,
        axis.location(),
      )
  }
  let at_right = alignment is @render.SecondaryLocation::Right
  let axis_x = if at_right { right } else { left }
  try! writer.empty_element("line", [
    ("x1", float_text(axis_x)),
    ("y1", float_text(top)),
    ("x2", float_text(axis_x)),
    ("y2", float_text(bottom)),
    ("stroke", "#374151"),
    ("stroke-width", "1"),
  ])
  let ticks = bundle.major
  let labels = bundle.major_labels
  for index, (primary, value) in bundle.minor {
    if secondary_tick_fraction(
        bundle,
        primary,
        value,
        scale.y_axis_scale,
        scale.ymin,
        scale.ymax,
      )
      is Some(fraction) {
      let y = match bundle.placement {
        Some(_) => top + (1.0 - fraction) * plot_height
        None => map_y(scale, top, plot_height, primary)
      }
      let direction = if at_right { 1.0 } else { -1.0 }
      try! writer.empty_element("line", [
        ("x1", float_text(axis_x)),
        ("y1", float_text(y)),
        ("x2", float_text(axis_x + direction * 3.0)),
        ("y2", float_text(y)),
        ("stroke", "#374151"),
        ("stroke-width", "0.7"),
      ])
      if index < bundle.minor_labels.length() {
        append_text(
          writer,
          axis_x + direction * 8.0,
          y + 3.0,
          bundle.minor_labels[index],
          if at_right {
            "start"
          } else {
            "end"
          },
          axis.tick_label_size(),
        )
      }
    }
  }
  for index, tick in ticks {
    let (primary, value) = tick
    if secondary_tick_fraction(
        bundle,
        primary,
        value,
        scale.y_axis_scale,
        scale.ymin,
        scale.ymax,
      )
      is Some(fraction) {
      let y = match bundle.placement {
        Some(_) => top + (1.0 - fraction) * plot_height
        None => map_y(scale, top, plot_height, primary)
      }
      let direction = if at_right { 1.0 } else { -1.0 }
      try! writer.empty_element("line", [
        ("x1", float_text(axis_x)),
        ("y1", float_text(y)),
        ("x2", float_text(axis_x + direction * 5.0)),
        ("y2", float_text(y)),
        ("stroke", "#374151"),
        ("stroke-width", "1"),
      ])
      append_text(
        writer,
        axis_x + direction * 8.0,
        y + 3.0,
        labels[index],
        if at_right {
          "start"
        } else {
          "end"
        },
        axis.tick_label_size(),
      )
    }
  }
  if bundle.offset != "" {
    append_text(
      writer,
      axis_x + (if at_right { 8.0 } else { -8.0 }),
      top - 8.0,
      bundle.offset,
      if at_right {
        "start"
      } else {
        "end"
      },
      9,
    )
  }
  match axis.label() {
    Some(value) =>
      append_text(
        writer,
        axis_x + (if at_right { 42.0 } else { -40.0 }),
        top + plot_height / 2.0,
        value,
        "middle",
        13,
      )
    None => ()
  }
}
