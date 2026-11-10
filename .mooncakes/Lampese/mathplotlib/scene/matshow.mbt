///|
fn matrix_index_ticks(size : Int32) -> Array[Double] {
  let ticks = Array(capacity=size)
  for index in 0..<size {
    ticks.push(Double::from_int(index))
  }
  ticks
}

///|
fn matrix_index_labels(size : Int32) -> Array[String] {
  let labels = Array(capacity=size)
  for index in 0..<size {
    labels.push(index.to_string())
  }
  labels
}

///|
fn Axes::configure_matrix_axes(
  self : Axes,
  rows : Int32,
  columns : Int32,
) -> Unit raise @core.DataError {
  self.set_x_limits(-0.5, Double::from_int(columns) - 0.5)
  self.set_y_limits(Double::from_int(rows) - 0.5, -0.5)
  self.set_x_ticks(matrix_index_ticks(columns))
  self.set_y_ticks(matrix_index_ticks(rows))
  self.set_x_tick_labels(matrix_index_labels(columns))
  self.set_y_tick_labels(matrix_index_labels(rows))
  self.set_x_tick_position(@axis.TickPosition::Both)
  self.set_aspect_equal()
}

///|
/// Display a two-dimensional matrix with zero-based row and column indices.
///
/// The first row is rendered at the top, x tick labels are placed above the
/// image, and one data unit has the same display size on both axes. The
/// `interpolation` accepts the same filter names as `imshow`.
pub fn Axes::matshow(
  self : Axes,
  data : Array[Array[Double]],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      self.imshow(data, vmin~, vmax~, cmap~, interpolation~)
    (Some(vmin), None) => self.imshow(data, vmin~, cmap~, interpolation~)
    (None, Some(vmax)) => self.imshow(data, vmax~, cmap~, interpolation~)
    (None, None) => self.imshow(data, cmap~, interpolation~)
  }
  let rows = data.length()
  let columns = if rows == 0 { 0 } else { data[0].length() }
  self.configure_matrix_axes(rows, columns)
}

///|
/// Display a two-dimensional matrix on the default axes panel.
pub fn Figure::matshow(
  self : Figure,
  data : Array[Array[Double]],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      self.axes().matshow(data, vmin~, vmax~, cmap~, interpolation~)
    (Some(vmin), None) =>
      self.axes().matshow(data, vmin~, cmap~, interpolation~)
    (None, Some(vmax)) =>
      self.axes().matshow(data, vmax~, cmap~, interpolation~)
    (None, None) => self.axes().matshow(data, cmap~, interpolation~)
  }
}
