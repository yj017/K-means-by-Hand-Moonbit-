///|
fn stream_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn validate_stream_axis(
  values : Array[Double],
  name : String,
) -> Unit raise @core.DataError {
  if values.length() < 2 {
    raise @core.DataError::InvalidStreamplot(
      message="streamplot \{name} must have at least two coordinates",
    )
  }
  for value in values {
    if !stream_finite(value) {
      raise @core.DataError::InvalidStreamplot(
        message="streamplot coordinates must be finite",
      )
    }
  }
  let span = values[values.length() - 1] - values[0]
  let spacing = span / Double::from_int(values.length() - 1)
  if !stream_finite(span) {
    raise @core.DataError::InvalidStreamplot(
      message="streamplot \{name} coordinate span must be finite",
    )
  }
  for index in 1..<values.length() {
    let previous = values[index - 1]
    let current = values[index]
    if current <= previous {
      raise @core.DataError::InvalidStreamplot(
        message="streamplot \{name} coordinates must be strictly increasing",
      )
    }
    // Upstream Grid uses numpy.allclose for uniform spacing.
    if Double::abs(current - previous - spacing) >
      1.0e-8 + 1.0e-5 * Double::abs(spacing) {
      raise @core.DataError::InvalidStreamplot(
        message="streamplot \{name} coordinates must be equally spaced",
      )
    }
  }
}

///|
fn validate_stream_field(
  field : Array[Array[Double]],
  rows : Int32,
  columns : Int32,
  name : String,
) -> Unit raise @core.DataError {
  if field.length() != rows {
    raise @core.DataError::InvalidStreamplot(
      message="streamplot \{name} rows must match y coordinates",
    )
  }
  for row in field {
    if row.length() != columns {
      raise @core.DataError::InvalidStreamplot(
        message="streamplot \{name} columns must match x coordinates",
      )
    }
  }
}

///|
fn stream_locate(values : Array[Double], value : Double) -> Int32? {
  for index in 0..<(values.length() - 1) {
    let first = values[index]
    let second = values[index + 1]
    if value >= first && value <= second {
      return Some(index)
    }
  }
  None
}

///|
fn stream_sample(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  x : Double,
  y : Double,
) -> (Double, Double)? {
  let column = match stream_locate(xs, x) {
    Some(value) => value
    None => return None
  }
  let row = match stream_locate(ys, y) {
    Some(value) => value
    None => return None
  }
  let x0 = xs[column]
  let x1 = xs[column + 1]
  let y0 = ys[row]
  let y1 = ys[row + 1]
  let tx = (x - x0) / (x1 - x0)
  let ty = (y - y0) / (y1 - y0)
  let u00 = us[row][column]
  let u01 = us[row][column + 1]
  let u10 = us[row + 1][column]
  let u11 = us[row + 1][column + 1]
  let v00 = vs[row][column]
  let v01 = vs[row][column + 1]
  let v10 = vs[row + 1][column]
  let v11 = vs[row + 1][column + 1]
  if !stream_finite(u00) ||
    !stream_finite(u01) ||
    !stream_finite(u10) ||
    !stream_finite(u11) ||
    !stream_finite(v00) ||
    !stream_finite(v01) ||
    !stream_finite(v10) ||
    !stream_finite(v11) {
    return None
  }
  let u0 = u00 + (u01 - u00) * tx
  let u1 = u10 + (u11 - u10) * tx
  let v0 = v00 + (v01 - v00) * tx
  let v1 = v10 + (v11 - v10) * tx
  Some((u0 + (u1 - u0) * ty, v0 + (v1 - v0) * ty))
}

///|
fn stream_unit_direction(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  x : Double,
  y : Double,
  x_span : Double,
  y_span : Double,
) -> (Double, Double)? {
  match stream_sample(xs, ys, us, vs, x, y) {
    None => None
    Some((u, v)) => {
      let speed = (u / x_span * (u / x_span) + v / y_span * (v / y_span)).sqrt()
      if speed <= 1.0e-12 || !stream_finite(speed) {
        None
      } else {
        // Return data-space displacement per unit axes-space arc length.
        Some((u / speed, v / speed))
      }
    }
  }
}

///|
/// Bilinearly interpolate one scalar grid at a data coordinate.
fn stream_sample_scalar(
  xs : Array[Double],
  ys : Array[Double],
  values : Array[Array[Double]],
  x : Double,
  y : Double,
) -> Double? {
  let column = match stream_locate(xs, x) {
    Some(value) => value
    None => return None
  }
  let row = match stream_locate(ys, y) {
    Some(value) => value
    None => return None
  }
  let x0 = xs[column]
  let x1 = xs[column + 1]
  let y0 = ys[row]
  let y1 = ys[row + 1]
  let tx = (x - x0) / (x1 - x0)
  let ty = (y - y0) / (y1 - y0)
  let v00 = values[row][column]
  let v01 = values[row][column + 1]
  let v10 = values[row + 1][column]
  let v11 = values[row + 1][column + 1]
  if !stream_finite(v00) ||
    !stream_finite(v01) ||
    !stream_finite(v10) ||
    !stream_finite(v11) {
    return None
  }
  let v0 = v00 + (v01 - v00) * tx
  let v1 = v10 + (v11 - v10) * tx
  Some(v0 + (v1 - v0) * ty)
}

///|
fn stream_validate_style_grid(
  values : Array[Array[Double]],
  rows : Int32,
  columns : Int32,
  name : String,
  allow_missing : Bool,
) -> Unit raise @core.DataError {
  validate_stream_field(values, rows, columns, name)
  for row in values {
    for value in row {
      if !allow_missing && !stream_finite(value) {
        raise @core.DataError::InvalidStreamplot(
          message="streamplot \{name} values must be finite",
        )
      }
    }
  }
}

///|
fn stream_grid_values(values : Array[Array[Double]]) -> Array[Double] {
  let result : Array[Double] = []
  for row in values {
    for value in row {
      if stream_finite(value) {
        result.push(value)
      }
    }
  }
  result
}

///|
fn stream_color_from_value(
  value : Double,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
) -> String? {
  let normalized = norm.transform(value) catch { _ => return None }
  Some(cmap.sample_extended(normalized).to_css())
}

///|
fn stream_inside(
  xs : Array[Double],
  ys : Array[Double],
  x : Double,
  y : Double,
) -> Bool {
  x >= Double::min(xs[0], xs[xs.length() - 1]) &&
  x <= Double::max(xs[0], xs[xs.length() - 1]) &&
  y >= Double::min(ys[0], ys[ys.length() - 1]) &&
  y <= Double::max(ys[0], ys[ys.length() - 1])
}

///|
/// Take an Euler step from a point to the first data-domain boundary.
///
/// The adaptive corrector can sample just outside the domain near an edge.
/// Matplotlib adds one final Euler point in that case so streamlines end on
/// the boundary instead of stopping one integration step early.
fn stream_boundary_step(
  xs : Array[Double],
  ys : Array[Double],
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
  max_distance : Double,
) -> (@core.Point, Double)? {
  let xmin = xs[0]
  let xmax = xs[xs.length() - 1]
  let ymin = ys[0]
  let ymax = ys[ys.length() - 1]
  let x_distance = if dx > 0.0 {
    Some((xmax - x) / dx)
  } else if dx < 0.0 {
    Some((xmin - x) / dx)
  } else {
    None
  }
  let y_distance = if dy > 0.0 {
    Some((ymax - y) / dy)
  } else if dy < 0.0 {
    Some((ymin - y) / dy)
  } else {
    None
  }
  let distance = match (x_distance, y_distance) {
    (Some(x_value), Some(y_value)) => Double::min(x_value, y_value)
    (Some(value), None) => value
    (None, Some(value)) => value
    (None, None) => return None
  }
  if distance <= 0.0 || !stream_finite(distance) {
    return None
  }
  let actual_distance = Double::min(distance, max_distance)
  Some(
    (
      @core.point(x + dx * actual_distance, y + dy * actual_distance),
      actual_distance,
    ),
  )
}

///|
fn integrate_stream(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  start_x : Double,
  start_y : Double,
  direction : Double,
  max_steps : Int32,
  x_span : Double,
  y_span : Double,
  max_length : Double,
  mask_width : Int32,
  mask_height : Int32,
  integration_max_step_scale : Double,
  integration_max_error_scale : Double,
  occupancy : Array[Bool],
  touched : Array[Int32],
  broken_streamlines : Bool,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Array[@core.Point] {
  let result = Array(capacity=max_steps + 1)
  let mut x = start_x
  let mut y = start_y
  let mut travelled = 0.0
  let max_step = Double::min(
      Double::min(
        1.0 / Double::from_int(mask_width),
        1.0 / Double::from_int(mask_height),
      ),
      0.1,
    ) *
    integration_max_step_scale
  let max_error = 0.003 * integration_max_error_scale
  result.push(@core.point(x, y))
  let mut previous_cell = Some(
    stream_cell(start_x, xmin, xmax, mask_width) +
    stream_cell(start_y, ymin, ymax, mask_height) * mask_width,
  )
  let mut step = max_step
  for _ in 0..<max_steps {
    let remaining = max_length - travelled
    if remaining <= 0.0 {
      break
    }
    let mut accepted = false
    let mut attempts = 0
    while !accepted && attempts < 10 {
      match stream_unit_direction(xs, ys, us, vs, x, y, x_span, y_span) {
        None => attempts = 10
        Some((k1_x, k1_y)) => {
          let euler_x = x + direction * step * k1_x
          let euler_y = y + direction * step * k1_y
          match
            stream_unit_direction(
              xs, ys, us, vs, euler_x, euler_y, x_span, y_span,
            ) {
            None =>
              if !stream_inside(xs, ys, euler_x, euler_y) {
                match
                  stream_boundary_step(
                    xs,
                    ys,
                    x,
                    y,
                    direction * k1_x,
                    direction * k1_y,
                    remaining,
                  ) {
                  None => attempts = 10
                  Some((boundary_point, boundary_distance)) => {
                    let (can_continue, next_cell) = stream_update_mask(
                      boundary_point, previous_cell, occupancy, touched, mask_width,
                      mask_height, xmin, xmax, ymin, ymax, broken_streamlines,
                    )
                    if !can_continue {
                      attempts = 10
                    } else {
                      x = boundary_point.x()
                      y = boundary_point.y()
                      previous_cell = Some(next_cell)
                      travelled += boundary_distance
                      result.push(boundary_point)
                      accepted = true
                    }
                  }
                }
              } else {
                attempts = 10
              }
            Some((k2_x, k2_y)) => {
              let corrected_x = direction * step * (k1_x + k2_x) / 2.0
              let corrected_y = direction * step * (k1_y + k2_y) / 2.0
              let error = ((corrected_x - direction * step * k1_x) /
              x_span *
              ((corrected_x - direction * step * k1_x) / x_span) +
              (corrected_y - direction * step * k1_y) /
              y_span *
              ((corrected_y - direction * step * k1_y) / y_span)).sqrt()
              if error > max_error && step > 1.0e-12 {
                step = step * 0.5
                attempts += 1
              } else {
                let proposed_length = (corrected_x /
                x_span *
                (corrected_x / x_span) +
                corrected_y / y_span * (corrected_y / y_span)).sqrt()
                let factor = if proposed_length > remaining {
                  remaining / proposed_length
                } else {
                  1.0
                }
                let next_x = x + corrected_x * factor
                let next_y = y + corrected_y * factor
                if !stream_inside(xs, ys, next_x, next_y) {
                  attempts = 10
                } else {
                  let next_point = @core.point(next_x, next_y)
                  let (can_continue, next_cell) = stream_update_mask(
                    next_point, previous_cell, occupancy, touched, mask_width, mask_height,
                    xmin, xmax, ymin, ymax, broken_streamlines,
                  )
                  if !can_continue {
                    attempts = 10
                  } else {
                    x = next_x
                    y = next_y
                    previous_cell = Some(next_cell)
                    travelled += proposed_length * factor
                    result.push(next_point)
                    if error <= 1.0e-12 {
                      step = max_step
                    } else {
                      step = Double::min(
                        max_step,
                        0.85 * step * (max_error / error).sqrt(),
                      )
                    }
                    accepted = true
                    if factor < 1.0 {
                      attempts = 10
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    if !accepted {
      break
    }
  }
  result
}

///|
fn stream_length(
  line : Array[@core.Point],
  x_span : Double,
  y_span : Double,
) -> Double {
  let mut result = 0.0
  for index in 1..<line.length() {
    let dx = (line[index].x() - line[index - 1].x()) / x_span
    let dy = (line[index].y() - line[index - 1].y()) / y_span
    result += (dx * dx + dy * dy).sqrt()
  }
  result
}

///|
fn stream_cell(
  value : Double,
  lower : Double,
  upper : Double,
  cells : Int32,
) -> Int32 {
  if cells <= 1 {
    return 0
  }
  // Matplotlib's DomainMap rounds grid coordinates to the nearest mask
  // coordinate.  The mask coordinate range is 0..(cells - 1), so the
  // right/top boundary maps directly to the final cell.
  let raw = Double::round(
    (value - lower) / (upper - lower) * Double::from_int(cells - 1),
  ).to_int()
  Int32::max(0, Int32::min(cells - 1, raw))
}

///|
fn stream_mask_coordinate(
  index : Int32,
  cells : Int32,
  lower : Double,
  upper : Double,
) -> Double {
  if cells <= 1 {
    (lower + upper) / 2.0
  } else {
    lower +
    (upper - lower) * Double::from_int(index) / Double::from_int(cells - 1)
  }
}

///|
/// Mark one mask cell for the current trajectory.
///
/// The returned boolean says whether integration may continue.  A trajectory
/// may revisit the cell it occupied in its immediately preceding step; an
/// occupied cell belonging to an earlier part of the field terminates a
/// broken streamline.  When broken streamlines are disabled, existing cells
/// are traversable but are not added to the transaction being built.
fn stream_update_mask(
  point : @core.Point,
  previous_cell : Int32?,
  occupancy : Array[Bool],
  touched : Array[Int32],
  mask_width : Int32,
  mask_height : Int32,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
  broken_streamlines : Bool,
) -> (Bool, Int32) {
  let column = stream_cell(point.x(), xmin, xmax, mask_width)
  let row = stream_cell(point.y(), ymin, ymax, mask_height)
  let cell = row * mask_width + column
  if previous_cell is Some(previous) && previous == cell {
    return (true, cell)
  }
  if occupancy[cell] {
    if broken_streamlines {
      return (false, cell)
    }
    return (true, cell)
  }
  occupancy[cell] = true
  touched.push(cell)
  (true, cell)
}

///|
fn undo_stream_mask(occupancy : Array[Bool], touched : Array[Int32]) -> Unit {
  for cell in touched {
    occupancy[cell] = false
  }
  touched.clear()
}

///|
/// Generate mask seeds in the boundary-first spiral used by Matplotlib.
fn stream_seed_points(
  mask_width : Int32,
  mask_height : Int32,
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Array[@core.Point] {
  let result : Array[@core.Point] = Array(capacity=mask_width * mask_height)
  if mask_width <= 1 {
    for row in 0..<mask_height {
      result.push(
        @core.point(
          stream_mask_coordinate(0, mask_width, xmin, xmax),
          stream_mask_coordinate(row, mask_height, ymin, ymax),
        ),
      )
    }
    return result
  }
  if mask_height <= 1 {
    for column in 0..<mask_width {
      result.push(
        @core.point(
          stream_mask_coordinate(column, mask_width, xmin, xmax),
          stream_mask_coordinate(0, mask_height, ymin, ymax),
        ),
      )
    }
    return result
  }
  let mut xfirst = 0
  let mut yfirst = 1
  let mut xlast = mask_width - 1
  let mut ylast = mask_height - 1
  let mut x = 0
  let mut y = 0
  let mut direction = 0
  // 0 = right, 1 = up, 2 = left, 3 = down.
  for _ in 0..<(mask_width * mask_height) {
    result.push(
      @core.point(
        stream_mask_coordinate(x, mask_width, xmin, xmax),
        stream_mask_coordinate(y, mask_height, ymin, ymax),
      ),
    )
    if direction == 0 {
      x += 1
      if x >= xlast {
        xlast -= 1
        direction = 1
      }
    } else if direction == 1 {
      y += 1
      if y >= ylast {
        ylast -= 1
        direction = 2
      }
    } else if direction == 2 {
      x -= 1
      if x <= xfirst {
        xfirst += 1
        direction = 3
      }
    } else {
      y -= 1
      if y <= yfirst {
        yfirst += 1
        direction = 0
      }
    }
  }
  result
}

///|
fn stream_join(
  backward : Array[@core.Point],
  forward : Array[@core.Point],
) -> Array[@core.Point] {
  let result = Array(capacity=backward.length() + forward.length())
  if backward.length() > 0 {
    for index in 0..<backward.length() {
      result.push(backward[backward.length() - index - 1])
    }
  }
  if forward.length() > 1 {
    for index in 1..<forward.length() {
      result.push(forward[index])
    }
  }
  result
}

///|
fn stream_style_at(
  xs : Array[Double],
  ys : Array[Double],
  point : @core.Point,
  linewidth : Double,
  color : String,
  linewidth_grid : Array[Array[Double]]?,
  color_grid : Array[Array[Double]]?,
  color_norm : @colors.ColorNorm?,
  color_map : @colors.ColorMap?,
) -> (String, Double, Double?)? {
  let width = match linewidth_grid {
    None => Some(linewidth)
    Some(values) => stream_sample_scalar(xs, ys, values, point.x(), point.y())
  }
  let line_color = match color_grid {
    None => Some((color, None))
    Some(values) => {
      let value = match
        stream_sample_scalar(xs, ys, values, point.x(), point.y()) {
        Some(value) => value
        None => return None
      }
      match (color_norm, color_map) {
        (Some(norm), Some(cmap)) =>
          stream_color_from_value(value, norm, cmap).map(color => {
            (color, Some(value))
          })
        _ => None
      }
    }
  }
  match (line_color, width) {
    (Some((line_color, color_value)), Some(width)) =>
      Some((line_color, width, color_value))
    _ => None
  }
}

///|
fn stream_line_artists(
  axes : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  line : Array[@core.Point],
  linewidth : Double,
  color : String,
  linewidth_grid : Array[Array[Double]]?,
  color_grid : Array[Array[Double]]?,
  color_norm : @colors.ColorNorm?,
  color_map : @colors.ColorMap?,
  seed_index : Int32,
  series : String,
) -> Array[Artist] {
  let styled = linewidth_grid is Some(_) || color_grid is Some(_)
  let samples : Array[@render.StreamplotDatum?] = []
  let body : Array[(Artist, Int32)] = []
  for index in 1..<line.length() {
    let first = line[index - 1]
    let second = line[index]
    // Keep the old arithmetic used for painting style-grid bodies.
    let midpoint = @core.point(
      (first.x() + second.x()) / 2.0,
      (first.y() + second.y()) / 2.0,
    )
    if styled {
      match
        stream_style_at(
          xs, ys, midpoint, linewidth, color, linewidth_grid, color_grid, color_norm,
          color_map,
        ) {
        Some((line_color, line_width, color_value)) => {
          samples.push(
            streamplot_sample_datum(
              xs,
              ys,
              us,
              vs,
              midpoint,
              index - 1,
              seed_index,
              color_value,
            ),
          )
          body.push(
            (
              Artist::Line(
                [first, second],
                @core.style(line_color, width=line_width),
              ),
              index - 1,
            ),
          )
        }
        None => samples.push(None)
      }
    } else {
      samples.push(
        streamplot_sample_datum(
          xs,
          ys,
          us,
          vs,
          midpoint,
          index - 1,
          seed_index,
          None,
        ),
      )
    }
  }
  if !styled {
    body.push((Artist::Line(line, @core.style(color, width=linewidth)), 0))
  }
  let source = @render.streamplot_hit_data(line, samples)
  let result = []
  for (artist, first_edge) in body {
    guard artist is Artist::Line(points, _) else { continue }
    axes.push_streamplot_owned(
      artist,
      @render.streamplot_body_hit(source, points, first_edge, series),
    )
    result.push(artist)
  }
  result
}

///|
fn streamplot_arrowstyle_valid(value : String) -> Bool {
  value == "-|>" ||
  value == "->" ||
  value == "-" ||
  value == "<-" ||
  value == "<->" ||
  value == "<|-" ||
  value == "<|-|>" ||
  value == "]-" ||
  value == "-[" ||
  value == "]-[" ||
  value == "|-|" ||
  value == "fancy" ||
  value == "simple" ||
  value == "wedge"
}

///|
fn streamplot_error(message~ : String) -> @core.DataError {
  @core.DataError::InvalidStreamplot(message~)
}

///|
fn resolve_stream_color_map(
  name : String,
) -> @colors.ColorMap raise @core.DataError {
  @colors.colormap(name) catch {
    _ => raise streamplot_error(message="unknown streamplot colormap")
  }
}

///|
fn streamplot_norm(
  values : Array[Array[Double]],
  vmin : Double?,
  vmax : Double?,
) -> @colors.ColorNorm raise @core.DataError {
  let finite_values = stream_grid_values(values)
  if finite_values.length() == 0 {
    raise streamplot_error(
      message="streamplot color values must contain finite data",
    )
  }
  let mut lower = match vmin {
    Some(value) => value
    None => finite_values[0]
  }
  let mut upper = match vmax {
    Some(value) => value
    None => finite_values[0]
  }
  if vmin is None || vmax is None {
    for value in finite_values {
      if vmin is None {
        lower = Double::min(lower, value)
      }
      if vmax is None {
        upper = Double::max(upper, value)
      }
    }
  }
  if !stream_finite(lower) || !stream_finite(upper) || lower > upper {
    raise streamplot_error(
      message="streamplot color bounds must be finite and ordered",
    )
  }
  @colors.ColorNorm::Linear(
    @colors.normalize(vmin=lower, vmax=upper) catch {
      _ => raise streamplot_error(message="invalid streamplot color bounds")
    },
  )
}

///|
fn add_streamlines(
  axes : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  density_x : Double,
  density_y : Double,
  linewidth : Double,
  max_steps : Int32,
  minlength : Double,
  maxlength : Double,
  start_points : Array[@core.Point],
  integration_direction : String,
  color : String,
  arrows : Bool,
  arrow_size : Double,
  arrowstyle : String,
  num_arrows : Int32,
  broken_streamlines : Bool,
  integration_max_step_scale : Double,
  integration_max_error_scale : Double,
  linewidth_grid : Array[Array[Double]]?,
  color_grid : Array[Array[Double]]?,
  color_norm : @colors.ColorNorm?,
  color_map : @colors.ColorMap?,
  series : String,
) -> StreamplotSet raise @core.DataError {
  let x_span = xs[xs.length() - 1] - xs[0]
  let y_span = ys[ys.length() - 1] - ys[0]
  let mask_width = Int32::max(1, (30.0 * density_x).to_int())
  let mask_height = Int32::max(1, (30.0 * density_y).to_int())
  let occupancy : Array[Bool] = Array(capacity=mask_width * mask_height)
  for _ in 0..<(mask_width * mask_height) {
    occupancy.push(false)
  }
  let lines : Array[Artist] = []
  let arrows_result : Array[Artist] = []
  let seeds = if start_points.length() > 0 {
    start_points.copy()
  } else {
    stream_seed_points(
      mask_width,
      mask_height,
      xs[0],
      xs[xs.length() - 1],
      ys[0],
      ys[ys.length() - 1],
    )
  }
  let directional_maxlength = if integration_direction == "both" {
    maxlength / 2.0
  } else {
    maxlength
  }
  for seed_index, seed in seeds {
    let touched : Array[Int32] = []
    let (seed_can_continue, _) = stream_update_mask(
      seed,
      None,
      occupancy,
      touched,
      mask_width,
      mask_height,
      xs[0],
      xs[xs.length() - 1],
      ys[0],
      ys[ys.length() - 1],
      broken_streamlines,
    )
    if !seed_can_continue {
      continue
    }
    let backward = if integration_direction == "forward" {
      [seed]
    } else {
      integrate_stream(
        xs,
        ys,
        us,
        vs,
        seed.x(),
        seed.y(),
        -1.0,
        max_steps,
        x_span,
        y_span,
        directional_maxlength,
        mask_width,
        mask_height,
        integration_max_step_scale,
        integration_max_error_scale,
        occupancy,
        touched,
        broken_streamlines,
        xs[0],
        xs[xs.length() - 1],
        ys[0],
        ys[ys.length() - 1],
      )
    }
    let forward = if integration_direction == "backward" {
      [seed]
    } else {
      integrate_stream(
        xs,
        ys,
        us,
        vs,
        seed.x(),
        seed.y(),
        1.0,
        max_steps,
        x_span,
        y_span,
        directional_maxlength,
        mask_width,
        mask_height,
        integration_max_step_scale,
        integration_max_error_scale,
        occupancy,
        touched,
        broken_streamlines,
        xs[0],
        xs[xs.length() - 1],
        ys[0],
        ys[ys.length() - 1],
      )
    }
    let line = stream_join(backward, forward)
    if line.length() >= 2 && stream_length(line, x_span, y_span) >= minlength {
      let line_artists = stream_line_artists(
        axes, xs, ys, us, vs, line, linewidth, color, linewidth_grid, color_grid,
        color_norm, color_map, seed_index, series,
      )
      for artist in line_artists {
        lines.push(artist)
      }
      if arrows {
        let arrow_artists = add_stream_arrows(
          axes, line, num_arrows, color, linewidth, arrow_size, arrowstyle, x_span,
          y_span, xs, ys, linewidth_grid, color_grid, color_norm, color_map, series,
        )
        for artist in arrow_artists {
          arrows_result.push(artist)
        }
      }
    } else {
      // A short trajectory must not reserve mask cells for later seeds.
      undo_stream_mask(occupancy, touched)
    }
  }
  streamplot_set(lines, arrows_result)
}

///|
fn validate_streamplot_inputs(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  density : Double,
  density_x : Double,
  density_y : Double,
  linewidth : Double,
  max_steps : Int32,
  minlength : Double,
  maxlength : Double,
  start_points : Array[@core.Point],
  integration_direction : String,
  num_arrows : Int32,
  integration_max_step_scale : Double,
  integration_max_error_scale : Double,
  arrow_size : Double,
  arrowstyle : String,
  linewidth_grid : Array[Array[Double]]?,
  color_grid : Array[Array[Double]]?,
) -> Unit raise @core.DataError {
  validate_stream_axis(xs, "x")
  validate_stream_axis(ys, "y")
  validate_stream_field(us, ys.length(), xs.length(), "u")
  validate_stream_field(vs, ys.length(), xs.length(), "v")
  if !stream_finite(density) || density <= 0.0 {
    raise streamplot_error(
      message="streamplot density must be finite and positive",
    )
  }
  if (
      !stream_finite(density_x) ||
      density_x == 0.0 ||
      (density_x < 0.0 && density_x != -1.0)
    ) ||
    !stream_finite(density_y) ||
    density_y == 0.0 ||
    (density_y < 0.0 && density_y != -1.0) {
    raise streamplot_error(
      message="streamplot density_x and density_y must be positive",
    )
  }
  if !stream_finite(linewidth) || linewidth < 0.0 {
    raise streamplot_error(
      message="streamplot linewidth must be finite and non-negative",
    )
  }
  if max_steps < 2 {
    raise streamplot_error(message="streamplot max_steps must be at least two")
  }
  if !stream_finite(minlength) || minlength < 0.0 {
    raise streamplot_error(
      message="streamplot minlength must be finite and non-negative",
    )
  }
  if !stream_finite(maxlength) || maxlength <= 0.0 {
    raise streamplot_error(
      message="streamplot maxlength must be finite and positive",
    )
  }
  if integration_direction != "both" &&
    integration_direction != "forward" &&
    integration_direction != "backward" {
    raise streamplot_error(
      message="streamplot integration_direction must be both, forward, or backward",
    )
  }
  for point in start_points {
    if !point.is_finite() || !stream_inside(xs, ys, point.x(), point.y()) {
      raise streamplot_error(
        message="streamplot start_points must be finite and inside the grid",
      )
    }
  }
  if num_arrows < 0 {
    raise streamplot_error(message="streamplot num_arrows must be non-negative")
  }
  if !stream_finite(integration_max_step_scale) ||
    integration_max_step_scale <= 0.0 {
    raise streamplot_error(
      message="streamplot integration_max_step_scale must be positive",
    )
  }
  if !stream_finite(integration_max_error_scale) ||
    integration_max_error_scale <= 0.0 {
    raise streamplot_error(
      message="streamplot integration_max_error_scale must be positive",
    )
  }
  if !stream_finite(arrow_size) || arrow_size < 0.0 {
    raise streamplot_error(
      message="streamplot arrow_size must be finite and non-negative",
    )
  }
  if !streamplot_arrowstyle_valid(arrowstyle) {
    raise streamplot_error(
      message="streamplot arrowstyle is not a supported FancyArrowPatch style",
    )
  }
  match linewidth_grid {
    Some(values) =>
      stream_validate_style_grid(
        values,
        ys.length(),
        xs.length(),
        "linewidth",
        false,
      )
    None => ()
  }
  match color_grid {
    Some(values) =>
      stream_validate_style_grid(
        values,
        ys.length(),
        xs.length(),
        "color",
        true,
      )
    None => ()
  }
}

///|
fn Axes::streamplot_impl(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  density : Double,
  density_x : Double,
  density_y : Double,
  color : String,
  linewidth : Double,
  max_steps : Int32,
  minlength : Double,
  start_points : Array[@core.Point],
  maxlength : Double,
  integration_direction : String,
  broken_streamlines : Bool,
  integration_max_step_scale : Double,
  integration_max_error_scale : Double,
  arrows : Bool,
  arrow_size : Double,
  arrowstyle : String,
  num_arrows : Int32,
  label : String,
  linewidth_grid : Array[Array[Double]]?,
  color_grid : Array[Array[Double]]?,
  cmap : String?,
  vmin : Double?,
  vmax : Double?,
) -> StreamplotSet raise @core.DataError {
  validate_streamplot_inputs(
    xs, ys, us, vs, density, density_x, density_y, linewidth, max_steps, minlength,
    maxlength, start_points, integration_direction, num_arrows, integration_max_step_scale,
    integration_max_error_scale, arrow_size, arrowstyle, linewidth_grid, color_grid,
  )
  let (color_norm, color_map) = match color_grid {
    None => (None, None)
    Some(values) => {
      let map_name = match cmap {
        Some(value) => value
        None => "viridis"
      }
      (
        Some(streamplot_norm(values, vmin, vmax)),
        Some(resolve_stream_color_map(map_name)),
      )
    }
  }
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  let result = add_streamlines(
    self,
    xs,
    ys,
    us,
    vs,
    if density_x < 0.0 {
      density
    } else {
      density_x
    },
    if density_y < 0.0 {
      density
    } else {
      density_y
    },
    linewidth,
    max_steps,
    minlength,
    maxlength,
    start_points,
    integration_direction,
    resolved_color,
    arrows,
    arrow_size,
    arrowstyle,
    num_arrows,
    broken_streamlines,
    integration_max_step_scale,
    integration_max_error_scale,
    linewidth_grid,
    color_grid,
    color_norm,
    color_map,
    label,
  )
  self.add_auto_legend(
    label,
    resolved_color,
    LegendKind::Line,
    record_series=self.state.val.artists.length() > start,
  )
  self.add_container(ContainerKind::Streamplot, start, label)
  result
}

///|
/// Draw streamlines for a regular vector field on 1D x/y grids.
pub fn Figure::streamplot(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
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
/// Draw streamlines and optionally vary line width and color over the grid.
///
/// Empty style grids use the scalar `color` and `linewidth` values. Color
/// values are mapped through `cmap` after linear normalization.
pub fn Figure::streamplot_with_style_grids(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  linewidths~ : Array[Array[Double]] = [],
  color_values~ : Array[Array[Double]] = [],
  density~ : Double = 1.0,
  density_x~ : Double = -1.0,
  density_y~ : Double = -1.0,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  cmap~ : String = "viridis",
  vmin? : Double,
  vmax? : Double,
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
  let linewidth_grid = if linewidths.length() == 0 {
    None
  } else {
    Some(linewidths)
  }
  let color_grid = if color_values.length() == 0 {
    None
  } else {
    Some(color_values)
  }
  self
  .axes()
  .streamplot_impl(
    xs,
    ys,
    us,
    vs,
    density,
    density_x,
    density_y,
    color,
    linewidth,
    max_steps,
    minlength,
    start_points,
    maxlength,
    integration_direction,
    broken_streamlines,
    integration_max_step_scale,
    integration_max_error_scale,
    arrows,
    arrow_size,
    arrowstyle,
    num_arrows,
    label,
    linewidth_grid,
    color_grid,
    Some(cmap),
    vmin,
    vmax,
  )
}

///|
/// Draw streamlines and optionally vary line width and color over the grid.
pub fn Axes::streamplot(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
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
  self.streamplot_impl(
    xs,
    ys,
    us,
    vs,
    density,
    density_x,
    density_y,
    color,
    linewidth,
    max_steps,
    minlength,
    start_points,
    maxlength,
    integration_direction,
    broken_streamlines,
    integration_max_step_scale,
    integration_max_error_scale,
    arrows,
    arrow_size,
    arrowstyle,
    num_arrows,
    label,
    None,
    None,
    None,
    None,
    None,
  )
}

///|
/// Draw streamlines with optional grid-valued linewidth and color controls.
pub fn Axes::streamplot_with_style_grids(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  linewidths~ : Array[Array[Double]] = [],
  color_values~ : Array[Array[Double]] = [],
  density~ : Double = 1.0,
  density_x~ : Double = -1.0,
  density_y~ : Double = -1.0,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  cmap~ : String = "viridis",
  vmin? : Double,
  vmax? : Double,
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
  let linewidth_grid = if linewidths.length() == 0 {
    None
  } else {
    Some(linewidths)
  }
  let color_grid = if color_values.length() == 0 {
    None
  } else {
    Some(color_values)
  }
  self.streamplot_impl(
    xs,
    ys,
    us,
    vs,
    density,
    density_x,
    density_y,
    color,
    linewidth,
    max_steps,
    minlength,
    start_points,
    maxlength,
    integration_direction,
    broken_streamlines,
    integration_max_step_scale,
    integration_max_error_scale,
    arrows,
    arrow_size,
    arrowstyle,
    num_arrows,
    label,
    linewidth_grid,
    color_grid,
    Some(cmap),
    vmin,
    vmax,
  )
}
