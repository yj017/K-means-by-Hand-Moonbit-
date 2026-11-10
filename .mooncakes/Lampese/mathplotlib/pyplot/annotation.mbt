///|
/// Add text at a data point, optionally connected by an arrow.
pub fn annotate(
  value : String,
  x : Double,
  y : Double,
  offset_x~ : Double = 0.0,
  offset_y~ : Double = 0.0,
  arrow~ : Bool = false,
  color~ : String = "#111827",
  arrowcolor~ : String = "",
  linewidth~ : Double = 1.0,
  head_length~ : Double = 0.15,
  head_width~ : Double = 0.10,
  fontsize~ : Int32 = 12,
  xycoords~ : String = "data",
  textcoords~ : String = "data",
  connector~ : String = "straight",
) -> Unit raise @core.DataError {
  require_axes().annotate(
    value,
    x,
    y,
    offset_x~,
    offset_y~,
    arrow~,
    color~,
    arrowcolor~,
    linewidth~,
    head_length~,
    head_width~,
    fontsize~,
    xycoords~,
    textcoords~,
    connector~,
  )
}

///|
/// Add text at a data coordinate on the current figure.
pub fn text(
  x : Double,
  y : Double,
  value : String,
  color~ : String = "#111827",
) -> Unit raise @core.DataError {
  require_axes().text(x, y, value, color~)
}
