///|
/// Install copied converter defaults on every axis sharing this x coordinate.
pub fn Axes::set_x_date_converter(
  self : Axes,
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  let states = self.x_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.x_axis)
    state.val.x_axis.validate_date_converter(converter~)
  }
  for state in states {
    state.val.x_axis.set_date_converter(converter)
  }
}

///|
/// Install copied converter defaults on every axis sharing this y coordinate.
pub fn Axes::set_y_date_converter(
  self : Axes,
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  let states = self.y_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.y_axis)
    state.val.y_axis.validate_date_converter(converter~)
  }
  for state in states {
    state.val.y_axis.set_date_converter(converter)
  }
}

///|
pub fn Figure::set_x_date_converter(
  self : Figure,
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  self.axes().set_x_date_converter(converter)
}

///|
pub fn Figure::set_y_date_converter(
  self : Figure,
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  self.axes().set_y_date_converter(converter)
}
