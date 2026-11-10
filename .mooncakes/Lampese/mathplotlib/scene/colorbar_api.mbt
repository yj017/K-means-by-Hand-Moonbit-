///|
/// Add a scalar colorbar to this figure.
pub fn Figure::colorbar(
  self : Figure,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  orientation~ : @colorbar.Orientation = @colorbar.Orientation::Vertical,
) -> @colorbar.Colorbar {
  let result = @colorbar.colorbar(norm, cmap, orientation~)
  self.colorbars.push(result)
  result
}

///|
/// Return colorbars in insertion order.
pub fn Figure::colorbars(self : Figure) -> Array[@colorbar.Colorbar] {
  self.colorbars.copy()
}
