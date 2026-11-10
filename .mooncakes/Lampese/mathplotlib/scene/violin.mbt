///|
/// Bandwidth rules used by the Gaussian kernel density estimate.
pub(all) enum ViolinBandwidth {
  Scott
  Silverman
  Fixed(Double)
}

///|
/// Select which side of a violin body is filled around its position.
pub(all) enum ViolinSide {
  Both
  Low
  High
}

///|
/// Kernel-density and summary statistics used to draw one violin.
pub struct ViolinStats {
  coords : Array[Double]
  vals : Array[Double]
  mean : Double
  median : Double
  min : Double
  max : Double
  quantiles : Array[Double]
}

///|
fn violin_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn violin_sorted(values : Array[Double]) -> Array[Double] {
  let result = Array(capacity=values.length())
  for value in values {
    if violin_finite(value) {
      result.push(value)
    }
  }
  result.sort()
  result
}

///|
fn violin_percentile(values : Array[Double], fraction : Double) -> Double {
  let position = fraction * Double::from_int(values.length() - 1)
  let lower = position.floor().to_int()
  let upper = position.ceil().to_int()
  if lower == upper {
    values[lower]
  } else {
    let weight = position - Double::from_int(lower)
    values[lower] + (values[upper] - values[lower]) * weight
  }
}

///|
fn violin_quantiles(
  sorted : Array[Double],
  requested : Array[Double],
) -> Array[Double] raise @core.DataError {
  let result = Array(capacity=requested.length())
  for fraction in requested {
    if fraction.is_nan() ||
      fraction.is_inf() ||
      fraction < 0.0 ||
      fraction > 1.0 {
      raise @core.DataError::InvalidViolin(
        message="violin quantiles must be in the interval [0, 1]",
      )
    }
    if sorted.length() == 0 {
      result.push(0.0 / 0.0)
    } else {
      result.push(violin_percentile(sorted, fraction))
    }
  }
  result
}

///|
fn violin_validate_bandwidth(
  bandwidth_method : ViolinBandwidth,
) -> Unit raise @core.DataError {
  match bandwidth_method {
    ViolinBandwidth::Scott | ViolinBandwidth::Silverman => ()
    ViolinBandwidth::Fixed(value) =>
      if value <= 0.0 || value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidViolin(
          message="fixed violin bandwidth must be positive and finite",
        )
      }
  }
}

///|
fn violin_bandwidth(
  sorted : Array[Double],
  bandwidth_method : ViolinBandwidth,
  lower : Double,
  upper : Double,
) -> Double raise @core.DataError {
  violin_validate_bandwidth(bandwidth_method)
  let n = Double::from_int(sorted.length())
  let mut mean = 0.0
  for value in sorted {
    mean += value
  }
  mean /= n
  let mut variance = 0.0
  if sorted.length() > 1 {
    for value in sorted {
      let delta = value - mean
      variance += delta * delta
    }
    variance /= Double::from_int(sorted.length() - 1)
  }
  let deviation = variance.sqrt()
  let factor = match bandwidth_method {
    ViolinBandwidth::Scott => @math.pow(n, -0.2)
    ViolinBandwidth::Silverman => @math.pow(n * 0.75, -0.2)
    ViolinBandwidth::Fixed(value) => value
  }
  let mut result = deviation * factor
  if result <= 0.0 || result.is_nan() || result.is_inf() {
    result = (upper - lower) / 6.0
  }
  if result <= 0.0 || result.is_nan() || result.is_inf() {
    result = 1.0
  }
  result
}

///|
fn violin_density(
  sorted : Array[Double],
  coords : Array[Double],
  bandwidth : Double,
) -> Array[Double] {
  let result = Array(capacity=coords.length())
  let normalizer = Double::from_int(sorted.length()) *
    bandwidth *
    (2.0 * 3.141592653589793).sqrt()
  for coordinate in coords {
    let mut density = 0.0
    for value in sorted {
      let distance = (coordinate - value) / bandwidth
      density += @math.exp(-0.5 * distance * distance)
    }
    result.push(density / normalizer)
  }
  result
}

///|
/// Compute the statistics and Gaussian density for one violin series.
pub fn violin_stats(
  values : Array[Double],
  points~ : Int32 = 100,
  bandwidth~ : ViolinBandwidth = ViolinBandwidth::Scott,
  quantiles~ : Array[Double] = [],
) -> ViolinStats raise @core.DataError {
  if points < 2 {
    raise @core.DataError::InvalidViolin(
      message="violin points must be at least 2",
    )
  }
  violin_validate_bandwidth(bandwidth)
  let sorted = violin_sorted(values)
  if sorted.length() == 0 {
    let requested_quantiles = violin_quantiles(sorted, quantiles)
    let nan = 0.0 / 0.0
    {
      coords: [],
      vals: [],
      mean: nan,
      median: nan,
      min: nan,
      max: nan,
      quantiles: requested_quantiles,
    }
  } else {
    let min = sorted[0]
    let max = sorted[sorted.length() - 1]
    let mean = sorted.fold(init=0.0, (total, value) => total + value) /
      Double::from_int(sorted.length())
    let median = violin_percentile(sorted, 0.5)
    let requested_quantiles = violin_quantiles(sorted, quantiles)
    let lower = if min == max { min - 0.5 } else { min }
    let upper = if min == max { max + 0.5 } else { max }
    let coords = Array(capacity=points)
    for index in 0..<points {
      let fraction = Double::from_int(index) / Double::from_int(points - 1)
      coords.push(lower + (upper - lower) * fraction)
    }
    let density = violin_density(
      sorted,
      coords,
      violin_bandwidth(sorted, bandwidth, lower, upper),
    )
    {
      coords,
      vals: density,
      mean,
      median,
      min,
      max,
      quantiles: requested_quantiles,
    }
  }
}

///|
/// Return the coordinates sampled by the density estimate.
pub fn ViolinStats::coords(self : ViolinStats) -> Array[Double] {
  self.coords.copy()
}

///|
/// Return the density values sampled at `coords`.
pub fn ViolinStats::vals(self : ViolinStats) -> Array[Double] {
  self.vals.copy()
}

///|
pub fn ViolinStats::mean(self : ViolinStats) -> Double {
  self.mean
}

///|
pub fn ViolinStats::median(self : ViolinStats) -> Double {
  self.median
}

///|
pub fn ViolinStats::min(self : ViolinStats) -> Double {
  self.min
}

///|
pub fn ViolinStats::max(self : ViolinStats) -> Double {
  self.max
}

///|
pub fn ViolinStats::quantiles(self : ViolinStats) -> Array[Double] {
  self.quantiles.copy()
}

///|
fn violin_quantiles_for(
  quantiles : Array[Array[Double]],
  index : Int32,
  count : Int32,
) -> Array[Double] raise @core.DataError {
  if quantiles.length() == 0 {
    []
  } else if quantiles.length() == 1 && count == 1 {
    quantiles[0].copy()
  } else if quantiles.length() == count {
    quantiles[index].copy()
  } else {
    raise @core.DataError::InvalidViolin(
      message="quantiles must have one entry per violin",
    )
  }
}

///|
fn violin_positions(
  count : Int32,
  positions : Array[Double],
) -> Array[Double] raise @core.DataError {
  if positions.length() == 0 {
    let result = Array(capacity=count)
    for index in 0..<count {
      result.push(Double::from_int(index + 1))
    }
    result
  } else {
    if positions.length() != count {
      raise @core.DataError::LengthMismatch(
        expected=count,
        actual=positions.length(),
      )
    }
    for value in positions {
      if !violin_finite(value) {
        raise @core.DataError::NonFiniteLimit(axis="position")
      }
    }
    positions.copy()
  }
}

///|
fn violin_widths(
  count : Int32,
  width : Double,
  widths : Array[Double],
) -> Array[Double] raise @core.DataError {
  if width.is_nan() || width.is_inf() || width <= 0.0 {
    raise @core.DataError::InvalidViolin(
      message="violin width must be positive and finite",
    )
  }
  if widths.length() == 0 {
    let result = Array(capacity=count)
    for _ in 0..<count {
      result.push(width)
    }
    result
  } else {
    if widths.length() != count {
      raise @core.DataError::LengthMismatch(
        expected=count,
        actual=widths.length(),
      )
    }
    for value in widths {
      if value.is_nan() || value.is_inf() || value <= 0.0 {
        raise @core.DataError::InvalidViolin(
          message="violin widths must be positive and finite",
        )
      }
    }
    widths.copy()
  }
}

///|
/// Draw violins from precomputed density statistics.
pub fn Figure::violin(
  self : Figure,
  stats : Array[ViolinStats],
  positions~ : Array[Double] = [],
  width~ : Double = 0.5,
  widths~ : Array[Double] = [],
  horizontal~ : Bool = false,
  side~ : ViolinSide = ViolinSide::Both,
  showmeans~ : Bool = false,
  showextrema~ : Bool = true,
  showmedians~ : Bool = false,
  color~ : String = "",
  facecolor~ : String = "",
  linecolor~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self
  .axes()
  .violin(
    stats,
    positions~,
    width~,
    widths~,
    horizontal~,
    side~,
    showmeans~,
    showextrema~,
    showmedians~,
    color~,
    facecolor~,
    linecolor~,
    label~,
  )
}

///|
/// Draw violins from precomputed density statistics on this axes panel.
pub fn Axes::violin(
  self : Axes,
  stats : Array[ViolinStats],
  positions~ : Array[Double] = [],
  width~ : Double = 0.5,
  widths~ : Array[Double] = [],
  horizontal~ : Bool = false,
  side~ : ViolinSide = ViolinSide::Both,
  showmeans~ : Bool = false,
  showextrema~ : Bool = true,
  showmedians~ : Bool = false,
  color~ : String = "",
  facecolor~ : String = "",
  linecolor~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if stats.length() == 0 {
    raise @core.DataError::InvalidViolin(
      message="violin requires at least one statistics series",
    )
  }
  let resolved_positions = violin_positions(stats.length(), positions)
  let resolved_widths = violin_widths(stats.length(), width, widths)
  let resolved_color = self.resolve_color(color)
  let body_color = if facecolor == "" { resolved_color } else { facecolor }
  let edge_color = if linecolor == "" { resolved_color } else { linecolor }
  let body_opacity = if facecolor == "" { 0.35 } else { 1.0 }
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::Violin(
      stats.copy(),
      resolved_positions,
      resolved_widths,
      horizontal,
      side,
      showmeans,
      showextrema,
      showmedians,
      @core.style(body_color, width=1.0, fill=body_color),
      @core.style(edge_color, width=1.5),
      body_opacity,
    ),
  )
  self.add_auto_legend(label, edge_color, LegendKind::Patch)
  self.add_container(ContainerKind::Violin, start, label)
}

///|
/// Compute and draw Gaussian kernel-density violins from raw data.
pub fn Figure::violinplot(
  self : Figure,
  data : Array[Array[Double]],
  positions~ : Array[Double] = [],
  width~ : Double = 0.5,
  widths~ : Array[Double] = [],
  horizontal~ : Bool = false,
  side~ : ViolinSide = ViolinSide::Both,
  showmeans~ : Bool = false,
  showextrema~ : Bool = true,
  showmedians~ : Bool = false,
  quantiles~ : Array[Array[Double]] = [],
  points~ : Int32 = 100,
  bandwidth~ : ViolinBandwidth = ViolinBandwidth::Scott,
  color~ : String = "",
  facecolor~ : String = "",
  linecolor~ : String = "",
  label~ : String = "",
) -> Array[ViolinStats] raise @core.DataError {
  self
  .axes()
  .violinplot(
    data,
    positions~,
    width~,
    widths~,
    horizontal~,
    side~,
    showmeans~,
    showextrema~,
    showmedians~,
    quantiles~,
    points~,
    bandwidth~,
    color~,
    facecolor~,
    linecolor~,
    label~,
  )
}

///|
/// Compute and draw Gaussian kernel-density violins from raw data.
pub fn Axes::violinplot(
  self : Axes,
  data : Array[Array[Double]],
  positions~ : Array[Double] = [],
  width~ : Double = 0.5,
  widths~ : Array[Double] = [],
  horizontal~ : Bool = false,
  side~ : ViolinSide = ViolinSide::Both,
  showmeans~ : Bool = false,
  showextrema~ : Bool = true,
  showmedians~ : Bool = false,
  quantiles~ : Array[Array[Double]] = [],
  points~ : Int32 = 100,
  bandwidth~ : ViolinBandwidth = ViolinBandwidth::Scott,
  color~ : String = "",
  facecolor~ : String = "",
  linecolor~ : String = "",
  label~ : String = "",
) -> Array[ViolinStats] raise @core.DataError {
  if data.length() == 0 {
    raise @core.DataError::InvalidViolin(
      message="violinplot requires at least one series",
    )
  }
  let stats = Array(capacity=data.length())
  for index, values in data {
    stats.push(
      violin_stats(
        values,
        points~,
        bandwidth~,
        quantiles=violin_quantiles_for(quantiles, index, data.length()),
      ),
    )
  }
  self.violin(
    stats,
    positions~,
    width~,
    widths~,
    horizontal~,
    side~,
    showmeans~,
    showextrema~,
    showmedians~,
    color~,
    facecolor~,
    linecolor~,
    label~,
  )
  stats
}
