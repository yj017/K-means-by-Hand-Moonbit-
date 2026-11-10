///|
/// Draw scalar values as filled quadrilaterals on the current axes.
pub fn pcolor(
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolor(data, x~, y~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      require_axes().pcolor(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      require_axes().pcolor(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) => require_axes().pcolor(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a rectangular scalar mesh on the current axes.
pub fn pcolormesh(
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolormesh(data, x~, y~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      require_axes().pcolormesh(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      require_axes().pcolormesh(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) => require_axes().pcolormesh(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a scalar mesh on a two-dimensional coordinate grid.
pub fn pcolor_grid(
  data : Array[Array[Double]],
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolor_grid(
        data,
        x,
        y,
        shading~,
        vmin~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (Some(vmin), None) =>
      require_axes().pcolor_grid(
        data,
        x,
        y,
        shading~,
        vmin~,
        cmap~,
        antialiased~,
      )
    (None, Some(vmax)) =>
      require_axes().pcolor_grid(
        data,
        x,
        y,
        shading~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (None, None) =>
      require_axes().pcolor_grid(data, x, y, shading~, cmap~, antialiased~)
  }
}

///|
/// Draw a fast scalar mesh on a two-dimensional coordinate grid.
pub fn pcolormesh_grid(
  data : Array[Array[Double]],
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolormesh_grid(
        data,
        x,
        y,
        shading~,
        vmin~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (Some(vmin), None) =>
      require_axes().pcolormesh_grid(
        data,
        x,
        y,
        shading~,
        vmin~,
        cmap~,
        antialiased~,
      )
    (None, Some(vmax)) =>
      require_axes().pcolormesh_grid(
        data,
        x,
        y,
        shading~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (None, None) =>
      require_axes().pcolormesh_grid(data, x, y, shading~, cmap~, antialiased~)
  }
}

///|
/// Draw a masked scalar mesh on a two-dimensional coordinate grid.
pub fn pcolor_grid_masked(
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolor_grid_masked(
        data,
        x,
        y,
        shading~,
        vmin~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (Some(vmin), None) =>
      require_axes().pcolor_grid_masked(
        data,
        x,
        y,
        shading~,
        vmin~,
        cmap~,
        antialiased~,
      )
    (None, Some(vmax)) =>
      require_axes().pcolor_grid_masked(
        data,
        x,
        y,
        shading~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (None, None) =>
      require_axes().pcolor_grid_masked(
        data,
        x,
        y,
        shading~,
        cmap~,
        antialiased~,
      )
  }
}

///|
/// Draw a fast masked scalar mesh on a two-dimensional coordinate grid.
pub fn pcolormesh_grid_masked(
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().pcolormesh_grid_masked(
        data,
        x,
        y,
        shading~,
        vmin~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (Some(vmin), None) =>
      require_axes().pcolormesh_grid_masked(
        data,
        x,
        y,
        shading~,
        vmin~,
        cmap~,
        antialiased~,
      )
    (None, Some(vmax)) =>
      require_axes().pcolormesh_grid_masked(
        data,
        x,
        y,
        shading~,
        vmax~,
        cmap~,
        antialiased~,
      )
    (None, None) =>
      require_axes().pcolormesh_grid_masked(
        data,
        x,
        y,
        shading~,
        cmap~,
        antialiased~,
      )
  }
}

///|
/// Draw a scalar mesh with explicit normalization and named colormap.
pub fn pcolor_with_norm(
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  require_axes().pcolor_with_norm(data, norm, cmap~, x~, y~, antialiased~)
}

///|
/// Draw a fast scalar mesh with explicit normalization and named colormap.
pub fn pcolormesh_with_norm(
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  require_axes().pcolormesh_with_norm(data, norm, cmap~, x~, y~, antialiased~)
}

///|
/// Draw a scalar mesh with an explicit normalization and colormap object.
pub fn pcolor_with_norm_and_colormap(
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  require_axes().pcolor_with_norm_and_colormap(
    data,
    norm,
    cmap,
    x~,
    y~,
    antialiased~,
  )
}

///|
/// Draw a rectangular scalar mesh with an explicit normalization and colormap.
pub fn pcolormesh_with_norm_and_colormap(
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  require_axes().pcolormesh_with_norm_and_colormap(
    data,
    norm,
    cmap,
    x~,
    y~,
    antialiased~,
  )
}
