///|
fn spine_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn append_spine(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  spine : @render.Spine,
) -> Unit {
  if !spine.visible() {
    return
  }
  let (x1, y1, x2, y2) = match spine.side() {
    @render.SpineSide::Left => {
      let x = match spine.position() {
        @render.SpinePosition::Axes => left
        @render.SpinePosition::Data(value) =>
          map_x(scale, left, plot_width, value)
        @render.SpinePosition::Outward(value) => left - value
      }
      let (lower, upper) = match spine.bounds() {
        Some((lower, upper)) =>
          (
            map_y(scale, top, plot_height, lower),
            map_y(scale, top, plot_height, upper),
          )
        None => (top + plot_height, top)
      }
      (x, lower, x, upper)
    }
    @render.SpineSide::Right => {
      let x = match spine.position() {
        @render.SpinePosition::Axes => left + plot_width
        @render.SpinePosition::Data(value) =>
          map_x(scale, left, plot_width, value)
        @render.SpinePosition::Outward(value) => left + plot_width + value
      }
      let (lower, upper) = match spine.bounds() {
        Some((lower, upper)) =>
          (
            map_y(scale, top, plot_height, lower),
            map_y(scale, top, plot_height, upper),
          )
        None => (top + plot_height, top)
      }
      (x, lower, x, upper)
    }
    @render.SpineSide::Bottom => {
      let y = match spine.position() {
        @render.SpinePosition::Axes => top + plot_height
        @render.SpinePosition::Data(value) =>
          map_y(scale, top, plot_height, value)
        @render.SpinePosition::Outward(value) => top + plot_height + value
      }
      let (lower, upper) = match spine.bounds() {
        Some((lower, upper)) =>
          (
            map_x(scale, left, plot_width, lower),
            map_x(scale, left, plot_width, upper),
          )
        None => (left, left + plot_width)
      }
      (lower, y, upper, y)
    }
    @render.SpineSide::Top => {
      let y = match spine.position() {
        @render.SpinePosition::Axes => top
        @render.SpinePosition::Data(value) =>
          map_y(scale, top, plot_height, value)
        @render.SpinePosition::Outward(value) => top - value
      }
      let (lower, upper) = match spine.bounds() {
        Some((lower, upper)) =>
          (
            map_x(scale, left, plot_width, lower),
            map_x(scale, left, plot_width, upper),
          )
        None => (left, left + plot_width)
      }
      (lower, y, upper, y)
    }
  }
  if spine_finite(x1) &&
    spine_finite(y1) &&
    spine_finite(x2) &&
    spine_finite(y2) {
    try! writer.empty_element("line", [
      ("x1", float_text(x1)),
      ("y1", float_text(y1)),
      ("x2", float_text(x2)),
      ("y2", float_text(y2)),
      ("stroke", spine.color()),
      ("stroke-width", float_text(spine.linewidth())),
    ])
  }
}

///|
fn append_axes(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  spines : Array[@render.Spine],
) -> Unit {
  if spines.length() == 0 {
    try! writer.empty_element("rect", [
      ("x", float_text(left)),
      ("y", float_text(top)),
      ("width", float_text(plot_width)),
      ("height", float_text(plot_height)),
      ("fill", "none"),
      ("stroke", "#374151"),
      ("stroke-width", "1.2"),
    ])
  } else {
    for spine in spines {
      append_spine(writer, scale, left, top, plot_width, plot_height, spine)
    }
  }
}
