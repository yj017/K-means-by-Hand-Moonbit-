///|
priv struct RenderedBoxPlot {
  source_index : Int32
  stat : @boxplot.BoxStats
  position : Double
  horizontal : Bool
  fill_visible : Bool
  stroke_visible : Bool
  rectangle : (Double, Double, Double, Double)
  segments : Array[(Double, Double, Double, Double)]
  fliers : Array[(Double, Double, Double)]
}

///|
fn append_boxplot(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  stats : Array[@boxplot.BoxStats],
  horizontal : Bool,
  style : @core.Style,
  on_box~ : ((RenderedBoxPlot) -> Unit)? = None,
) -> Unit {
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  let fill_visible = statistics_paint_visible(fill)
  let stroke_visible = statistics_stroke_visible(style)
  let outliers_visible = statistics_paint_visible(style.color())
  let box_width = 0.6
  let cap_width = 0.2
  for index, stat in stats {
    let position = Double::from_int(index + 1)
    let segments : Array[(Double, Double, Double, Double)]? = on_box.map(_ => [])
    let fliers : Array[(Double, Double, Double)]? = on_box.map(_ => [])
    if horizontal {
      if !scale.x_axis_scale.is_valid(stat.q1()) ||
        !scale.x_axis_scale.is_valid(stat.q3()) {
        continue
      }
      let center_y = map_y(scale, top, plot_height, position)
      let y1 = map_y(scale, top, plot_height, position + box_width / 2.0)
      let y2 = map_y(scale, top, plot_height, position - box_width / 2.0)
      let x1 = map_x(scale, left, plot_width, stat.q1())
      let x2 = map_x(scale, left, plot_width, stat.q3())
      try! writer.empty_element("rect", [
        ("x", float_text(Double::min(x1, x2))),
        ("y", float_text(Double::min(y1, y2))),
        ("width", float_text(Double::abs(x2 - x1))),
        ("height", float_text(Double::abs(y2 - y1))),
        ("fill", fill),
        ("fill-opacity", "0.35"),
        ("stroke", style.color()),
        ("stroke-width", float_text(style.width())),
      ])
      let median_x = map_x(scale, left, plot_width, stat.median())
      let lower_x = map_x(scale, left, plot_width, stat.lower_whisker())
      let upper_x = map_x(scale, left, plot_width, stat.upper_whisker())
      append_error_segment(
        writer,
        lower_x,
        center_y,
        x1,
        center_y,
        style,
        segments~,
      )
      append_error_segment(
        writer,
        x2,
        center_y,
        upper_x,
        center_y,
        style,
        segments~,
      )
      append_error_segment(writer, median_x, y1, median_x, y2, style, segments~)
      let cap1 = map_y(scale, top, plot_height, position - cap_width / 2.0)
      let cap2 = map_y(scale, top, plot_height, position + cap_width / 2.0)
      append_error_segment(
        writer,
        lower_x,
        cap1,
        lower_x,
        cap2,
        style,
        segments~,
      )
      append_error_segment(
        writer,
        upper_x,
        cap1,
        upper_x,
        cap2,
        style,
        segments~,
      )
      for flier in stat.fliers() {
        if scale.x_axis_scale.is_valid(flier) {
          let flier_x = map_x(scale, left, plot_width, flier)
          try! writer.empty_element("circle", [
            ("cx", float_text(flier_x)),
            ("cy", float_text(center_y)),
            ("r", "3"),
            ("fill", style.color()),
          ])
          if outliers_visible && fliers is Some(captured) {
            captured.push((flier, flier_x, center_y))
          }
        }
      }
      if on_box is Some(collect) {
        collect({
          source_index: index,
          stat,
          position,
          horizontal,
          fill_visible,
          stroke_visible,
          rectangle: (
            Double::min(x1, x2),
            Double::min(y1, y2),
            Double::abs(x2 - x1),
            Double::abs(y2 - y1),
          ),
          segments: segments.unwrap(),
          fliers: fliers.unwrap(),
        })
      }
    } else {
      if !scale.y_axis_scale.is_valid(stat.q1()) ||
        !scale.y_axis_scale.is_valid(stat.q3()) {
        continue
      }
      let center_x = map_x(scale, left, plot_width, position)
      let x1 = map_x(scale, left, plot_width, position - box_width / 2.0)
      let x2 = map_x(scale, left, plot_width, position + box_width / 2.0)
      let y1 = map_y(scale, top, plot_height, stat.q1())
      let y2 = map_y(scale, top, plot_height, stat.q3())
      try! writer.empty_element("rect", [
        ("x", float_text(Double::min(x1, x2))),
        ("y", float_text(Double::min(y1, y2))),
        ("width", float_text(Double::abs(x2 - x1))),
        ("height", float_text(Double::abs(y2 - y1))),
        ("fill", fill),
        ("fill-opacity", "0.35"),
        ("stroke", style.color()),
        ("stroke-width", float_text(style.width())),
      ])
      let median_y = map_y(scale, top, plot_height, stat.median())
      let lower_y = map_y(scale, top, plot_height, stat.lower_whisker())
      let upper_y = map_y(scale, top, plot_height, stat.upper_whisker())
      append_error_segment(
        writer,
        center_x,
        lower_y,
        center_x,
        y1,
        style,
        segments~,
      )
      append_error_segment(
        writer,
        center_x,
        y2,
        center_x,
        upper_y,
        style,
        segments~,
      )
      append_error_segment(writer, x1, median_y, x2, median_y, style, segments~)
      let cap1 = map_x(scale, left, plot_width, position - cap_width / 2.0)
      let cap2 = map_x(scale, left, plot_width, position + cap_width / 2.0)
      append_error_segment(
        writer,
        cap1,
        lower_y,
        cap2,
        lower_y,
        style,
        segments~,
      )
      append_error_segment(
        writer,
        cap1,
        upper_y,
        cap2,
        upper_y,
        style,
        segments~,
      )
      for flier in stat.fliers() {
        if scale.y_axis_scale.is_valid(flier) {
          let flier_y = map_y(scale, top, plot_height, flier)
          try! writer.empty_element("circle", [
            ("cx", float_text(center_x)),
            ("cy", float_text(flier_y)),
            ("r", "3"),
            ("fill", style.color()),
          ])
          if outliers_visible && fliers is Some(captured) {
            captured.push((flier, center_x, flier_y))
          }
        }
      }
      if on_box is Some(collect) {
        collect({
          source_index: index,
          stat,
          position,
          horizontal,
          fill_visible,
          stroke_visible,
          rectangle: (
            Double::min(x1, x2),
            Double::min(y1, y2),
            Double::abs(x2 - x1),
            Double::abs(y2 - y1),
          ),
          segments: segments.unwrap(),
          fliers: fliers.unwrap(),
        })
      }
    }
  }
}
