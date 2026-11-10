///|
fn pie_point(
  center_x : Double,
  center_y : Double,
  radius : Double,
  angle : Double,
) -> (Double, Double) {
  let radians = angle * @math.PI / 180.0
  (
    center_x + radius * @math.cos(radians),
    center_y - radius * @math.sin(radians),
  )
}

///|
fn pie_path(
  center_x : Double,
  center_y : Double,
  radius : Double,
  start_angle : Double,
  end_angle : Double,
) -> String {
  let (start_x, start_y) = pie_point(center_x, center_y, radius, start_angle)
  let (end_x, end_y) = pie_point(center_x, center_y, radius, end_angle)
  let large_arc = if Double::abs(end_angle - start_angle) > 180.0 {
    1
  } else {
    0
  }
  "M \{float_text(center_x)},\{float_text(center_y)} " +
  "L \{float_text(start_x)},\{float_text(start_y)} " +
  "A \{float_text(radius)},\{float_text(radius)} 0 \{large_arc} 0 " +
  "\{float_text(end_x)},\{float_text(end_y)} Z"
}

///|
fn append_pie(
  writer : @xml.Writer,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  values : Array[Double],
  labels : Array[String],
  colors : Array[String],
  start_angle : Double,
  on_slice~ : ((Int32, Double, Double, Double, Double, Double, Double) -> Unit)? = None,
) -> Unit {
  if values.length() == 0 {
    return
  }
  let mut total = 0.0
  for value in values {
    if !value.is_nan() && !value.is_inf() && value > 0.0 {
      total += value
    }
  }
  if total <= 0.0 {
    return
  }
  let center_x = left + plot_width / 2.0
  let center_y = top + plot_height / 2.0
  let radius = Double::min(plot_width, plot_height) * 0.32
  let mut angle = start_angle
  for index in 0..<values.length() {
    let value = values[index]
    if value <= 0.0 || value.is_nan() || value.is_inf() {
      continue
    }
    let sweep = value / total * 360.0
    let end_angle = angle + sweep
    let fill = if index < colors.length() { colors[index] } else { "#9ca3af" }
    if sweep >= 359.999 {
      try! writer.empty_element("circle", [
        ("cx", float_text(center_x)),
        ("cy", float_text(center_y)),
        ("r", float_text(radius)),
        ("fill", fill),
        ("stroke", "white"),
        ("stroke-width", "1"),
      ])
    } else {
      try! writer.empty_element("path", [
        ("d", pie_path(center_x, center_y, radius, angle, end_angle)),
        ("fill", fill),
        ("stroke", "white"),
        ("stroke-width", "1"),
      ])
    }
    if index < labels.length() && labels[index] != "" {
      let label_angle = angle + sweep / 2.0
      let (label_x, label_y) = pie_point(
        center_x,
        center_y,
        radius * 1.12,
        label_angle,
      )
      append_text(writer, label_x, label_y, labels[index], "middle", 11)
    }
    if on_slice is Some(collect) {
      collect(
        index,
        center_x,
        center_y,
        radius,
        angle,
        if sweep >= 359.999 {
          360.0
        } else {
          sweep
        },
        value / total,
      )
    }
    angle = end_angle
  }
}
