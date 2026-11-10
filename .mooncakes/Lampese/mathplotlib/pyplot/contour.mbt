///|
/// Add contour lines to the current axes.
pub fn contour(
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  corner_mask~ : Bool = true,
  locator? : @ticker.Locator,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> @scene.ContourSet raise @core.DataError {
  require_axes().contour(
    data,
    x~,
    y~,
    levels~,
    nlevels~,
    color~,
    linewidth~,
    label~,
    corner_mask~,
    locator~,
    colors~,
    linewidths~,
  )
}

///|
/// Add filled contour bands to the current axes.
pub fn contourf(
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  corner_mask~ : Bool = true,
  locator? : @ticker.Locator,
) -> @scene.ContourSet raise @core.DataError {
  require_axes().contourf(
    data,
    x~,
    y~,
    levels~,
    nlevels~,
    colors~,
    cmap~,
    label~,
    extend_mode~,
    corner_mask~,
    locator~,
  )
}

///|
/// Label representative segments in a contour set on the current axes.
pub fn clabel(
  contours : @scene.ContourSet,
  inline~ : Bool = true,
  fontsize~ : Int32 = 10,
  color~ : String = "#111827",
) -> Unit raise @core.DataError {
  require_axes().clabel(contours, inline~, fontsize~, color~)
}
