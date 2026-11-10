///|
/// Configure automatic date ticks on the current x axis.
pub fn xaxis_date(format~ : String = "") -> Unit raise @core.DataError {
  require_axes().xaxis_date(format~)
}

///|
/// Configure automatic date ticks on the current y axis.
pub fn yaxis_date(format~ : String = "") -> Unit raise @core.DataError {
  require_axes().yaxis_date(format~)
}

///|
/// Configure an explicit calendar locator on the current x axis.
pub fn xaxis_date_locator(
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  require_axes().set_x_date_locator(locator)
}

///|
/// Configure an explicit calendar locator on the current y axis.
pub fn yaxis_date_locator(
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  require_axes().set_y_date_locator(locator)
}

///|
/// Set the fixed UTC offset used by date ticks and labels on the current x axis.
///
/// ```mbt check
/// test {
///   @pyplot.close()
///   ignore(@pyplot.figure())
///   try! @pyplot.xaxis_date_offset(345)
///   assert_eq(@pyplot.gca().x_date_offset(), 345)
///   @pyplot.close()
/// }
/// ```
pub fn xaxis_date_offset(offset_minutes : Int32) -> Unit raise @core.DataError {
  require_axes().set_x_date_offset(offset_minutes)
}

///|
/// Set the fixed UTC offset used by date ticks and labels on the current y axis.
///
/// ```mbt check
/// test {
///   @pyplot.close()
///   ignore(@pyplot.figure())
///   try! @pyplot.yaxis_date_offset(-480)
///   assert_eq(@pyplot.gca().y_date_offset(), -480)
///   @pyplot.close()
/// }
/// ```
pub fn yaxis_date_offset(offset_minutes : Int32) -> Unit raise @core.DataError {
  require_axes().set_y_date_offset(offset_minutes)
}

///|
/// Set a transition-aware timezone for the current x axis.
pub fn xaxis_date_timezone(
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  require_axes().set_x_date_timezone(timezone)
}

///|
/// Set a transition-aware timezone for the current y axis.
pub fn yaxis_date_timezone(
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  require_axes().set_y_date_timezone(timezone)
}

///|
/// Plot date values on the current axes.
pub fn plot_date(
  dates : Array[@date.DateTime],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().plot_date(dates, values, color~, label~)
}

///|
/// Set a date formatter on the current x axis. Use a concise formatter's
/// as_formatter() to select compact batch labels and shared date text.
pub fn xaxis_date_formatter(
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  require_axes().set_x_date_formatter(formatter)
}

///|
/// Set a date formatter on the current y axis.
pub fn yaxis_date_formatter(
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  require_axes().set_y_date_formatter(formatter)
}
