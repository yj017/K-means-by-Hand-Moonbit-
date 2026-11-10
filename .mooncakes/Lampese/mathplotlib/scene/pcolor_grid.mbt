///|
fn validate_grid_coordinates(
  coordinates : Array[Array[Double]],
  rows : Int32,
  columns : Int32,
  expected_rows : Int32,
  expected_columns : Int32,
  axis : String,
) -> Unit raise @core.DataError {
  if coordinates.length() != expected_rows {
    raise @core.DataError::InvalidImage(
      message="pcolor {axis} grid has an invalid row count",
    )
  }
  for row in coordinates {
    if row.length() != expected_columns {
      raise @core.DataError::InvalidImage(
        message="pcolor {axis} grid has an invalid column count",
      )
    }
    for value in row {
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidImage(
          message="pcolor grid coordinates must be finite",
        )
      }
    }
  }
  ignore(rows)
  ignore(columns)
  ignore(axis)
}

///|
fn validate_grid_mask(
  mask : Array[Array[Bool]],
  expected_rows : Int32,
  expected_columns : Int32,
  axis : String,
) -> Unit raise @core.DataError {
  if mask.length() == 0 {
    return
  }
  if mask.length() != expected_rows {
    raise @core.DataError::InvalidImage(
      message="pcolor \{axis} mask has an invalid row count",
    )
  }
  for row in mask {
    if row.length() != expected_columns {
      raise @core.DataError::InvalidImage(
        message="pcolor \{axis} mask has an invalid column count",
      )
    }
  }
}

///|
fn mask_at(mask : Array[Array[Bool]], row : Int32, column : Int32) -> Bool {
  mask.length() > 0 && mask[row][column]
}

///|
fn grid_cell_coordinates_masked(
  x_mask : Array[Array[Bool]],
  y_mask : Array[Array[Bool]],
  row : Int32,
  column : Int32,
  rows : Int32,
  columns : Int32,
  shading : String,
) -> Bool {
  if shading == "flat" || shading == "gouraud" {
    mask_at(x_mask, row, column) ||
    mask_at(x_mask, row, column + 1) ||
    mask_at(x_mask, row + 1, column) ||
    mask_at(x_mask, row + 1, column + 1) ||
    mask_at(y_mask, row, column) ||
    mask_at(y_mask, row, column + 1) ||
    mask_at(y_mask, row + 1, column) ||
    mask_at(y_mask, row + 1, column + 1)
  } else {
    // Nearest derives each edge from the center and its immediate neighbor.
    mask_at(x_mask, row, column) ||
    (column > 0 && mask_at(x_mask, row, column - 1)) ||
    (column + 1 < columns && mask_at(x_mask, row, column + 1)) ||
    mask_at(y_mask, row, column) ||
    (row > 0 && mask_at(y_mask, row - 1, column)) ||
    (row + 1 < rows && mask_at(y_mask, row + 1, column))
  }
}

///|
fn nearest_grid_edge(
  coordinates : Array[Array[Double]],
  row : Int32,
  column : Int32,
  rows : Int32,
  columns : Int32,
  horizontal : Bool,
  lower : Bool,
) -> Double {
  let center = coordinates[row][column]
  if horizontal {
    if lower {
      if column == 0 {
        if columns == 1 {
          center - 0.5
        } else {
          center - (coordinates[row][column + 1] - center) / 2.0
        }
      } else {
        (coordinates[row][column - 1] + center) / 2.0
      }
    } else if column + 1 == columns {
      if columns == 1 {
        center + 0.5
      } else {
        center + (center - coordinates[row][column - 1]) / 2.0
      }
    } else {
      (center + coordinates[row][column + 1]) / 2.0
    }
  } else if lower {
    if row == 0 {
      if rows == 1 {
        center - 0.5
      } else {
        center - (coordinates[row + 1][column] - center) / 2.0
      }
    } else {
      (coordinates[row - 1][column] + center) / 2.0
    }
  } else if row + 1 == rows {
    if rows == 1 {
      center + 0.5
    } else {
      center + (center - coordinates[row - 1][column]) / 2.0
    }
  } else {
    (center + coordinates[row + 1][column]) / 2.0
  }
}

///|
fn grid_cell_corners(
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  row : Int32,
  column : Int32,
  rows : Int32,
  columns : Int32,
  shading : String,
) -> Array[@core.Point] {
  if shading == "flat" {
    [
      @core.point(x[row][column], y[row][column]),
      @core.point(x[row][column + 1], y[row][column + 1]),
      @core.point(x[row + 1][column + 1], y[row + 1][column + 1]),
      @core.point(x[row + 1][column], y[row + 1][column]),
    ]
  } else {
    let left_x = nearest_grid_edge(x, row, column, rows, columns, true, true)
    let right_x = nearest_grid_edge(x, row, column, rows, columns, true, false)
    let top_y = nearest_grid_edge(y, row, column, rows, columns, false, true)
    let bottom_y = nearest_grid_edge(
      y, row, column, rows, columns, false, false,
    )
    [
      @core.point(left_x, top_y),
      @core.point(right_x, top_y),
      @core.point(right_x, bottom_y),
      @core.point(left_x, bottom_y),
    ]
  }
}

///|
fn mesh_vertex_color(
  norm : @colors.ColorNorm,
  color_map : @colors.ColorMap,
  value : Double,
) -> String? raise @core.DataError {
  let normalized : Double? = if norm.is_valid(value) {
    Some(mesh_transform(norm, value))
  } else if color_map.bad() is Some(_) {
    Some(0.0 / 0.0)
  } else {
    None
  }
  match normalized {
    Some(value) => Some(color_map.sample_extended(value).to_css())
    None => None
  }
}

///|
fn add_gouraud_grid_with_norm(
  axes : Axes,
  data : Array[Array[Double]],
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  data_mask : Array[Array[Bool]],
  x_mask : Array[Array[Bool]],
  y_mask : Array[Array[Bool]],
  norm : @colors.ColorNorm,
  color_map : @colors.ColorMap,
  draw_bad : Bool,
) -> Unit raise @core.DataError {
  let (rows, columns) = validate_mesh_data(data)
  if rows < 2 || columns < 2 {
    raise @core.DataError::InvalidImage(
      message="pcolor gouraud shading requires at least a 2 by 2 grid",
    )
  }
  validate_grid_coordinates(x, rows, columns, rows, columns, "x")
  validate_grid_coordinates(y, rows, columns, rows, columns, "y")
  validate_grid_mask(data_mask, rows, columns, "data")
  validate_grid_mask(x_mask, rows, columns, "x")
  validate_grid_mask(y_mask, rows, columns, "y")
  norm.autoscale_none(mesh_values(data))
  for row in 0..<(rows - 1) {
    for column in 0..<(columns - 1) {
      if grid_cell_coordinates_masked(
          x_mask, y_mask, row, column, rows, columns, "gouraud",
        ) {
        continue
      }
      let v00 = if mask_at(data_mask, row, column) {
        0.0 / 0.0
      } else {
        data[row][column]
      }
      let v01 = if mask_at(data_mask, row, column + 1) {
        0.0 / 0.0
      } else {
        data[row][column + 1]
      }
      let v11 = if mask_at(data_mask, row + 1, column + 1) {
        0.0 / 0.0
      } else {
        data[row + 1][column + 1]
      }
      let v10 = if mask_at(data_mask, row + 1, column) {
        0.0 / 0.0
      } else {
        data[row + 1][column]
      }
      let source_invalid = v00.is_nan() ||
        v00.is_inf() ||
        v01.is_nan() ||
        v01.is_inf() ||
        v11.is_nan() ||
        v11.is_inf() ||
        v10.is_nan() ||
        v10.is_inf()
      if source_invalid && !draw_bad {
        continue
      }
      let c00 = mesh_vertex_color(norm, color_map, v00)
      let c01 = mesh_vertex_color(norm, color_map, v01)
      let c11 = mesh_vertex_color(norm, color_map, v11)
      let c10 = mesh_vertex_color(norm, color_map, v10)
      match (c00, c01, c11, c10) {
        (Some(c00), Some(c01), Some(c11), Some(c10)) => {
          let p00 = @core.point(x[row][column], y[row][column])
          let p01 = @core.point(x[row][column + 1], y[row][column + 1])
          let p11 = @core.point(x[row + 1][column + 1], y[row + 1][column + 1])
          let p10 = @core.point(x[row + 1][column], y[row + 1][column])
          axes.push_artist(
            Artist::GouraudTriangle([p00, p01, p11], [c00, c01, c11]),
          )
          axes.push_artist(
            Artist::GouraudTriangle([p00, p11, p10], [c00, c11, c10]),
          )
        }
        _ => ()
      }
    }
  }
}

///|
fn add_grid_mesh_with_norm(
  axes : Axes,
  data : Array[Array[Double]],
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  data_mask : Array[Array[Bool]],
  x_mask : Array[Array[Bool]],
  y_mask : Array[Array[Bool]],
  norm : @colors.ColorNorm,
  color_map : @colors.ColorMap,
  shading : String,
  draw_bad : Bool,
  antialiased : Bool,
) -> Unit raise @core.DataError {
  let (rows, columns) = validate_mesh_data(data)
  let actual_shading = if shading == "auto" {
    if x.length() == rows + 1 {
      "flat"
    } else {
      "nearest"
    }
  } else {
    shading
  }
  if actual_shading != "flat" &&
    actual_shading != "nearest" &&
    actual_shading != "gouraud" {
    raise @core.DataError::InvalidImage(
      message="pcolor shading must be flat, nearest, gouraud, or auto",
    )
  }
  let expected_rows = if actual_shading == "flat" { rows + 1 } else { rows }
  let expected_columns = if actual_shading == "flat" {
    columns + 1
  } else {
    columns
  }
  validate_grid_coordinates(
    x, rows, columns, expected_rows, expected_columns, "x",
  )
  validate_grid_coordinates(
    y, rows, columns, expected_rows, expected_columns, "y",
  )
  validate_grid_mask(data_mask, rows, columns, "data")
  validate_grid_mask(x_mask, expected_rows, expected_columns, "x")
  validate_grid_mask(y_mask, expected_rows, expected_columns, "y")
  if actual_shading == "gouraud" {
    add_gouraud_grid_with_norm(
      axes, data, x, y, data_mask, x_mask, y_mask, norm, color_map, draw_bad,
    )
    return
  }
  norm.autoscale_none(mesh_values(data))
  for row in 0..<rows {
    for column in 0..<columns {
      if grid_cell_coordinates_masked(
          x_mask, y_mask, row, column, rows, columns, actual_shading,
        ) {
        continue
      }
      let value = if mask_at(data_mask, row, column) {
        0.0 / 0.0
      } else {
        data[row][column]
      }
      if !draw_bad && (value.is_nan() || value.is_inf()) {
        continue
      }
      let normalized : Double? = if norm.is_valid(value) {
        Some(mesh_transform(norm, value))
      } else if color_map.bad() is Some(_) {
        Some(0.0 / 0.0)
      } else {
        None
      }
      match normalized {
        Some(normalized) => {
          let color = color_map.sample_extended(normalized).to_css()
          axes.push_artist(
            Artist::Polygon(
              grid_cell_corners(
                x, y, row, column, rows, columns, actual_shading,
              ),
              @core.style(
                color,
                width=if antialiased { 0.5 } else { 0.0 },
                fill=color,
              ),
            ),
          )
        }
        None => ()
      }
    }
  }
}

///|
fn add_masked_grid_mesh(
  axes : Axes,
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading : String,
  vmin : Double?,
  vmax : Double?,
  cmap : String,
  draw_bad : Bool,
  antialiased : Bool,
) -> Unit raise @core.DataError {
  let color_map = resolve_colormap(cmap)
  let norm = linear_color_norm(vmin, vmax)
  add_grid_mesh_with_norm(
    axes,
    data.values(),
    x.values(),
    y.values(),
    data.mask(),
    x.mask(),
    y.mask(),
    norm,
    color_map,
    shading,
    draw_bad,
    antialiased,
  )
}

///|
/// Draw a scalar mesh on a two-dimensional coordinate grid.
///
/// `flat` expects corner grids with shape `(rows + 1, columns + 1)`;
/// `nearest` expects center grids with the same shape as `data` and derives
/// cell edges from neighboring centers. `gouraud` expects vertex grids with
/// the same shape as `data` and linearly interpolates vertex colors across
/// each cell. `auto` selects flat when the corner shape is supplied and
/// nearest otherwise.
pub fn Figure::pcolor_grid(
  self : Figure,
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
      self
      .axes()
      .pcolor_grid(data, x, y, shading~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      self.axes().pcolor_grid(data, x, y, shading~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      self.axes().pcolor_grid(data, x, y, shading~, vmax~, cmap~, antialiased~)
    (None, None) =>
      self.axes().pcolor_grid(data, x, y, shading~, cmap~, antialiased~)
  }
}

///|
/// Draw a scalar mesh on a two-dimensional coordinate grid.
pub fn Axes::pcolor_grid(
  self : Axes,
  data : Array[Array[Double]],
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  let color_map = resolve_colormap(cmap)
  let norm = linear_color_norm(vmin, vmax)
  add_grid_mesh_with_norm(
    self,
    data,
    x,
    y,
    [],
    [],
    [],
    norm,
    color_map,
    shading,
    false,
    antialiased,
  )
}

///|
/// Draw a fast scalar mesh on a two-dimensional coordinate grid.
pub fn Figure::pcolormesh_grid(
  self : Figure,
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
      self
      .axes()
      .pcolormesh_grid(data, x, y, shading~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      self
      .axes()
      .pcolormesh_grid(data, x, y, shading~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      self
      .axes()
      .pcolormesh_grid(data, x, y, shading~, vmax~, cmap~, antialiased~)
    (None, None) =>
      self.axes().pcolormesh_grid(data, x, y, shading~, cmap~, antialiased~)
  }
}

///|
/// Draw a fast scalar mesh on a two-dimensional coordinate grid.
pub fn Axes::pcolormesh_grid(
  self : Axes,
  data : Array[Array[Double]],
  x : Array[Array[Double]],
  y : Array[Array[Double]],
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  let color_map = resolve_colormap(cmap)
  let norm = linear_color_norm(vmin, vmax)
  add_grid_mesh_with_norm(
    self,
    data,
    x,
    y,
    [],
    [],
    [],
    norm,
    color_map,
    shading,
    true,
    antialiased,
  )
}

///|
/// Draw a masked scalar mesh on a two-dimensional coordinate grid.
///
/// The data, X, and Y matrices must be rectangular. A masked data cell is
/// omitted by `pcolor_grid_masked`; `pcolormesh_grid_masked` maps it through
/// the colormap's bad color when one is configured. A masked coordinate
/// vertex omits every cell that depends on that vertex.
pub fn Figure::pcolor_grid_masked(
  self : Figure,
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_masked_grid_mesh(
    self.axes(),
    data,
    x,
    y,
    shading,
    vmin,
    vmax,
    cmap,
    false,
    antialiased,
  )
}

///|
/// Draw a fast masked scalar mesh on a two-dimensional coordinate grid.
pub fn Figure::pcolormesh_grid_masked(
  self : Figure,
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_masked_grid_mesh(
    self.axes(),
    data,
    x,
    y,
    shading,
    vmin,
    vmax,
    cmap,
    true,
    antialiased,
  )
}

///|
/// Draw a masked scalar mesh through the axes view.
pub fn Axes::pcolor_grid_masked(
  self : Axes,
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_masked_grid_mesh(
    self, data, x, y, shading, vmin, vmax, cmap, false, antialiased,
  )
}

///|
/// Draw a fast masked scalar mesh through the axes view.
pub fn Axes::pcolormesh_grid_masked(
  self : Axes,
  data : @core.MaskedMatrix,
  x : @core.MaskedMatrix,
  y : @core.MaskedMatrix,
  shading~ : String = "auto",
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_masked_grid_mesh(
    self, data, x, y, shading, vmin, vmax, cmap, true, antialiased,
  )
}
