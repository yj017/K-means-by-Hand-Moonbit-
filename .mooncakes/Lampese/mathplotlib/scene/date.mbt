///|
/// Configure automatic date ticks on this axes' x axis.
pub fn Axes::xaxis_date(
  self : Axes,
  format~ : String = "",
) -> Unit raise @core.DataError {
  if format == "" {
    self.set_x_date()
  } else {
    self.set_x_date_format(format)
  }
}

///|
/// Configure automatic date ticks on this axes' y axis.
pub fn Axes::yaxis_date(
  self : Axes,
  format~ : String = "",
) -> Unit raise @core.DataError {
  if format == "" {
    self.set_y_date()
  } else {
    self.set_y_date_format(format)
  }
}

///|
/// Set an explicit date format on all axes sharing this x coordinate.
pub fn Axes::set_x_date_format(
  self : Axes,
  format : String,
) -> Unit raise @core.DataError {
  let states = self.x_group_states()
  for state in states {
    state.val.x_axis.validate_date_converter()
  }
  for state in states {
    state.val.x_axis.set_date_format(format)
  }
}

///|
/// Set an explicit date format on all axes sharing this y coordinate.
pub fn Axes::set_y_date_format(
  self : Axes,
  format : String,
) -> Unit raise @core.DataError {
  let states = self.y_group_states()
  for state in states {
    state.val.y_axis.validate_date_converter()
  }
  for state in states {
    state.val.y_axis.set_date_format(format)
  }
}

///|
/// Set the fixed UTC offset for date tick positions and labels on all shared x axes.
///
/// ```mbt check
/// test {
///   let axes = @scene.figure().axes()
///   try! axes.set_x_date_offset(345)
///   assert_eq(axes.x_date_offset(), 345)
/// }
/// ```
pub fn Axes::set_x_date_offset(
  self : Axes,
  offset_minutes : Int32,
) -> Unit raise @core.DataError {
  for state in self.x_group_states() {
    state.val.x_axis.set_date_offset(offset_minutes)
  }
}

///|
/// Set the fixed UTC offset for date tick positions and labels on all shared y axes.
///
/// ```mbt check
/// test {
///   let axes = @scene.figure().axes()
///   try! axes.set_y_date_offset(-210)
///   assert_eq(axes.y_date_offset(), -210)
/// }
/// ```
pub fn Axes::set_y_date_offset(
  self : Axes,
  offset_minutes : Int32,
) -> Unit raise @core.DataError {
  for state in self.y_group_states() {
    state.val.y_axis.set_date_offset(offset_minutes)
  }
}

///|
/// Set a transition-aware timezone for all shared x axes.
pub fn Axes::set_x_date_timezone(
  self : Axes,
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  for state in self.x_group_states() {
    state.val.x_axis.set_date_timezone(timezone)
  }
}

///|
/// Set a transition-aware timezone for all shared y axes.
pub fn Axes::set_y_date_timezone(
  self : Axes,
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  for state in self.y_group_states() {
    state.val.y_axis.set_date_timezone(timezone)
  }
}

///|
/// Return the fixed UTC offset used by this axes' x coordinate.
///
/// ```mbt check
/// test {
///   assert_eq(@scene.figure().axes().x_date_offset(), 0)
/// }
/// ```
pub fn Axes::x_date_offset(self : Axes) -> Int32 {
  self.state.val.x_axis.date_offset_minutes()
}

///|
/// Return the fixed UTC offset used by this axes' y coordinate.
///
/// ```mbt check
/// test {
///   assert_eq(@scene.figure().axes().y_date_offset(), 0)
/// }
/// ```
pub fn Axes::y_date_offset(self : Axes) -> Int32 {
  self.state.val.y_axis.date_offset_minutes()
}

///|
/// Return the transition-aware timezone used by the shared x axes, if any.
pub fn Axes::x_date_timezone(self : Axes) -> @date.DateTimeZone? {
  self.state.val.x_axis.date_timezone()
}

///|
/// Return the transition-aware timezone used by the shared y axes, if any.
pub fn Axes::y_date_timezone(self : Axes) -> @date.DateTimeZone? {
  self.state.val.y_axis.date_timezone()
}

///|
/// Return the explicit x-axis date format, if date mode is enabled.
///
/// ```mbt check
/// test {
///   let axes = @scene.figure().axes()
///   try! axes.set_x_date_format("%Y-%m-%d")
///   assert_eq(axes.x_date_format(), Some("%Y-%m-%d"))
/// }
/// ```
pub fn Axes::x_date_format(self : Axes) -> String? {
  self.state.val.x_axis.date_format()
}

///|
/// Return the explicit y-axis date format, if date mode is enabled.
///
/// ```mbt check
/// test {
///   let axes = @scene.figure().axes()
///   try! axes.set_y_date_format("%H:%M")
///   assert_eq(axes.y_date_format(), Some("%H:%M"))
/// }
/// ```
pub fn Axes::y_date_format(self : Axes) -> String? {
  self.state.val.y_axis.date_format()
}

///|
/// Set automatic date formatting on all axes sharing this x coordinate.
pub fn Axes::set_x_date(self : Axes) -> Unit raise @core.DataError {
  self.set_x_date_format("")
}

///|
/// Set automatic date formatting on all axes sharing this y coordinate.
pub fn Axes::set_y_date(self : Axes) -> Unit raise @core.DataError {
  self.set_y_date_format("")
}

///|
/// Configure an explicit calendar locator on all axes sharing this x coordinate.
pub fn Axes::set_x_date_locator(
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
    state.val.x_axis.set_date_locator(locator)
  }
}

///|
/// Configure an explicit calendar locator on all axes sharing this y coordinate.
pub fn Axes::set_y_date_locator(
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
    state.val.y_axis.set_date_locator(locator)
  }
}

///|
/// Configure date ticks on the default axes' x coordinate.
pub fn Figure::xaxis_date(
  self : Figure,
  format~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().xaxis_date(format~)
}

///|
/// Configure date ticks on the default axes' y coordinate.
pub fn Figure::yaxis_date(
  self : Figure,
  format~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().yaxis_date(format~)
}

///|
/// Configure an explicit calendar locator on the default axes' x coordinate.
pub fn Figure::set_x_date_locator(
  self : Figure,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  self.axes().set_x_date_locator(locator)
}

///|
/// Configure an explicit calendar locator on the default axes' y coordinate.
pub fn Figure::set_y_date_locator(
  self : Figure,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  self.axes().set_y_date_locator(locator)
}

///|
/// Set the fixed UTC offset for date tick positions and labels on the default x axis.
///
/// ```mbt check
/// test {
///   let figure = @scene.figure()
///   try! figure.set_x_date_offset(120)
///   assert_eq(figure.x_axis().date_offset_minutes(), 120)
/// }
/// ```
pub fn Figure::set_x_date_offset(
  self : Figure,
  offset_minutes : Int32,
) -> Unit raise @core.DataError {
  self.axes().set_x_date_offset(offset_minutes)
}

///|
/// Set the fixed UTC offset for date tick positions and labels on the default y axis.
///
/// ```mbt check
/// test {
///   let figure = @scene.figure()
///   try! figure.set_y_date_offset(-480)
///   assert_eq(figure.y_axis().date_offset_minutes(), -480)
/// }
/// ```
pub fn Figure::set_y_date_offset(
  self : Figure,
  offset_minutes : Int32,
) -> Unit raise @core.DataError {
  self.axes().set_y_date_offset(offset_minutes)
}

///|
/// Set a transition-aware timezone for the default x axis.
pub fn Figure::set_x_date_timezone(
  self : Figure,
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  self.axes().set_x_date_timezone(timezone)
}

///|
/// Set a transition-aware timezone for the default y axis.
pub fn Figure::set_y_date_timezone(
  self : Figure,
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  self.axes().set_y_date_timezone(timezone)
}

///|
/// Return the transition-aware timezone used by the default x axis, if any.
pub fn Figure::x_date_timezone(self : Figure) -> @date.DateTimeZone? {
  self.axes().x_date_timezone()
}

///|
/// Return the transition-aware timezone used by the default y axis, if any.
pub fn Figure::y_date_timezone(self : Figure) -> @date.DateTimeZone? {
  self.axes().y_date_timezone()
}

///|
/// Plot date values on the default axes using Matplotlib day ordinals.
pub fn Axes::plot_date(
  self : Axes,
  dates : Array[@date.DateTime],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if dates.length() != values.length() {
    raise @core.DataError::LengthMismatch(
      expected=dates.length(),
      actual=values.length(),
    )
  }
  // DateTime stores aware instants even when no retained rule-zone handle is
  // present; RRuleDateTime carries the separate naive source domain.
  self.plot_date_units(
    dates.map(value => @date.RRuleDateTime::aware(value)),
    values,
    color~,
    label~,
  )
}

///|
/// Plot date values on the default axes.
pub fn Figure::plot_date(
  self : Figure,
  dates : Array[@date.DateTime],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().plot_date(dates, values, color~, label~)
}
