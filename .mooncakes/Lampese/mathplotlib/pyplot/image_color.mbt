///|
/// Add a typed RGBA image to the current axes.
pub fn imshow_rgba(
  data : Array[Array[@colors.Rgba]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_rgba(
    data,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a typed opaque RGB image to the current axes.
pub fn imshow_rgb(
  data : Array[Array[@colors.Rgb]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_rgb(
    data,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add an RGBA image from raw normalized four-channel pixels.
pub fn imshow_rgba_channels(
  data : Array[Array[Array[Double]]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_rgba_channels(
    data,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add an RGB image from raw normalized three-channel pixels.
pub fn imshow_rgb_channels(
  data : Array[Array[Array[Double]]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_rgb_channels(
    data,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Alias for the typed RGBA image entry point.
pub fn imshow_color(
  data : Array[Array[@colors.Rgba]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_color(
    data,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}
