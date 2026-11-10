///|
fn validate_mesh_data(
  data : Array[Array[Double]],
) -> (Int32, Int32) raise @core.DataError {
  if data.length() == 0 || data[0].length() == 0 {
    raise @core.DataError::InvalidImage(
      message="pcolor data must have at least one cell",
    )
  }
  let columns = data[0].length()
  for row in data {
    if row.length() != columns {
      raise @core.DataError::InvalidImage(
        message="pcolor data rows must have equal length",
      )
    }
  }
  (data.length(), columns)
}

///|
fn mesh_axis(
  values : Array[Double],
  count : Int32,
  axis : String,
) -> Array[Double] raise @core.DataError {
  if values.length() == 0 {
    let result = Array(capacity=count + 1)
    for index in 0..<=count {
      result.push(Double::from_int(index))
    }
    result
  } else {
    if values.length() != count + 1 {
      raise @core.DataError::InvalidImage(
        message="pcolor \{axis} boundaries must have one more value than cells",
      )
    }
    for value in values {
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidImage(
          message="pcolor coordinates must be finite",
        )
      }
    }
    if values.length() > 1 {
      let increasing = values[1] > values[0]
      for index in 1..<values.length() {
        let previous = values[index - 1]
        let current = values[index]
        if increasing {
          if current <= previous {
            raise @core.DataError::InvalidImage(
              message="pcolor coordinates must be strictly monotonic",
            )
          }
        } else if current >= previous {
          raise @core.DataError::InvalidImage(
            message="pcolor coordinates must be strictly monotonic",
          )
        }
      }
    }
    values.copy()
  }
}

///|
fn mesh_transform(
  norm : @colors.ColorNorm,
  value : Double,
) -> Double raise @core.DataError {
  norm.transform(value) catch {
    @colors.NormalizeError::InvalidBounds(message~)
    | @colors.NormalizeError::InvalidBase(message~)
    | @colors.NormalizeError::InvalidValue(message~) =>
      raise @core.DataError::InvalidImage(message~)
    @colors.NormalizeError::NotScaled =>
      raise @core.DataError::InvalidImage(
        message="pcolor normalization is not scaled",
      )
    @colors.NormalizeError::NoFiniteData =>
      raise @core.DataError::InvalidImage(message="pcolor has no finite data")
    @colors.NormalizeError::NotInvertible =>
      raise @core.DataError::InvalidImage(
        message="pcolor normalization is not invertible",
      )
  }
}

///|
fn mesh_values(data : Array[Array[Double]]) -> Array[Double] {
  let values = Array(capacity=data.length())
  for row in data {
    for value in row {
      values.push(value)
    }
  }
  values
}

///|
fn add_mesh(
  axes : Axes,
  data : Array[Array[Double]],
  x : Array[Double],
  y : Array[Double],
  vmin : Double?,
  vmax : Double?,
  cmap : String,
  draw_bad : Bool,
  antialiased : Bool,
  histogram2d~ : Bool = false,
) -> Unit raise @core.DataError {
  let color_map = resolve_colormap(cmap)
  let norm = linear_color_norm(vmin, vmax)
  add_mesh_with_norm(
    axes,
    data,
    x,
    y,
    norm,
    color_map,
    draw_bad,
    antialiased,
    histogram2d~,
  )
}

///|
fn add_mesh_with_norm(
  axes : Axes,
  data : Array[Array[Double]],
  x : Array[Double],
  y : Array[Double],
  norm : @colors.ColorNorm,
  color_map : @colors.ColorMap,
  draw_bad : Bool,
  antialiased : Bool,
  histogram2d~ : Bool = false,
) -> Unit raise @core.DataError {
  let (rows, columns) = validate_mesh_data(data)
  if (x.length() == 0) != (y.length() == 0) {
    raise @core.DataError::InvalidImage(
      message="pcolor x and y boundaries must be supplied together",
    )
  }
  let xs = mesh_axis(x, columns, "x")
  let ys = mesh_axis(y, rows, "y")
  norm.autoscale_none(mesh_values(data))
  for row in 0..<rows {
    for column in 0..<columns {
      let value = data[row][column]
      // PolyQuadMesh removes masked faces; QuadMesh maps them to the bad color.
      if !draw_bad && (value.is_nan() || value.is_inf()) {
        continue
      }
      let valid = norm.is_valid(value)
      let normalized : Double? = if valid {
        Some(mesh_transform(norm, value))
      } else if color_map.bad() is Some(_) {
        // Values rejected by a normalization (for example non-positive
        // values under LogNorm) use the colormap's bad color. Source
        // non-finite values were omitted above for pcolor, while pcolormesh
        // keeps them as transparent/bad cells.
        Some(0.0 / 0.0)
      } else {
        None
      }
      match normalized {
        Some(normalized) => {
          let paint = color_map.sample_extended(normalized)
          let color = paint.to_css()
          axes.push_artist(
            Artist::Polygon(
              [
                @core.point(xs[column], ys[row]),
                @core.point(xs[column + 1], ys[row]),
                @core.point(xs[column + 1], ys[row + 1]),
                @core.point(xs[column], ys[row + 1]),
              ],
              @core.style(
                color,
                width=if antialiased { 0.5 } else { 0.0 },
                fill=color,
              ),
            ),
          )
          if valid && !value.is_nan() && !value.is_inf() && paint.alpha() > 0.0 {
            axes.record_mesh_cell(
              @render.mesh_hit_data(
                row,
                column,
                columns,
                value,
                (xs[column], xs[column + 1]),
                (ys[row], ys[row + 1]),
                histogram=histogram2d,
              ),
            )
          }
        }
        None => ()
      }
    }
  }
}

///|
/// Draw scalar values as filled quadrilaterals on a rectangular grid.
///
/// When supplied, `x` and `y` contain cell boundaries and therefore have one
/// more value than the number of columns and rows. Empty coordinates use an
/// integer grid. Source masked or non-finite cells are omitted from the
/// polygon set; values rejected by a normalization use the colormap bad color
/// when one is configured.
pub fn Figure::pcolor(
  self : Figure,
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
      self.axes().pcolor(data, x~, y~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      self.axes().pcolor(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      self.axes().pcolor(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) => self.axes().pcolor(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw scalar values as filled quadrilaterals on a rectangular grid.
pub fn Axes::pcolor(
  self : Axes,
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_mesh(self, data, x, y, vmin, vmax, cmap, false, antialiased)
}

///|
/// Draw a scalar mesh using an explicit normalization and colormap object.
pub fn Figure::pcolor_with_norm_and_colormap(
  self : Figure,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  self
  .axes()
  .pcolor_with_norm_and_colormap(data, norm, cmap, x~, y~, antialiased~)
}

///|
/// Draw a scalar mesh through the axes view with explicit normalization.
pub fn Axes::pcolor_with_norm_and_colormap(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_mesh_with_norm(self, data, x, y, norm, cmap, false, antialiased)
}

///|
/// Draw a scalar mesh with an explicit normalization and named colormap.
pub fn Figure::pcolor_with_norm(
  self : Figure,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  self.axes().pcolor_with_norm(data, norm, cmap~, x~, y~, antialiased~)
}

///|
/// Draw a scalar mesh through the axes view with explicit normalization.
pub fn Axes::pcolor_with_norm(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = true,
) -> Unit raise @core.DataError {
  add_mesh_with_norm(
    self,
    data,
    x,
    y,
    norm,
    resolve_colormap(cmap),
    false,
    antialiased,
  )
}

///|
/// Draw a rectangular scalar mesh with 1D cell boundaries. Masked or
/// non-finite cells use the colormap's bad color, which is transparent by default.
pub fn Figure::pcolormesh(
  self : Figure,
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
      self.axes().pcolormesh(data, x~, y~, vmin~, vmax~, cmap~, antialiased~)
    (Some(vmin), None) =>
      self.axes().pcolormesh(data, x~, y~, vmin~, cmap~, antialiased~)
    (None, Some(vmax)) =>
      self.axes().pcolormesh(data, x~, y~, vmax~, cmap~, antialiased~)
    (None, None) => self.axes().pcolormesh(data, x~, y~, cmap~, antialiased~)
  }
}

///|
/// Draw a fast rectangular scalar mesh.
pub fn Axes::pcolormesh(
  self : Axes,
  data : Array[Array[Double]],
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_mesh(self, data, x, y, vmin, vmax, cmap, true, antialiased)
}

///|
/// Draw a fast scalar mesh using an explicit normalization and colormap.
pub fn Figure::pcolormesh_with_norm_and_colormap(
  self : Figure,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  self
  .axes()
  .pcolormesh_with_norm_and_colormap(data, norm, cmap, x~, y~, antialiased~)
}

///|
/// Draw a fast scalar mesh through the axes view with explicit normalization.
pub fn Axes::pcolormesh_with_norm_and_colormap(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_mesh_with_norm(self, data, x, y, norm, cmap, true, antialiased)
}

///|
/// Draw a fast scalar mesh with an explicit normalization and named colormap.
pub fn Figure::pcolormesh_with_norm(
  self : Figure,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  self.axes().pcolormesh_with_norm(data, norm, cmap~, x~, y~, antialiased~)
}

///|
/// Draw a fast scalar mesh through the axes view with explicit normalization.
pub fn Axes::pcolormesh_with_norm(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "viridis",
  x~ : Array[Double] = [],
  y~ : Array[Double] = [],
  antialiased~ : Bool = false,
) -> Unit raise @core.DataError {
  add_mesh_with_norm(
    self,
    data,
    x,
    y,
    norm,
    resolve_colormap(cmap),
    true,
    antialiased,
  )
}
