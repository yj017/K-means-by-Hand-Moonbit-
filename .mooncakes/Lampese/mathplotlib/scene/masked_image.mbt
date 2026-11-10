///|
/// Add a masked scalar image. Explicitly masked cells are converted to NaN and
/// therefore follow the colormap's bad-color/transparent-cell policy.
pub fn Figure::imshow_masked(
  self : Figure,
  data : @core.MaskedMatrix,
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image(
    data.to_array(),
    vmin,
    vmax,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image using a custom colormap object.
pub fn Figure::imshow_masked_with_colormap(
  self : Figure,
  data : @core.MaskedMatrix,
  cmap : @colors.ColorMap,
  vmin? : Double,
  vmax? : Double,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image(
    data.to_array(),
    vmin,
    vmax,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image with an explicit normalization.
pub fn Figure::imshow_masked_with_norm(
  self : Figure,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image_norm(
    data.to_array(),
    norm,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image with explicit normalization and colormap objects.
pub fn Figure::imshow_masked_with_norm_and_colormap(
  self : Figure,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image_norm(
    data.to_array(),
    norm,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image through the axes view.
pub fn Axes::imshow_masked(
  self : Axes,
  data : @core.MaskedMatrix,
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image(
    data.to_array(),
    vmin,
    vmax,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image through the axes view using a custom colormap.
pub fn Axes::imshow_masked_with_colormap(
  self : Axes,
  data : @core.MaskedMatrix,
  cmap : @colors.ColorMap,
  vmin? : Double,
  vmax? : Double,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image(
    data.to_array(),
    vmin,
    vmax,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image through the axes view with explicit normalization.
pub fn Axes::imshow_masked_with_norm(
  self : Axes,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image_norm(
    data.to_array(),
    norm,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a masked scalar image through the axes view with explicit normalization
/// and colormap objects.
pub fn Axes::imshow_masked_with_norm_and_colormap(
  self : Axes,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image_norm(
    data.to_array(),
    norm,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}
