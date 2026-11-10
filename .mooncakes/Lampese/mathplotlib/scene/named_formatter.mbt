///|
/// Install the same live formatter on the shared x group, owned by this axes.
pub fn Axes::set_x_named_formatter(
  self : Axes,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  for state in self.x_group_states() {
    state.val.x_axis.set_named_formatter(formatter)
  }
  self.state.val.x_axis.bind_formatter_axis()
}

///|
pub fn Axes::set_y_named_formatter(
  self : Axes,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  for state in self.y_group_states() {
    state.val.y_axis.set_named_formatter(formatter)
  }
  self.state.val.y_axis.bind_formatter_axis()
}

///|
pub fn Axes::set_x_minor_named_formatter(
  self : Axes,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  for state in self.x_group_states() {
    state.val.x_axis.set_minor_named_formatter(formatter)
  }
  self.state.val.x_axis.bind_formatter_axis(minor=true)
}

///|
pub fn Axes::set_y_minor_named_formatter(
  self : Axes,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  for state in self.y_group_states() {
    state.val.y_axis.set_minor_named_formatter(formatter)
  }
  self.state.val.y_axis.bind_formatter_axis(minor=true)
}

///|
pub fn Figure::set_x_named_formatter(
  self : Figure,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.axes().set_x_named_formatter(formatter)
}

///|
pub fn Figure::set_y_named_formatter(
  self : Figure,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.axes().set_y_named_formatter(formatter)
}

///|
pub fn Figure::set_x_minor_named_formatter(
  self : Figure,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.axes().set_x_minor_named_formatter(formatter)
}

///|
pub fn Figure::set_y_minor_named_formatter(
  self : Figure,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.axes().set_y_minor_named_formatter(formatter)
}
