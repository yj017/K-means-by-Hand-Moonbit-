///|
// Original imshow runs set_extent before attaching the image. A checked limit
// failure retains updated dataLim but leaves the children and pending flags as
// they stood before imshow; successful extent setters consume selected requests.
fn Axes::attach_image_checked(
  self : Axes,
  artist : Artist,
  rows : Int32,
  columns : Int32,
  origin : ImageOrigin,
  extent : (Double, Double, Double, Double)?,
) -> Unit raise @core.DataError {
  self.update_artist_data_limits(artist)
  self.fit_image_dimensions(rows, columns, origin, extent)
  self.state.val.artists.push(artist)
}

///|
/// Apply image bounds to every axes in the corresponding shared-axis groups.
/// The helper is dimension based so scalar and already-colored images share
/// exactly the same half-pixel and origin semantics.
fn Axes::fit_image_dimensions(
  self : Axes,
  rows : Int32,
  columns : Int32,
  origin : ImageOrigin,
  extent : (Double, Double, Double, Double)?,
) -> Unit raise @core.DataError {
  let (left, right, bottom, top) = match extent {
    Some(bounds) => bounds
    None => {
      let right = Double::from_int(columns) - 0.5
      let last_row = Double::from_int(rows) - 0.5
      match origin {
        Upper => (-0.5, right, last_row, -0.5)
        Lower => (-0.5, right, -0.5, last_row)
      }
    }
  }
  if self.state.val.x_axis.autoscale_on() {
    self.set_coordinate_limits_checked(left, right, true, None)
  }
  if self.state.val.y_axis.autoscale_on() {
    self.set_coordinate_limits_checked(bottom, top, false, None)
  }
}
