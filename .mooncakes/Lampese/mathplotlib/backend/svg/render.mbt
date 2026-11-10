///|
/// Encode a scene figure as a self-contained SVG document.
pub fn render(figure : @render.Figure) -> String {
  render_with_positions(figure).0
}

///|
/// Encode SVG and return the active display rectangles used to draw it.
/// Rectangles are (left, top, width, height) in pixels, in panel order.
/// Scene handles use these results to retain their last drawn positions.
///
/// ```mbt check
/// test {
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     @axis.axis(),
///     @axis.axis(),
///     false,
///     [],
///     [],
///   )
///   let figure = @render.figure(400, 200, 50, [panel], [], None)
///   let (svg, positions) = @svg.render_with_positions(figure)
///   assert_eq(svg, @svg.render(figure))
///   assert_eq(positions, [(50.0, 50.0, 300.0, 100.0)])
///   assert_eq(@svg.panel_position(figure, 0), Some(positions[0]))
/// }
/// ```
pub fn render_with_positions(
  figure : @render.Figure,
) -> (String, Array[(Double, Double, Double, Double)]) {
  try! render_with_positions_checked(figure)
}

///|
/// Render while preserving checked locator and range errors.
pub fn render_with_positions_checked(
  figure : @render.Figure,
) -> (String, Array[(Double, Double, Double, Double)]) raise @core.DataError {
  render_with_hits_checked(figure, None)
}

///|
fn render_with_hits_checked(
  figure : @render.Figure,
  capture : DrawingCapture?,
) -> (String, Array[(Double, Double, Double, Double)]) raise @core.DataError {
  begin_tick_layout(figure)
  defer end_tick_layout(figure)
  let writer = @xml.Writer::new()
  let scales = compute_scales(figure)
  let positions = Array(capacity=figure.panels().length())
  for index, panel in figure.panels() {
    let position = positioned_panel_rect(figure, panel, scales[index])
    positions.push(position)
    if panel.polar() is Some(_) {
      continue
    }
    panel
    .x_axis()
    .set_tick_layout(position.2, true, active=true, origin=position.0)
    panel
    .y_axis()
    .set_tick_layout(
      position.3,
      false,
      active=true,
      origin=figure.height().to_double() - position.1 - position.3,
    )
    panel.x_axis().set_tick_view(scales[index].xmin, scales[index].xmax)
    panel.y_axis().set_tick_view(scales[index].ymin, scales[index].ymax)
  }
  for index, panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    let (left, top, width, height) = positions[index]
    for (_, _, axis, _) in ordered_secondary_axes(panel) {
      if !axis.positioned_aspect(left, top, width, height) {
        ignore(axis.synchronize_view())
      }
    }
  }
  try! writer.start_element("svg", [
    ("xmlns", "http://www.w3.org/2000/svg"),
    ("width", figure.width().to_string()),
    ("height", figure.height().to_string()),
    ("viewBox", "0 0 \{figure.width()} \{figure.height()}"),
  ])
  try! writer.empty_element("rect", [
    ("width", "100%"),
    ("height", "100%"),
    ("fill", "white"),
  ])
  for index, panel in figure.panels() {
    render_panel(
      writer,
      figure,
      panel,
      scales[index],
      index,
      positions[index],
      capture~,
    )
  }
  for index, bar in figure.colorbars() {
    append_colorbar(writer, figure, bar, index)
  }
  for subfigure in figure.subfigures() {
    let rect = subfigure.rect()
    match subfigure.title() {
      Some(value) =>
        append_text(
          writer,
          rect.x() + rect.width() / 2.0,
          rect.y() + 18.0,
          value,
          "middle",
          16,
        )
      None => ()
    }
  }
  match figure.title() {
    Some(value) =>
      append_text(
        writer,
        Double::from_int(figure.width()) / 2.0,
        28.0,
        value,
        "middle",
        18,
      )
    None => ()
  }
  try! writer.end_element("svg")
  (try! writer.to_string(), positions)
}
