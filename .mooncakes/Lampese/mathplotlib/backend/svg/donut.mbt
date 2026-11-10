///|
// Both contours of a full ring need two arcs; a single 360-degree SVG arc has
// identical endpoints and would render nothing. Evenodd leaves the hole clear.
fn donut_path(
  cx : Double,
  cy : Double,
  inner : Double,
  outer : Double,
  start : Double,
  sweep : Double,
) -> String {
  let (ox0, oy0) = pie_point(cx, cy, outer, start)
  let (ix0, iy0) = pie_point(cx, cy, inner, start)
  if sweep >= 360.0 {
    let (ox1, oy1) = pie_point(cx, cy, outer, start + 180.0)
    let (ix1, iy1) = pie_point(cx, cy, inner, start + 180.0)
    return "M \{float_text(ox0)},\{float_text(oy0)} " +
      "A \{float_text(outer)},\{float_text(outer)} 0 1 0 \{float_text(ox1)},\{float_text(oy1)} " +
      "A \{float_text(outer)},\{float_text(outer)} 0 1 0 \{float_text(ox0)},\{float_text(oy0)} Z " +
      "M \{float_text(ix0)},\{float_text(iy0)} " +
      "A \{float_text(inner)},\{float_text(inner)} 0 1 1 \{float_text(ix1)},\{float_text(iy1)} " +
      "A \{float_text(inner)},\{float_text(inner)} 0 1 1 \{float_text(ix0)},\{float_text(iy0)} Z"
  }
  let (ox1, oy1) = pie_point(cx, cy, outer, start + sweep)
  let (ix1, iy1) = pie_point(cx, cy, inner, start + sweep)
  let large = if sweep > 180.0 { 1 } else { 0 }
  "M \{float_text(ox0)},\{float_text(oy0)} " +
  "A \{float_text(outer)},\{float_text(outer)} 0 \{large} 0 \{float_text(ox1)},\{float_text(oy1)} " +
  "L \{float_text(ix1)},\{float_text(iy1)} " +
  "A \{float_text(inner)},\{float_text(inner)} 0 \{large} 1 \{float_text(ix0)},\{float_text(iy0)} Z"
}

///|
fn append_donut(
  writer : @xml.Writer,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  values : Array[Double],
  labels : Array[String],
  colors : Array[String],
  start_angle : Double,
  inner_ratio : Double,
  on_slice~ : ((Int32, Double, Double, Double, Double, Double, Double, Double) -> Unit)? = None,
) -> Unit {
  if inner_ratio.is_nan() ||
    inner_ratio.is_inf() ||
    inner_ratio < 0.0 ||
    inner_ratio >= 1.0 {
    return
  }
  let mut total = 0.0
  for value in values {
    if !value.is_nan() && !value.is_inf() && value > 0.0 {
      total += value
    }
  }
  if total <= 0.0 ||
    total.is_inf() ||
    start_angle.is_nan() ||
    start_angle.is_inf() {
    return
  }
  // Normalize before trigonometry, including finite angles whose degree-to-radian
  // multiplication would overflow. Geometry and hit data share this angle.
  let normalized = start_angle % 360.0
  let first_angle = if normalized < 0.0 {
    normalized + 360.0
  } else {
    normalized
  }
  if inner_ratio == 0.0 {
    append_pie(
      writer,
      left,
      top,
      plot_width,
      plot_height,
      values,
      labels,
      colors,
      first_angle,
      on_slice=on_slice.map(collect => {
        (index, cx, cy, radius, start, sweep, fraction) => {
          collect(index, cx, cy, 0.0, radius, start, sweep, fraction)
        }
      }),
    )
    return
  }
  let cx = left + plot_width / 2.0
  let cy = top + plot_height / 2.0
  let outer = Double::min(plot_width, plot_height) * 0.32
  let inner = outer * inner_ratio
  let mut angle = first_angle
  for index, value in values {
    if value <= 0.0 || value.is_nan() || value.is_inf() {
      continue
    }
    let fraction = value / total
    let actual_sweep = fraction * 360.0
    let sweep = if actual_sweep >= 359.999 { 360.0 } else { actual_sweep }
    let fill = if index < colors.length() { colors[index] } else { "#9ca3af" }
    try! writer.empty_element("path", [
      ("d", donut_path(cx, cy, inner, outer, angle, sweep)),
      ("fill", fill),
      ("fill-rule", "evenodd"),
      ("stroke", "white"),
      ("stroke-width", "1"),
    ])
    if index < labels.length() && labels[index] != "" {
      let (x, y) = pie_point(cx, cy, outer * 1.12, angle + actual_sweep / 2.0)
      append_text(writer, x, y, labels[index], "middle", 11)
    }
    if on_slice is Some(collect) {
      collect(index, cx, cy, inner, outer, angle, sweep, fraction)
    }
    angle += actual_sweep
  }
}

///|
fn collect_drawing_donut(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  index : Int32,
  value : Double,
  labels : Array[String],
  series : String,
  cx : Double,
  cy : Double,
  inner : Double,
  outer : Double,
  start : Double,
  sweep : Double,
  fraction : Double,
  position : (Double, Double, Double, Double),
) -> Unit {
  let (x, y) = pie_point(cx, cy, (inner + outer) / 2.0, start + sweep / 2.0)
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    index,
    index.to_double(),
    value,
    x,
    y,
  )
  let category = if index < labels.length() {
    Some(labels[index])
  } else {
    None
  }
  let info = @drawing.hit_info(
    point,
    @drawing.HitKind::Pie,
    value~,
    series~,
    category~,
    fraction=Some(fraction),
  )
  output.points.push(point)
  output.targets.push(
    @drawing.hit_target(
      info,
      @drawing.HitShape::AnnularSector(cx, cy, inner, outer, start, sweep),
      position,
    ),
  )
}
