///|
/// Update x units from explicit naive/aware dates without adding an artist.
pub fn Axes::update_x_date_units(
  self : Axes,
  values : Array[@date.RRuleDateTime],
) -> Bool raise @core.DataError {
  self.state.val.x_axis.update_date_units(values)
}

///|
pub fn Axes::update_y_date_units(
  self : Axes,
  values : Array[@date.RRuleDateTime],
) -> Bool raise @core.DataError {
  self.state.val.y_axis.update_date_units(values)
}

///|
pub fn Axes::update_x_category_units(
  self : Axes,
  values : Array[String],
) -> Bool raise @core.DataError {
  self.state.val.x_axis.update_category_units(values)
}

///|
pub fn Axes::update_y_category_units(
  self : Axes,
  values : Array[String],
) -> Bool raise @core.DataError {
  self.state.val.y_axis.update_category_units(values)
}

///|
/// Change units with original shared-axis mutation and callback ordering.
pub fn Axes::set_x_units(
  self : Axes,
  unit : @axis.AxisUnitTag?,
) -> Unit raise @core.DataError {
  self.state.val.x_axis.set_unit_tag(unit)
}

///|
pub fn Axes::set_y_units(
  self : Axes,
  unit : @axis.AxisUnitTag?,
) -> Unit raise @core.DataError {
  self.state.val.y_axis.set_unit_tag(unit)
}

///|
pub fn Axes::x_units(self : Axes) -> @axis.AxisUnitTag? {
  self.state.val.x_axis.unit_tag()
}

///|
pub fn Axes::y_units(self : Axes) -> @axis.AxisUnitTag? {
  self.state.val.y_axis.unit_tag()
}

///|
/// Plot dates while retaining the distinction between naive and aware inputs.
/// Empty ordinary arrays do not choose a registry converter.
pub fn Axes::plot_date_units(
  self : Axes,
  dates : Array[@date.RRuleDateTime],
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
  if !self.state.val.x_axis.have_units() {
    ignore(self.update_x_date_units(dates))
  }
  let ordinals = self.state.val.x_axis.convert_date_units(dates)
  let points = @core.series(ordinals, values).points()
  self.attach_line_with_originals(
    points,
    LineData::Date(dates),
    LineData::Numeric(values),
    color~,
    label~,
  )
}

///|
pub fn Figure::plot_date_units(
  self : Figure,
  dates : Array[@date.RRuleDateTime],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().plot_date_units(dates, values, color~, label~)
}
