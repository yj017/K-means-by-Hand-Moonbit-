///|
fn append_legend(
  writer : @xml.Writer,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  entries : Array[@render.LegendEntry],
  position : @render.LegendPosition,
  on_box~ : (((Double, Double, Double, Double)) -> Unit)? = None,
) -> Unit {
  if entries.length() == 0 {
    return
  }
  let box_width = 152.0
  let box_height = 12.0 + Double::from_int(entries.length()) * 20.0
  let box_x = match position {
    @render.LegendPosition::UpperRight | @render.LegendPosition::LowerRight =>
      left + plot_width - box_width - 8.0
    @render.LegendPosition::UpperLeft | @render.LegendPosition::LowerLeft =>
      left + 8.0
  }
  let box_y = match position {
    @render.LegendPosition::UpperRight | @render.LegendPosition::UpperLeft =>
      top + 8.0
    @render.LegendPosition::LowerRight | @render.LegendPosition::LowerLeft =>
      top + plot_height - box_height - 8.0
  }
  try! writer.empty_element("rect", [
    ("x", float_text(box_x)),
    ("y", float_text(box_y)),
    ("width", float_text(box_width)),
    ("height", float_text(box_height)),
    ("fill", "white"),
    ("fill-opacity", "0.85"),
    ("stroke", "#9ca3af"),
    ("stroke-width", "1"),
  ])
  if on_box is Some(capture) {
    capture((box_x, box_y, box_width, box_height))
  }
  for i in 0..<entries.length() {
    let entry = entries[i]
    let y = box_y + 20.0 + Double::from_int(i) * 20.0
    let sample_x = box_x + 10.0
    match entry.kind() {
      @render.LegendKind::Line =>
        try! writer.empty_element("line", [
          ("x1", float_text(sample_x)),
          ("y1", float_text(y - 4.0)),
          ("x2", float_text(sample_x + 22.0)),
          ("y2", float_text(y - 4.0)),
          ("stroke", entry.color()),
          ("stroke-width", "2"),
        ])
      @render.LegendKind::Marker =>
        try! writer.empty_element("circle", [
          ("cx", float_text(sample_x + 11.0)),
          ("cy", float_text(y - 4.0)),
          ("r", "4"),
          ("fill", entry.color()),
        ])
      @render.LegendKind::Patch =>
        try! writer.empty_element("rect", [
          ("x", float_text(sample_x)),
          ("y", float_text(y - 12.0)),
          ("width", "22"),
          ("height", "12"),
          ("fill", entry.color()),
        ])
    }
    append_text(writer, sample_x + 32.0, y, entry.label(), "start", 11)
  }
}
