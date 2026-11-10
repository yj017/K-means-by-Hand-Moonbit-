///|
/// Configure the current x minor date locator.
pub fn xaxis_minor_date_locator(
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  require_axes().set_x_minor_date_locator(locator)
}

///|
/// Configure the current x minor date formatter.
pub fn xaxis_minor_date_formatter(
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  require_axes().set_x_minor_date_formatter(formatter)
}

///|
/// Configure the current y minor date locator.
pub fn yaxis_minor_date_locator(
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  require_axes().set_y_minor_date_locator(locator)
}

///|
/// Configure the current y minor date formatter.
pub fn yaxis_minor_date_formatter(
  formatter : @date.DateFormatter,
) -> Unit raise @core.DataError {
  require_axes().set_y_minor_date_formatter(formatter)
}
