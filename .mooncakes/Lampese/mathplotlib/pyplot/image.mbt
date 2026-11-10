///|
/// Add a scalar image to the current figure.
pub fn imshow(
  data : Array[Array[Double]],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().imshow(
        data,
        vmin~,
        vmax~,
        cmap~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
    (Some(vmin), None) =>
      require_axes().imshow(
        data,
        vmin~,
        cmap~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
    (None, Some(vmax)) =>
      require_axes().imshow(
        data,
        vmax~,
        cmap~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
    (None, None) =>
      require_axes().imshow(
        data,
        cmap~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
  }
}

///|
/// Add a scalar image using a custom or builtin colormap object.
pub fn imshow_with_colormap(
  data : Array[Array[Double]],
  cmap : @colors.ColorMap,
  vmin? : Double,
  vmax? : Double,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().imshow_with_colormap(
        data,
        cmap,
        vmin~,
        vmax~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
    (Some(vmin), None) =>
      require_axes().imshow_with_colormap(
        data,
        cmap,
        vmin~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
    (None, Some(vmax)) =>
      require_axes().imshow_with_colormap(
        data,
        cmap,
        vmax~,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
    (None, None) =>
      require_axes().imshow_with_colormap(
        data,
        cmap,
        origin~,
        extent~,
        aspect~,
        alpha~,
        interpolation~,
      )
  }
}

///|
/// Add a scalar image with an explicit linear or logarithmic normalization.
pub fn imshow_with_norm(
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_with_norm(
    data,
    norm,
    cmap~,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image with explicit normalization and colormap objects.
pub fn imshow_with_norm_and_colormap(
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_with_norm_and_colormap(
    data,
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
/// Display a two-dimensional matrix with zero-based index ticks.
pub fn matshow(
  data : Array[Array[Double]],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().matshow(data, vmin~, vmax~, cmap~, interpolation~)
    (Some(vmin), None) =>
      require_axes().matshow(data, vmin~, cmap~, interpolation~)
    (None, Some(vmax)) =>
      require_axes().matshow(data, vmax~, cmap~, interpolation~)
    (None, None) => require_axes().matshow(data, cmap~, interpolation~)
  }
}

///|
/// Add a colorbar for an explicit scalar normalization to the current figure.
pub fn colorbar(
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  orientation~ : @colorbar.Orientation = @colorbar.Orientation::Vertical,
) -> @colorbar.Colorbar raise @core.DataError {
  let color_map = match @colors.find_colormap(cmap) {
    Some(value) => value
    None =>
      raise @core.DataError::InvalidImage(message="unknown colormap: \{cmap}")
  }
  require_figure().colorbar(norm, color_map, orientation~)
}
