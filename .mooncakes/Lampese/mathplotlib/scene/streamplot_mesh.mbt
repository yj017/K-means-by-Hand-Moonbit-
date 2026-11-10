///|
fn mesh_close(left : Double, right : Double) -> Bool {
  Double::abs(left - right) <= 1.0e-8 + 1.0e-5 * Double::abs(right)
}

///|
fn stream_mesh_axes(
  x_grid : Array[Array[Double]],
  y_grid : Array[Array[Double]],
) -> (Array[Double], Array[Double]) raise @core.DataError {
  if x_grid.length() == 0 || y_grid.length() == 0 {
    raise @core.DataError::InvalidStreamplot(
      message="streamplot mesh coordinates must not be empty",
    )
  }
  if x_grid.length() != y_grid.length() {
    raise @core.DataError::InvalidStreamplot(
      message="streamplot mesh x and y rows must match",
    )
  }
  let columns = x_grid[0].length()
  if columns == 0 || y_grid[0].length() != columns {
    raise @core.DataError::InvalidStreamplot(
      message="streamplot mesh rows must have equal non-zero length",
    )
  }
  for row in 0..<x_grid.length() {
    if x_grid[row].length() != columns || y_grid[row].length() != columns {
      raise @core.DataError::InvalidStreamplot(
        message="streamplot mesh rows must have equal length",
      )
    }
  }
  let xs = x_grid[0].copy()
  let ys = Array(capacity=y_grid.length())
  for row in 0..<y_grid.length() {
    ys.push(y_grid[row][0])
    for column in 0..<columns {
      if !mesh_close(x_grid[row][column], xs[column]) {
        raise @core.DataError::InvalidStreamplot(
          message="the rows of streamplot mesh x must be equal",
        )
      }
      if !mesh_close(y_grid[row][column], y_grid[row][0]) {
        raise @core.DataError::InvalidStreamplot(
          message="the columns of streamplot mesh y must be equal",
        )
      }
    }
  }
  (xs, ys)
}

///|
/// Draw a streamline field from meshgrid-style two-dimensional coordinates.
pub fn Figure::streamplot_mesh(
  self : Figure,
  x_grid : Array[Array[Double]],
  y_grid : Array[Array[Double]],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  density~ : Double = 1.0,
  density_x~ : Double = -1.0,
  density_y~ : Double = -1.0,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  max_steps~ : Int32 = 200,
  minlength~ : Double = 0.1,
  start_points~ : Array[@core.Point] = [],
  maxlength~ : Double = 4.0,
  integration_direction~ : String = "both",
  broken_streamlines~ : Bool = true,
  integration_max_step_scale~ : Double = 1.0,
  integration_max_error_scale~ : Double = 1.0,
  arrows~ : Bool = true,
  arrow_size~ : Double = 1.0,
  num_arrows~ : Int32 = 1,
  arrowstyle~ : String = "-|>",
  label~ : String = "",
) -> StreamplotSet raise @core.DataError {
  let (xs, ys) = stream_mesh_axes(x_grid, y_grid)
  self
  .axes()
  .streamplot(
    xs,
    ys,
    us,
    vs,
    density~,
    density_x~,
    density_y~,
    color~,
    linewidth~,
    max_steps~,
    minlength~,
    start_points~,
    maxlength~,
    integration_direction~,
    broken_streamlines~,
    integration_max_step_scale~,
    integration_max_error_scale~,
    arrows~,
    arrow_size~,
    num_arrows~,
    arrowstyle~,
    label~,
  )
}

///|
/// Draw a streamline field from meshgrid-style two-dimensional coordinates.
pub fn Axes::streamplot_mesh(
  self : Axes,
  x_grid : Array[Array[Double]],
  y_grid : Array[Array[Double]],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  density~ : Double = 1.0,
  density_x~ : Double = -1.0,
  density_y~ : Double = -1.0,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  max_steps~ : Int32 = 200,
  minlength~ : Double = 0.1,
  start_points~ : Array[@core.Point] = [],
  maxlength~ : Double = 4.0,
  integration_direction~ : String = "both",
  broken_streamlines~ : Bool = true,
  integration_max_step_scale~ : Double = 1.0,
  integration_max_error_scale~ : Double = 1.0,
  arrows~ : Bool = true,
  arrow_size~ : Double = 1.0,
  num_arrows~ : Int32 = 1,
  arrowstyle~ : String = "-|>",
  label~ : String = "",
) -> StreamplotSet raise @core.DataError {
  let (xs, ys) = stream_mesh_axes(x_grid, y_grid)
  self.streamplot(
    xs,
    ys,
    us,
    vs,
    density~,
    density_x~,
    density_y~,
    color~,
    linewidth~,
    max_steps~,
    minlength~,
    start_points~,
    maxlength~,
    integration_direction~,
    broken_streamlines~,
    integration_max_step_scale~,
    integration_max_error_scale~,
    arrows~,
    arrow_size~,
    num_arrows~,
    arrowstyle~,
    label~,
  )
}
