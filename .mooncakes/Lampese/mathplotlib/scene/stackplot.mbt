///|
// Validate the input shared by all stackplot baseline algorithms.
fn validate_stackplot_input(
  xs : Array[Double],
  ys : Array[Array[Double]],
  labels : Array[String],
  baseline : String,
) -> Unit raise @core.DataError {
  if xs.is_empty() {
    raise @core.DataError::InvalidReference(
      message="stackplot requires at least one x value",
    )
  }
  if ys.is_empty() {
    raise @core.DataError::InvalidReference(
      message="stackplot requires at least one y series",
    )
  }
  if labels.length() != 0 && labels.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=ys.length(),
      actual=labels.length(),
    )
  }
  if baseline != "zero" &&
    baseline != "sym" &&
    baseline != "wiggle" &&
    baseline != "weighted_wiggle" {
    raise @core.DataError::InvalidReference(
      message="stackplot baseline must be zero, sym, wiggle, or weighted_wiggle",
    )
  }
  for value in xs {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidReference(
        message="stackplot x values must be finite",
      )
    }
  }
  for row in ys {
    if row.length() != xs.length() {
      raise @core.DataError::LengthMismatch(
        expected=xs.length(),
        actual=row.length(),
      )
    }
    for value in row {
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidReference(
          message="stackplot y values must be finite",
        )
      }
    }
  }
}

///|
fn stackplot_zeroes(length : Int32) -> Array[Double] {
  let result = Array(capacity=length)
  for _ in 0..<length {
    result.push(0.0)
  }
  result
}

///|
// Build cumulative upper boundaries without mutating caller-owned data.
fn stackplot_cumulative(ys : Array[Array[Double]]) -> Array[Array[Double]] {
  let length = ys[0].length()
  let cumulative = stackplot_zeroes(length)
  let result : Array[Array[Double]] = []
  for row in ys {
    let upper = Array(capacity=length)
    for index in 0..<length {
      cumulative[index] += row[index]
      upper.push(cumulative[index])
    }
    result.push(upper)
  }
  result
}

///|
fn stackplot_first_line(
  ys : Array[Array[Double]],
  stacked : Array[Array[Double]],
  baseline : String,
) -> Array[Double] {
  let rows = ys.length()
  let length = ys[0].length()
  let result = stackplot_zeroes(length)
  if baseline == "zero" {
    return result
  }
  if baseline == "sym" {
    for index in 0..<length {
      result[index] = -0.5 * stacked[rows - 1][index]
    }
    return result
  }
  if baseline == "wiggle" {
    let row_count = Double::from_int(rows)
    for index in 0..<length {
      let mut weighted = 0.0
      for row_index in 0..<rows {
        weighted += ys[row_index][index] *
          (row_count - 0.5 - Double::from_int(row_index))
      }
      result[index] = weighted / -row_count
    }
    return result
  }
  // Matplotlib's weighted_wiggle baseline. `center` is the cumulative
  // movement of the streamgraph's center line along the x direction.
  let mut center = 0.0
  for index in 0..<length {
    let total = stacked[rows - 1][index]
    let inverse_total = if total > 0.0 { 1.0 / total } else { 0.0 }
    let mut movement = 0.0
    for row_index in 0..<rows {
      let below_size = total -
        stacked[row_index][index] +
        0.5 * ys[row_index][index]
      let move_up = if index == 0 { 0.5 } else { below_size * inverse_total }
      let increase = if index == 0 {
        ys[row_index][index]
      } else {
        ys[row_index][index] - ys[row_index][index - 1]
      }
      movement += (move_up - 0.5) * increase
    }
    center += movement
    result[index] = center - 0.5 * total
  }
  result
}

///|
fn stackplot_label(labels : Array[String], index : Int32) -> String {
  if labels.is_empty() {
    ""
  } else {
    labels[index]
  }
}

///|
fn Axes::add_stackplot_layer(
  self : Axes,
  xs : Array[Double],
  lower : Array[Double],
  upper : Array[Double],
  color : String,
  label : String,
  values : Array[Double],
) -> Artist {
  let lower_points = Array(capacity=xs.length())
  let upper_points = Array(capacity=xs.length())
  for index in 0..<xs.length() {
    lower_points.push(@core.point(xs[index], lower[index]))
    upper_points.push(@core.point(xs[index], upper[index]))
  }
  let artist = Artist::FillBetween(
    upper_points,
    lower_points,
    @core.style(color, width=0.0, fill=color),
  )
  self.push_artist(artist)
  self.record_band(false, values=Some(values))
  self.add_auto_legend(label, color, LegendKind::Patch)
  artist
}

///|
/// Draw a stacked area plot and return one filled artist per input series.
///
/// `baseline` accepts `"zero"`, `"sym"`, `"wiggle"`, or
/// `"weighted_wiggle"`. Colors cycle when fewer colors than series are given;
/// an empty color array uses the axes property cycle.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let artists = try! fig.stackplot(
///     [0.0, 1.0, 2.0],
///     [[1.0, 2.0, 1.0], [2.0, 1.0, 2.0]],
///     colors=["#123456", "#abcdef"],
///   )
///   assert_eq(artists.length(), 2)
///   assert_eq(fig.artists().length(), 2)
/// }
/// ```
pub fn Figure::stackplot(
  self : Figure,
  xs : Array[Double],
  ys : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  baseline~ : String = "zero",
) -> Array[Artist] raise @core.DataError {
  self.axes().stackplot(xs, ys, labels~, colors~, baseline~)
}

///|
/// Draw a stacked area plot through the axes handle.
pub fn Axes::stackplot(
  self : Axes,
  xs : Array[Double],
  ys : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  baseline~ : String = "zero",
) -> Array[Artist] raise @core.DataError {
  validate_stackplot_input(xs, ys, labels, baseline)
  let stacked = stackplot_cumulative(ys)
  let first_line = stackplot_first_line(ys, stacked, baseline)
  let start = self.state.val.artists.length()
  let mut lower = first_line.copy()
  let result : Array[Artist] = []
  for row_index in 0..<ys.length() {
    let upper = Array(capacity=xs.length())
    for index in 0..<xs.length() {
      upper.push(first_line[index] + stacked[row_index][index])
    }
    let requested_color = if colors.is_empty() {
      ""
    } else {
      colors[row_index % colors.length()]
    }
    let color = self.resolve_color(requested_color)
    let artist = self.add_stackplot_layer(
      xs,
      lower,
      upper,
      color,
      stackplot_label(labels, row_index),
      ys[row_index],
    )
    result.push(copy_artist(artist))
    lower = upper
  }
  let container_label = if labels.is_empty() { "" } else { labels[0] }
  self.add_container(ContainerKind::Stackplot, start, container_label)
  result
}
