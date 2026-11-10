///|
/// Bins returned by `hexbin`.
pub struct Hexbin {
  centers : Array[@core.Point]
  values : Array[Double]
  counts : Array[Int32]
}

///|
/// A user supplied reducer for values collected in one hexbin cell.
pub struct HexbinReducer {
  reducer : (Array[Double]) -> Double
}

///|
/// Wrap a callable reducer for use with `hexbin(reduce_fn=...)`.
pub fn hexbin_reducer(reducer : (Array[Double]) -> Double) -> HexbinReducer {
  { reducer, }
}

///|
pub fn HexbinReducer::apply(
  self : HexbinReducer,
  samples : Array[Double],
) -> Double {
  (self.reducer)(samples)
}

///|
pub fn Hexbin::centers(self : Hexbin) -> Array[@core.Point] {
  self.centers.copy()
}

///|
pub fn Hexbin::values(self : Hexbin) -> Array[Double] {
  self.values.copy()
}

///|
pub fn Hexbin::counts(self : Hexbin) -> Array[Int32] {
  self.counts.copy()
}

///|
priv struct HexbinCell {
  col : Int32
  row : Int32
  mut count : Int32
  mut sum : Double
  samples : Array[Double]
}

///|
fn validate_hexbin_reduce(reduce : String) -> Unit raise @core.DataError {
  if reduce != "mean" &&
    reduce != "sum" &&
    reduce != "min" &&
    reduce != "max" &&
    reduce != "count" {
    raise @core.DataError::InvalidStatistics(
      message="hexbin reduce must be mean, sum, min, max, or count",
    )
  }
}

///|
fn validate_hexbin_bins(bins : String) -> Unit raise @core.DataError {
  if bins != "linear" && bins != "log" {
    raise @core.DataError::InvalidStatistics(
      message="hexbin bins must be linear or log",
    )
  }
}

///|
fn hexbin_color_norm(
  bins : String,
  vmin : Double?,
  vmax : Double?,
) -> @colors.ColorNorm raise @core.DataError {
  if bins == "linear" {
    return linear_color_norm(vmin, vmax)
  }
  let norm = try {
    match (vmin, vmax) {
      (Some(lower), Some(upper)) => @colors.log_norm(vmin=lower, vmax=upper)
      (Some(lower), None) => @colors.log_norm(vmin=lower)
      (None, Some(upper)) => @colors.log_norm(vmax=upper)
      (None, None) => @colors.log_norm()
    }
  } catch {
    @colors.NormalizeError::InvalidBounds(message~)
    | @colors.NormalizeError::InvalidBase(message~)
    | @colors.NormalizeError::InvalidValue(message~) =>
      raise @core.DataError::InvalidStatistics(message~)
    @colors.NormalizeError::NoFiniteData
    | @colors.NormalizeError::NotScaled
    | @colors.NormalizeError::NotInvertible =>
      raise @core.DataError::InvalidStatistics(
        message="invalid hexbin logarithmic normalization",
      )
  }
  @colors.log_color_norm(norm)
}

///|
fn reduce_hexbin_cell(
  cell : HexbinCell,
  has_values : Bool,
  reduce : String,
  reduce_fn : HexbinReducer?,
) -> Double raise @core.DataError {
  match reduce_fn {
    Some(reducer) => {
      if !has_values {
        raise @core.DataError::InvalidStatistics(
          message="hexbin reduce_fn requires values",
        )
      }
      let result = reducer.apply(cell.samples.copy())
      if !hexbin_finite(result) {
        raise @core.DataError::InvalidStatistics(
          message="hexbin reduce_fn must return a finite value",
        )
      }
      result
    }
    None =>
      if !has_values || reduce == "count" {
        Double::from_int(cell.count)
      } else if reduce == "sum" {
        cell.sum
      } else if reduce == "min" {
        let mut result = cell.samples[0]
        for value in cell.samples {
          result = Double::min(result, value)
        }
        result
      } else if reduce == "max" {
        let mut result = cell.samples[0]
        for value in cell.samples {
          result = Double::max(result, value)
        }
        result
      } else {
        cell.sum / Double::from_int(cell.count)
      }
  }
}

///|
fn hexbin_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn hexbin_scale_values(
  xs : Array[Double],
  ys : Array[Double],
  x_scale : @scale.Scale,
  y_scale : @scale.Scale,
) -> (Array[Double], Array[Double]) raise @core.DataError {
  let scaled_xs = Array(capacity=xs.length())
  let scaled_ys = Array(capacity=ys.length())
  for index in 0..<xs.length() {
    let x = xs[index]
    let y = ys[index]
    if !hexbin_finite(x) || !hexbin_finite(y) {
      raise @core.DataError::InvalidStatistics(
        message="hexbin coordinates must be finite",
      )
    }
    if !x_scale.is_valid(x) || !y_scale.is_valid(y) {
      raise @core.DataError::InvalidStatistics(
        message="hexbin coordinates must be valid for the axis scale",
      )
    }
    scaled_xs.push(x_scale.transform(x))
    scaled_ys.push(y_scale.transform(y))
  }
  (scaled_xs, scaled_ys)
}

///|
fn hexbin_bounds(
  xs : Array[Double],
  ys : Array[Double],
) -> (Double, Double, Double, Double) raise @core.DataError {
  if xs.length() == 0 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin requires at least one point",
    )
  }
  let mut xmin = 0.0
  let mut xmax = 0.0
  let mut ymin = 0.0
  let mut ymax = 0.0
  let mut found = false
  for index in 0..<xs.length() {
    let x = xs[index]
    let y = ys[index]
    if !hexbin_finite(x) || !hexbin_finite(y) {
      raise @core.DataError::InvalidStatistics(
        message="hexbin coordinates must be finite",
      )
    }
    if !found {
      xmin = x
      xmax = x
      ymin = y
      ymax = y
      found = true
    } else {
      xmin = Double::min(xmin, x)
      xmax = Double::max(xmax, x)
      ymin = Double::min(ymin, y)
      ymax = Double::max(ymax, y)
    }
  }
  if xmin == xmax {
    xmin -= 0.5
    xmax += 0.5
  }
  if ymin == ymax {
    ymin -= 0.5
    ymax += 0.5
  }
  (xmin, xmax, ymin, ymax)
}

///|
fn hexbin_extent_bounds(
  extent : Array[Double],
  x_scale : @scale.Scale,
  y_scale : @scale.Scale,
) -> (Double, Double, Double, Double)? raise @core.DataError {
  if extent.length() == 0 {
    return None
  }
  if extent.length() != 4 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin extent must contain xmin, xmax, ymin, and ymax",
    )
  }
  let xmin = extent[0]
  let xmax = extent[1]
  let ymin = extent[2]
  let ymax = extent[3]
  if !hexbin_finite(xmin) ||
    !hexbin_finite(xmax) ||
    !hexbin_finite(ymin) ||
    !hexbin_finite(ymax) {
    raise @core.DataError::InvalidStatistics(
      message="hexbin extent must be finite",
    )
  }
  if !x_scale.is_valid(xmin) ||
    !x_scale.is_valid(xmax) ||
    !y_scale.is_valid(ymin) ||
    !y_scale.is_valid(ymax) {
    raise @core.DataError::InvalidStatistics(
      message="hexbin extent must be valid for the axis scale",
    )
  }
  let first_x = x_scale.transform(xmin)
  let second_x = x_scale.transform(xmax)
  let first_y = y_scale.transform(ymin)
  let second_y = y_scale.transform(ymax)
  if first_x == second_x || first_y == second_y {
    raise @core.DataError::InvalidStatistics(
      message="hexbin extent must span both axes",
    )
  }
  Some(
    (
      Double::min(first_x, second_x),
      Double::max(first_x, second_x),
      Double::min(first_y, second_y),
      Double::max(first_y, second_y),
    ),
  )
}

///|
fn hexbin_rectangle(
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
  x_scale : @scale.Scale,
  y_scale : @scale.Scale,
) -> Array[@core.Point] {
  [
    @core.point(x_scale.inverse(xmin), y_scale.inverse(ymin)),
    @core.point(x_scale.inverse(xmax), y_scale.inverse(ymin)),
    @core.point(x_scale.inverse(xmax), y_scale.inverse(ymax)),
    @core.point(x_scale.inverse(xmin), y_scale.inverse(ymax)),
  ]
}

///|
/// Bin points into a regular hexagonal grid and add filled polygons.
pub fn Figure::hexbin(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  values~ : Array[Double] = [],
  gridsize~ : Int32 = 20,
  mincnt~ : Int32 = 0,
  cmap~ : String = "viridis",
  vmin? : Double,
  vmax? : Double,
  color~ : String = "",
  label~ : String = "",
  reduce~ : String = "mean",
  edgecolor~ : String = "",
  linewidth~ : Double = 0.0,
  bins~ : String = "linear",
  extent~ : Array[Double] = [],
  marginals~ : Bool = false,
  reduce_fn? : HexbinReducer,
) -> Hexbin raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      self
      .axes()
      .hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        vmin~,
        vmax~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
    (Some(vmin), None) =>
      self
      .axes()
      .hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        vmin~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
    (None, Some(vmax)) =>
      self
      .axes()
      .hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        vmax~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
    (None, None) =>
      self
      .axes()
      .hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
  }
}

///|
/// Bin points into a regular hexagonal grid and add filled polygons.
pub fn Axes::hexbin(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  values~ : Array[Double] = [],
  gridsize~ : Int32 = 20,
  mincnt~ : Int32 = 0,
  cmap~ : String = "viridis",
  vmin? : Double,
  vmax? : Double,
  color~ : String = "",
  label~ : String = "",
  reduce~ : String = "mean",
  edgecolor~ : String = "",
  linewidth~ : Double = 0.0,
  bins~ : String = "linear",
  extent~ : Array[Double] = [],
  marginals~ : Bool = false,
  reduce_fn~ : HexbinReducer? = None,
) -> Hexbin raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  if values.length() != 0 && values.length() != xs.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=values.length(),
    )
  }
  if gridsize < 1 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin gridsize must be positive",
    )
  }
  if mincnt < 0 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin mincnt must be non-negative",
    )
  }
  if linewidth.is_nan() || linewidth.is_inf() || linewidth < 0.0 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin linewidth must be finite and non-negative",
    )
  }
  validate_hexbin_reduce(reduce)
  validate_hexbin_bins(bins)
  if reduce_fn is Some(_) && values.length() == 0 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin reduce_fn requires values",
    )
  }
  for value in values {
    if !hexbin_finite(value) {
      raise @core.DataError::InvalidStatistics(
        message="hexbin values must be finite",
      )
    }
  }
  let x_scale = self.x_scale()
  let y_scale = self.y_scale()
  let (scaled_xs, scaled_ys) = hexbin_scale_values(xs, ys, x_scale, y_scale)
  let (xmin, xmax, ymin, ymax) = match
    hexbin_extent_bounds(extent, x_scale, y_scale) {
    Some(bounds) => bounds
    None => hexbin_bounds(scaled_xs, scaled_ys)
  }
  let grid = hexbin_grid(xmin, xmax, ymin, ymax, gridsize)
  let cells : Array[HexbinCell] = []
  let cell_indices : Map[(Int32, Int32), Int32] = Map([])
  for index in 0..<xs.length() {
    if scaled_xs[index] < xmin ||
      scaled_xs[index] > xmax ||
      scaled_ys[index] < ymin ||
      scaled_ys[index] > ymax {
      continue
    }
    let (column, row) = grid.cell(scaled_xs[index], scaled_ys[index])
    match cell_indices.get((column, row)) {
      Some(cell) => {
        cells[cell].count += 1
        if values.length() > 0 {
          cells[cell].sum += values[index]
          cells[cell].samples.push(values[index])
        }
      }
      None => {
        cell_indices[(column, row)] = cells.length()
        cells.push({
          col: column,
          row,
          count: 1,
          sum: if values.length() > 0 {
            values[index]
          } else {
            0.0
          },
          samples: if values.length() > 0 {
            [values[index]]
          } else {
            []
          },
        })
      }
    }
  }
  let centers : Array[@core.Point] = []
  let bin_values : Array[Double] = []
  let counts : Array[Int32] = []
  let bin_indices : Array[(Int32, Int32)] = []
  for cell in cells {
    if cell.count >= mincnt {
      let (center_x, center_y) = grid.center(cell.col, cell.row)
      let value = reduce_hexbin_cell(
        cell,
        values.length() > 0,
        reduce,
        reduce_fn,
      )
      centers.push(
        @core.point(x_scale.inverse(center_x), y_scale.inverse(center_y)),
      )
      bin_values.push(value)
      counts.push(cell.count)
      bin_indices.push((cell.row, cell.col))
    }
  }
  if bins == "log" {
    for value in bin_values {
      if value <= 0.0 {
        raise @core.DataError::InvalidStatistics(
          message="hexbin logarithmic bins require positive values",
        )
      }
    }
  }
  let mut legend_color = color
  let hit_paints : Array[Bool] = []
  let fill_color = if color == "" {
    let color_map = resolve_colormap(cmap)
    let norm = hexbin_color_norm(bins, vmin, vmax)
    norm.autoscale_none(bin_values)
    let style_values = Array(capacity=bin_values.length())
    for value in bin_values {
      if norm.is_valid(value) {
        let paint = color_map.sample_extended(mesh_transform(norm, value))
        style_values.push(paint.to_css())
        hit_paints.push(paint.alpha() > 0.0)
      } else {
        style_values.push("#000000")
        hit_paints.push(false)
      }
    }
    if style_values.length() > 0 {
      legend_color = style_values[0]
    } else {
      legend_color = color_map.sample_extended(0.5).to_css()
    }
    style_values
  } else {
    let style_values = Array(capacity=bin_values.length())
    for _ in bin_values {
      style_values.push(color)
      hit_paints.push(true)
    }
    style_values
  }
  for index in 0..<centers.length() {
    let center = centers[index]
    let (row, column) = bin_indices[index]
    let stroke_color = if edgecolor == "" {
      fill_color[index]
    } else {
      edgecolor
    }
    self.push_artist(
      Artist::Polygon(
        grid.vertices(column, row, x_scale, y_scale),
        @core.style(stroke_color, width=linewidth, fill=fill_color[index]),
      ),
    )
    // Marginal rectangles are painted above the cells in the same axes. Keep
    // this first interaction slice wholly static for that mode, rather than
    // selecting an obscured cell through a marginal's paint.
    if !marginals && hit_paints[index] && hexbin_finite(bin_values[index]) {
      self.record_hit_series(label)
      self.record_hexbin(
        @render.hexbin_hit_data(
          index,
          center,
          bin_values[index],
          @drawing.hexbin_info(
            row,
            column,
            counts[index],
            reduction=hexbin_reduction(values.length() > 0, reduce, reduce_fn),
          ),
        ),
      )
    }
  }
  if marginals && cells.length() > 0 {
    let marginals = hexbin_marginals(cells)
    let mut maximum_column = 1
    let mut maximum_row = 1
    for _, count in marginals.columns {
      maximum_column = maximum_column.max(count)
    }
    for _, count in marginals.rows {
      maximum_row = maximum_row.max(count)
    }
    let marginal_height = Double::min((ymax - ymin) * 0.2, grid.sy / 4.0)
    let marginal_width = Double::min((xmax - xmin) * 0.2, grid.sx / 4.0)
    let marginal_color = if color == "" { legend_color } else { color }
    let marginal_style = @core.style(
      if edgecolor == "" {
        marginal_color
      } else {
        edgecolor
      },
      width=linewidth,
      fill=marginal_color,
    )
    for (column, parity), count in marginals.columns {
      let center = xmin +
        (column.to_double() + parity.to_double() / 2.0) * grid.sx
      let lower = xmin.max(center - grid.sx / 4.0)
      let upper = xmax.min(center + grid.sx / 4.0)
      let height = marginal_height *
        Double::from_int(count) /
        Double::from_int(maximum_column)
      self.push_artist(
        Artist::Polygon(
          hexbin_rectangle(lower, upper, ymin, ymin + height, x_scale, y_scale),
          marginal_style,
        ),
      )
    }
    for row, count in marginals.rows {
      let center = ymin + row.to_double() / 2.0 * grid.sy
      let lower = ymin.max(center - grid.sy / 4.0)
      let upper = ymax.min(center + grid.sy / 4.0)
      let width = marginal_width *
        Double::from_int(count) /
        Double::from_int(maximum_row)
      self.push_artist(
        Artist::Polygon(
          hexbin_rectangle(xmax - width, xmax, lower, upper, x_scale, y_scale),
          marginal_style,
        ),
      )
    }
  }
  self.add_auto_legend(label, legend_color, LegendKind::Patch)
  { centers, values: bin_values, counts, }
}
