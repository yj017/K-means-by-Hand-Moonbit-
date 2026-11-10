///|
/// Draw a scalar mesh, omitting masked and non-finite cells entirely.
pub fn Figure::pcolor_masked(
  self : Figure,
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
      self.axes().pcolor_masked(data, x~, y~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      self.axes().pcolor_masked(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      self.axes().pcolor_masked(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) => self.axes().pcolor_masked(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a masked scalar mesh through the axes view.
pub fn Axes::pcolor_masked(
  self : Axes,
  data : @core.MaskedMatrix,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_mesh(self, data.to_array(), x, y, vmin, vmax, cmap, false, antialiased)
}

///|
/// Draw a masked scalar mesh with an explicit normalization and colormap.
pub fn Figure::pcolor_masked_with_norm_and_colormap(
  self : Figure,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  self
  .axes()
  .pcolor_masked_with_norm_and_colormap(data, norm, cmap, x~, y~, antialiased~)
}

///|
/// Draw a masked scalar mesh through the axes view with explicit objects.
pub fn Axes::pcolor_masked_with_norm_and_colormap(
  self : Axes,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_mesh_with_norm(
    self,
    data.to_array(),
    x,
    y,
    norm,
    cmap,
    false,
    antialiased,
  )
}

///|
/// Draw a masked rectangular scalar mesh.
pub fn Figure::pcolormesh_masked(
  self : Figure,
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
      self
      .axes()
      .pcolormesh_masked(data, x~, y~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      self.axes().pcolormesh_masked(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      self.axes().pcolormesh_masked(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) =>
      self.axes().pcolormesh_masked(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a masked rectangular scalar mesh through the axes view.
pub fn Axes::pcolormesh_masked(
  self : Axes,
  data : @core.MaskedMatrix,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_mesh(self, data.to_array(), x, y, vmin, vmax, cmap, true, antialiased)
}

///|
/// Draw a masked rectangular mesh with explicit normalization and colormap.
pub fn Figure::pcolormesh_masked_with_norm_and_colormap(
  self : Figure,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  self
  .axes()
  .pcolormesh_masked_with_norm_and_colormap(
    data,
    norm,
    cmap,
    x~,
    y~,
    antialiased~,
  )
}

///|
/// Draw a masked rectangular mesh through the axes view with explicit objects.
pub fn Axes::pcolormesh_masked_with_norm_and_colormap(
  self : Axes,
  data : @core.MaskedMatrix,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_mesh_with_norm(self, data.to_array(), x, y, norm, cmap, true, antialiased)
}
