///|
fn validate_date_formatter_axis(
  axis : @axis.Axis,
) -> Unit raise @core.DataError {
  if axis.scale().is_nonlinear() {
    raise @core.DataError::InvalidTicks(
      message="date axis cannot be combined with a non-linear scale",
    )
  }
  if axis.categories() is Some(_) {
    raise @core.DataError::InvalidTicks(
      message="date axis cannot be combined with category data",
    )
  }
}

///|
/// Set a copied date formatter on every axes sharing this x coordinate.
/// ConciseDateFormatter::as_formatter supplies batch labels and shared date text.
pub fn Axes::set_x_date_formatter(
  self : Axes,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  let states = self.x_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.x_axis)
    state.val.x_axis.validate_date_converter()
  }
  for state in states {
    state.val.x_axis.set_date_formatter(formatter)
  }
}

///|
/// Set a copied date formatter on every axes sharing this y coordinate.
pub fn Axes::set_y_date_formatter(
  self : Axes,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  let states = self.y_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.y_axis)
    state.val.y_axis.validate_date_converter()
  }
  for state in states {
    state.val.y_axis.set_date_formatter(formatter)
  }
}

///|
/// Set a date formatter on the default x axis, including shared axes.
pub fn Figure::set_x_date_formatter(
  self : Figure,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  self.axes().set_x_date_formatter(formatter)
}

///|
/// Set a date formatter on the default y axis, including shared axes.
pub fn Figure::set_y_date_formatter(
  self : Figure,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  self.axes().set_y_date_formatter(formatter)
}
