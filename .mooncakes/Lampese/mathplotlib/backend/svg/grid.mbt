///|
fn append_grid(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  x_ticks : Array[Double],
  y_ticks : Array[Double],
  x_minor_ticks : Array[Double],
  y_minor_ticks : Array[Double],
  x_labels : Array[String],
  y_labels : Array[String],
  x_minor_labels : Array[String],
  y_minor_labels : Array[String],
  x_offset_label : String,
  y_offset_label : String,
  x_position : @axis.TickPosition?,
  y_position : @axis.TickPosition?,
  show_x_tick_labels : Bool,
  show_y_tick_labels : Bool,
  x_grid_visible : Bool,
  x_grid_color : String,
  x_grid_width : Double,
  y_grid_visible : Bool,
  y_grid_color : String,
  y_grid_width : Double,
  x_minor_grid_visible : Bool,
  x_minor_grid_color : String,
  x_minor_grid_width : Double,
  y_minor_grid_visible : Bool,
  y_minor_grid_color : String,
  y_minor_grid_width : Double,
  x_tick_label_size : Double,
  y_tick_label_size : Double,
) -> Unit {
  let x_top = match x_position {
    Some(@axis.TickPosition::Top) => true
    Some(@axis.TickPosition::Both) => true
    _ => false
  }
  let x_bottom = match x_position {
    Some(@axis.TickPosition::Top) => false
    _ => true
  }
  let y_left = match y_position {
    Some(@axis.TickPosition::Right) => false
    _ => true
  }
  let y_right = match y_position {
    Some(@axis.TickPosition::Right) => true
    Some(@axis.TickPosition::Both) => true
    _ => false
  }
  for value in x_minor_ticks {
    if tick_in_view(value, scale.x_axis_scale, scale.xmin, scale.xmax) &&
      x_minor_grid_visible {
      let x = map_x(scale, left, plot_width, value)
      try! writer.empty_element("line", [
        ("x1", float_text(x)),
        ("y1", float_text(top)),
        ("x2", float_text(x)),
        ("y2", float_text(top + plot_height)),
        ("stroke", x_minor_grid_color),
        ("stroke-width", float_text(x_minor_grid_width)),
      ])
    }
  }
  for value in y_minor_ticks {
    if tick_in_view(value, scale.y_axis_scale, scale.ymin, scale.ymax) &&
      y_minor_grid_visible {
      let y = map_y(scale, top, plot_height, value)
      try! writer.empty_element("line", [
        ("x1", float_text(left)),
        ("y1", float_text(y)),
        ("x2", float_text(left + plot_width)),
        ("y2", float_text(y)),
        ("stroke", y_minor_grid_color),
        ("stroke-width", float_text(y_minor_grid_width)),
      ])
    }
  }
  for index in 0..<x_minor_ticks.length() {
    let value = x_minor_ticks[index]
    let label = x_minor_labels[index]
    if label != "" &&
      show_x_tick_labels &&
      tick_in_view(value, scale.x_axis_scale, scale.xmin, scale.xmax) {
      let x = map_x(scale, left, plot_width, value)
      if x_bottom {
        append_text(
          writer,
          x,
          top + plot_height + 18.0,
          label,
          "middle",
          x_tick_label_size,
        )
      }
      if x_top {
        append_text(writer, x, top - 8.0, label, "middle", x_tick_label_size)
      }
    }
  }
  for index in 0..<y_minor_ticks.length() {
    let value = y_minor_ticks[index]
    let label = y_minor_labels[index]
    if label != "" &&
      show_y_tick_labels &&
      tick_in_view(value, scale.y_axis_scale, scale.ymin, scale.ymax) {
      let y = map_y(scale, top, plot_height, value)
      if y_left {
        append_text(
          writer,
          left - 8.0,
          y + 3.0,
          label,
          "end",
          y_tick_label_size,
        )
      }
      if y_right {
        append_text(
          writer,
          left + plot_width + 8.0,
          y + 3.0,
          label,
          "start",
          y_tick_label_size,
        )
      }
    }
  }
  for i in 0..<x_ticks.length() {
    let value = x_ticks[i]
    if tick_in_view(value, scale.x_axis_scale, scale.xmin, scale.xmax) {
      let x = map_x(scale, left, plot_width, value)
      if x_grid_visible {
        try! writer.empty_element("line", [
          ("x1", float_text(x)),
          ("y1", float_text(top)),
          ("x2", float_text(x)),
          ("y2", float_text(top + plot_height)),
          ("stroke", x_grid_color),
          ("stroke-width", float_text(x_grid_width)),
        ])
      }
      if x_bottom && show_x_tick_labels {
        append_text(
          writer,
          x,
          top + plot_height + 18.0,
          x_labels[i],
          "middle",
          x_tick_label_size,
        )
      }
      if x_top && show_x_tick_labels {
        append_text(
          writer,
          x,
          top - 8.0,
          x_labels[i],
          "middle",
          x_tick_label_size,
        )
      }
    }
  }
  if x_offset_label != "" && show_x_tick_labels {
    if x_bottom {
      append_text(
        writer,
        left + plot_width,
        top + plot_height + 33.0,
        x_offset_label,
        "end",
        9,
      )
    }
    if x_top {
      append_text(
        writer,
        left + plot_width,
        top - 23.0,
        x_offset_label,
        "end",
        9,
      )
    }
  }
  for i in 0..<y_ticks.length() {
    let value = y_ticks[i]
    if tick_in_view(value, scale.y_axis_scale, scale.ymin, scale.ymax) {
      let y = map_y(scale, top, plot_height, value)
      if y_grid_visible {
        try! writer.empty_element("line", [
          ("x1", float_text(left)),
          ("y1", float_text(y)),
          ("x2", float_text(left + plot_width)),
          ("y2", float_text(y)),
          ("stroke", y_grid_color),
          ("stroke-width", float_text(y_grid_width)),
        ])
      }
      if y_left && show_y_tick_labels {
        append_text(
          writer,
          left - 8.0,
          y + 3.0,
          y_labels[i],
          "end",
          y_tick_label_size,
        )
      }
      if y_right && show_y_tick_labels {
        append_text(
          writer,
          left + plot_width + 8.0,
          y + 3.0,
          y_labels[i],
          "start",
          y_tick_label_size,
        )
      }
    }
  }
  if y_offset_label != "" && show_y_tick_labels {
    if y_left {
      append_text(writer, left - 8.0, top - 8.0, y_offset_label, "end", 9)
    }
    if y_right {
      append_text(
        writer,
        left + plot_width + 8.0,
        top - 8.0,
        y_offset_label,
        "start",
        9,
      )
    }
  }
}
