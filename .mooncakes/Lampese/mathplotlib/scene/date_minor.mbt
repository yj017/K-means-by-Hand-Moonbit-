///|
/// Configure the x minor date locator on all shared axes.
pub fn Axes::set_x_minor_date_locator(
  self : Axes,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  let states = self.x_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.x_axis)
    if state.val.x_axis.date_format() is None {
      state.val.x_axis.validate_date_converter()
    }
  }
  for state in states {
    state.val.x_axis.set_minor_date_locator(locator)
  }
}

///|
/// Configure the default x minor date locator.
pub fn Figure::set_x_minor_date_locator(
  self : Figure,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  self.axes().set_x_minor_date_locator(locator)
}

///|
/// Configure the x minor date formatter on all shared axes.
pub fn Axes::set_x_minor_date_formatter(
  self : Axes,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  let states = self.x_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.x_axis)
    if state.val.x_axis.date_format() is None {
      state.val.x_axis.validate_date_converter()
    }
  }
  for state in states {
    state.val.x_axis.set_minor_date_formatter(formatter)
  }
}

///|
/// Configure the default x minor date formatter.
pub fn Figure::set_x_minor_date_formatter(
  self : Figure,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  self.axes().set_x_minor_date_formatter(formatter)
}

///|
/// Configure the y minor date locator on all shared axes.
pub fn Axes::set_y_minor_date_locator(
  self : Axes,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  let states = self.y_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.y_axis)
    if state.val.y_axis.date_format() is None {
      state.val.y_axis.validate_date_converter()
    }
  }
  for state in states {
    state.val.y_axis.set_minor_date_locator(locator)
  }
}

///|
/// Configure the default y minor date locator.
pub fn Figure::set_y_minor_date_locator(
  self : Figure,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  self.axes().set_y_minor_date_locator(locator)
}

///|
/// Configure the y minor date formatter on all shared axes.
pub fn Axes::set_y_minor_date_formatter(
  self : Axes,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  let states = self.y_group_states()
  for state in states {
    validate_date_formatter_axis(state.val.y_axis)
    if state.val.y_axis.date_format() is None {
      state.val.y_axis.validate_date_converter()
    }
  }
  for state in states {
    state.val.y_axis.set_minor_date_formatter(formatter)
  }
}

///|
/// Configure the default y minor date formatter.
pub fn Figure::set_y_minor_date_formatter(
  self : Figure,
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  self.axes().set_y_minor_date_formatter(formatter)
}
