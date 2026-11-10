///|
/// Add a line plot from paired masked arrays to the current axes.
pub fn plot_masked(
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().plot_masked(xs, ys, color~, label~)
}

///|
/// Draw a masked scalar mesh on the current axes.
pub fn pcolor_masked(
  data : @core.MaskedMatrix,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolor_masked(
        data,
        x~,
        y~,
        vmin~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (Some(vmin), None) =>
      require_axes().pcolor_masked(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      require_axes().pcolor_masked(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) =>
      require_axes().pcolor_masked(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a masked scalar mesh with explicit normalization and colormap objects.
pub fn pcolor_masked_with_norm_and_colormap(
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  require_axes().pcolor_masked_with_norm_and_colormap(
    data,
    norm,
    cmap,
    x~,
    y~,
    antialiased~,
  )
}

///|
/// Draw a masked rectangular scalar mesh on the current axes.
pub fn pcolormesh_masked(
  data : @core.MaskedMatrix,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolormesh_masked(
        data,
        x~,
        y~,
        vmin~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (Some(vmin), None) =>
      require_axes().pcolormesh_masked(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      require_axes().pcolormesh_masked(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) =>
      require_axes().pcolormesh_masked(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a masked rectangular mesh with explicit normalization and colormap.
pub fn pcolormesh_masked_with_norm_and_colormap(
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  require_axes().pcolormesh_masked_with_norm_and_colormap(
    data,
    norm,
    cmap,
    x~,
    y~,
    antialiased~,
  )
}

///|
/// Fill between masked x series at y positions on the current axes.
pub fn fill_betweenx_masked(
  ys : @core.MaskedArray,
  left : @core.MaskedArray,
  right : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().fill_betweenx_masked(ys, left, right, color~, label~)
}

///|
/// Add a masked scalar image to the current axes.
pub fn imshow_masked(
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
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().imshow_masked(
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
      require_axes().imshow_masked(
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
      require_axes().imshow_masked(
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
      require_axes().imshow_masked(
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
/// Add a masked scalar image using a custom colormap object.
pub fn imshow_masked_with_colormap(
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
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().imshow_masked_with_colormap(
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
      require_axes().imshow_masked_with_colormap(
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
      require_axes().imshow_masked_with_colormap(
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
      require_axes().imshow_masked_with_colormap(
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
/// Add a masked scalar image with an explicit normalization.
pub fn imshow_masked_with_norm(
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_masked_with_norm(
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
/// Add a masked scalar image with explicit normalization and colormap objects.
pub fn imshow_masked_with_norm_and_colormap(
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  require_axes().imshow_masked_with_norm_and_colormap(
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
/// Add scatter points from paired masked arrays to the current axes.
pub fn scatter_masked(
  xs : @core.MaskedArray,
  ys : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().scatter_masked(xs, ys, color~, label~)
}

///|
/// Fill between masked lower and upper arrays on the current axes.
pub fn fill_between_masked(
  xs : @core.MaskedArray,
  lower : @core.MaskedArray,
  upper : @core.MaskedArray,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().fill_between_masked(xs, lower, upper, color~, label~)
}
