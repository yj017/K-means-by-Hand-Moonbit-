///|
fn panel_rect(
  figure : @render.Figure,
  panel : @render.Panel,
) -> (Double, Double, Double, Double) {
  match panel.rect() {
    Some(rect) => (rect.x(), rect.y(), rect.width(), rect.height())
    None =>
      (
        Double::from_int(figure.margin()),
        Double::from_int(figure.margin()),
        Double::from_int(figure.width() - figure.margin() * 2),
        Double::from_int(figure.height() - figure.margin() * 2),
      )
  }
}

///|
fn anchored_panel_rect(
  rect : (Double, Double, Double, Double),
  width : Double,
  height : Double,
  anchor : (Double, Double),
) -> (Double, Double, Double, Double) {
  (
    rect.0 + (rect.2 - width) * anchor.0,
    rect.1 + (rect.3 - height) * (1.0 - anchor.1),
    width,
    height,
  )
}

///|
fn box_aspect_panel_rect(
  figure : @render.Figure,
  panel : @render.Panel,
) -> (Double, Double, Double, Double) {
  let raw = panel_rect(figure, panel)
  guard panel.adjustable() == "datalim" && panel.box_aspect() is Some(aspect) else {
    return raw
  }
  let height = raw.2 * aspect
  if height <= raw.3 {
    anchored_panel_rect(raw, raw.2, height, panel.anchor())
  } else {
    anchored_panel_rect(raw, raw.3 / aspect, raw.3, panel.anchor())
  }
}

///|
fn data_aspect_rect(
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  aspect : Double,
  anchor : (Double, Double),
) -> (Double, Double, Double, Double) {
  // Match Axes.get_data_ratio's floor for very small transformed intervals.
  let x_span = Double::max(
    Double::abs(
      scale.x_axis_scale.transform(scale.xmax) -
      scale.x_axis_scale.transform(scale.xmin),
    ),
    1.0e-30,
  )
  let y_span = Double::max(
    Double::abs(
      scale.y_axis_scale.transform(scale.ymax) -
      scale.y_axis_scale.transform(scale.ymin),
    ),
    1.0e-30,
  )
  if aspect <= 0.0 || aspect.is_nan() || aspect.is_inf() {
    (left, top, plot_width, plot_height)
  } else {
    let x_units = plot_width / x_span
    let y_units = plot_height / y_span / aspect
    if x_units > y_units {
      let width = y_units * x_span
      anchored_panel_rect(
        (left, top, plot_width, plot_height),
        width,
        plot_height,
        anchor,
      )
    } else {
      let height = x_units * aspect * y_span
      anchored_panel_rect(
        (left, top, plot_width, plot_height),
        plot_width,
        height,
        anchor,
      )
    }
  }
}

///|
fn positioned_panel_rect(
  figure : @render.Figure,
  panel : @render.Panel,
  scale : Scale,
) -> (Double, Double, Double, Double) {
  if panel.polar() is Some(_) {
    return polar_panel_rect(figure, panel)
  }
  let (raw_left, raw_top, raw_width, raw_height) = panel_rect(figure, panel)
  if panel.adjustable() == "datalim" {
    return box_aspect_panel_rect(figure, panel)
  }
  match panel.aspect() {
    Some(aspect) =>
      data_aspect_rect(
        scale,
        raw_left,
        raw_top,
        raw_width,
        raw_height,
        aspect,
        panel.anchor(),
      )
    None => (raw_left, raw_top, raw_width, raw_height)
  }
}

///|
/// Resolve a panel's active display rectangle using the same ranges and
/// aspect/anchor calculation as SVG rendering. Invalid panel indices return None.
/// Aspect resolution failures also return None; panel_view preserves DataError.
/// The tuple is (left, top, width, height) in pixels from the top left.
///
/// ```mbt check
/// test {
///   let x_axis = @axis.axis()
///   let y_axis = @axis.axis()
///   x_axis.set_limits(0.0, 1.0)
///   y_axis.set_limits(0.0, 1.0)
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     x_axis,
///     y_axis,
///     true,
///     [],
///     [],
///   )
///   let figure = @render.figure(400, 200, 50, [panel], [], None)
///   assert_eq(@svg.panel_position(figure, 0), Some((150.0, 50.0, 100.0, 100.0)))
///   assert_true(@svg.panel_position(figure, 1) is None)
/// }
/// ```
pub fn panel_position(
  figure : @render.Figure,
  panel_index : Int32,
) -> (Double, Double, Double, Double)? {
  try panel_view(figure, panel_index) catch {
    _ => None
  } noraise {
    Some((position, _, _)) => Some(position)
    None => None
  }
}
