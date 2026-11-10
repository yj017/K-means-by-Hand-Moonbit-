///|
/// Install default date conversion and label configuration on the current x axis.
pub fn xaxis_date_converter(
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  require_axes().set_x_date_converter(converter)
}

///|
/// Install default date conversion and label configuration on the current y axis.
pub fn yaxis_date_converter(
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  require_axes().set_y_date_converter(converter)
}
