///|
fn default_color_cycle() -> Array[String] {
  @config.color_cycle()
}

///|
/// Select the next color from this axes' property cycle.
fn Axes::resolve_color(self : Axes, requested : String) -> String {
  if requested != "" {
    return requested
  }
  let cycle = self.state.val.color_cycle
  let index = self.state.val.color_cycle_index % cycle.length()
  let cycle_color = cycle[index]
  self.state.val.color_cycle_index += 1
  cycle_color
}

///|
/// Replace the property color cycle used when a plot omits `color`.
pub fn Axes::set_color_cycle(
  self : Axes,
  colors : Array[String],
) -> Unit raise @core.DataError {
  if colors.length() == 0 {
    raise @core.DataError::InvalidTicks(
      message="color cycle must contain at least one color",
    )
  }
  for color in colors {
    if color.length() == 0 {
      raise @core.DataError::InvalidTicks(
        message="color cycle entries must not be empty",
      )
    }
  }
  self.state.val.color_cycle.clear()
  for color in colors {
    self.state.val.color_cycle.push(color)
  }
  self.state.val.color_cycle_index = 0
}

///|
/// Matplotlib-style spelling for replacing the property cycle.
pub fn Axes::set_prop_cycle(
  self : Axes,
  colors : Array[String],
) -> Unit raise @core.DataError {
  self.set_color_cycle(colors)
}

///|
/// Return a copy of the current property color cycle.
pub fn Axes::color_cycle(self : Axes) -> Array[String] {
  self.state.val.color_cycle.copy()
}

///|
/// Replace the property color cycle on the default axes panel.
pub fn Figure::set_color_cycle(
  self : Figure,
  colors : Array[String],
) -> Unit raise @core.DataError {
  self.axes().set_color_cycle(colors)
}

///|
/// Matplotlib-style spelling for replacing the property cycle.
pub fn Figure::set_prop_cycle(
  self : Figure,
  colors : Array[String],
) -> Unit raise @core.DataError {
  self.set_color_cycle(colors)
}

///|
/// Return the default axes panel's property color cycle.
pub fn Figure::color_cycle(self : Figure) -> Array[String] {
  self.axes().color_cycle()
}
