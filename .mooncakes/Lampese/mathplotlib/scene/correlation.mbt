///|
/// Lags and values returned by `acorr` or `xcorr`.
pub struct Correlation {
  lags : Array[Double]
  values : Array[Double]
}

///|
/// Leave correlation samples unchanged while returning an owned copy.
///
/// This is the default detrending function for `acorr` and `xcorr`.
pub fn detrend_none(values : Array[Double]) -> Array[Double] {
  values.copy()
}

///|
/// Remove the arithmetic mean from correlation samples.
///
/// The returned array always has the same length as the input. Empty input is
/// returned unchanged; the correlation entry points reject empty samples
/// before invoking this function.
pub fn detrend_mean(values : Array[Double]) -> Array[Double] {
  if values.length() == 0 {
    return []
  }
  let mut total = 0.0
  for value in values {
    total += value
  }
  let mean = total / Double::from_int(values.length())
  values.map(value => value - mean)
}

///|
/// Remove the least-squares line from correlation samples.
///
/// The sample index (`0 .. n - 1`) is used as the independent variable. For
/// fewer than two samples the input is returned unchanged.
pub fn detrend_linear(values : Array[Double]) -> Array[Double] {
  if values.length() < 2 {
    return values.copy()
  }
  let count = Double::from_int(values.length())
  let x_mean = (count - 1.0) / 2.0
  let mut y_total = 0.0
  for value in values {
    y_total += value
  }
  let y_mean = y_total / count
  let mut covariance = 0.0
  let mut variance = 0.0
  for index in 0..<values.length() {
    let x = Double::from_int(index)
    let dx = x - x_mean
    covariance += dx * (values[index] - y_mean)
    variance += dx * dx
  }
  let slope = if variance == 0.0 { 0.0 } else { covariance / variance }
  let intercept = y_mean - slope * x_mean
  let result = Array(capacity=values.length())
  for index in 0..<values.length() {
    let x = Double::from_int(index)
    result.push(values[index] - (slope * x + intercept))
  }
  result
}

///|
pub fn Correlation::lags(self : Correlation) -> Array[Double] {
  self.lags.copy()
}

///|
pub fn Correlation::values(self : Correlation) -> Array[Double] {
  self.values.copy()
}

///|
fn validate_correlation_values(
  values : Array[Double],
  name : String,
) -> Unit raise @core.DataError {
  if values.length() == 0 {
    raise @core.DataError::InvalidStatistics(
      message="correlation \{name} must contain at least one value",
    )
  }
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidStatistics(
        message="correlation values must be finite",
      )
    }
  }
}

///|
fn apply_detrend(
  values : Array[Double],
  detrend : (Array[Double]) -> Array[Double],
  name : String,
) -> Array[Double] raise @core.DataError {
  let result = detrend(values.copy())
  if result.length() != values.length() {
    raise @core.DataError::LengthMismatch(
      expected=values.length(),
      actual=result.length(),
    )
  }
  validate_correlation_values(result, name)
  result
}

///|
fn correlation_result(
  first : Array[Double],
  second : Array[Double],
  maxlags : Int32,
  normed : Bool,
  detrend : (Array[Double]) -> Array[Double],
) -> Correlation raise @core.DataError {
  validate_correlation_values(first, "first")
  validate_correlation_values(second, "second")
  if first.length() != second.length() {
    raise @core.DataError::LengthMismatch(
      expected=first.length(),
      actual=second.length(),
    )
  }
  if maxlags < 0 {
    raise @core.DataError::InvalidStatistics(
      message="correlation maxlags must be non-negative",
    )
  }
  let detrended_first = apply_detrend(first, detrend, "first")
  let detrended_second = apply_detrend(second, detrend, "second")
  let count = detrended_first.length()
  let actual_maxlags = Int32::min(maxlags, count - 1)
  let denominator = if normed {
    let mut first_sum = 0.0
    let mut second_sum = 0.0
    for value in detrended_first {
      first_sum += value * value
    }
    for value in detrended_second {
      second_sum += value * value
    }
    (first_sum * second_sum).sqrt()
  } else {
    1.0
  }
  let lags = Array(capacity=actual_maxlags * 2 + 1)
  let values = Array(capacity=actual_maxlags * 2 + 1)
  for offset in 0..<(actual_maxlags * 2 + 1) {
    let lag = offset - actual_maxlags
    let first_start = if lag >= 0 { lag } else { 0 }
    let second_start = if lag >= 0 { 0 } else { -lag }
    let overlap = count - Int32::abs(lag)
    let mut value = 0.0
    for index in 0..<overlap {
      value += detrended_first[first_start + index] *
        detrended_second[second_start + index]
    }
    let normalized = if normed && denominator != 0.0 {
      value / denominator
    } else if normed {
      0.0
    } else {
      value
    }
    lags.push(Double::from_int(lag))
    values.push(normalized)
  }
  { lags, values, }
}

///|
fn draw_correlation(
  axes : Axes,
  result : Correlation,
  usevlines : Bool,
  color : String,
  label : String,
) -> Unit raise @core.DataError {
  let resolved_color = axes.resolve_color(color)
  if usevlines {
    for index in 0..<result.lags.length() {
      let current_label = if index == 0 { label } else { "" }
      axes.vlines(
        [result.lags[index]],
        0.0,
        result.values[index],
        color=resolved_color,
        label=current_label,
      )
    }
    axes.axhline(0.0, color=resolved_color)
  } else {
    let points = Array(capacity=result.lags.length())
    for index in 0..<result.lags.length() {
      points.push(@core.point(result.lags[index], result.values[index]))
    }
    axes.push_artist(Artist::Line(points, @core.style(resolved_color)))
    axes.add_auto_legend(label, resolved_color, LegendKind::Line)
  }
}

///|
/// Plot and return a normalized autocorrelation sequence.
///
/// `detrend` receives an owned copy of the samples and must return an array of
/// the same length. Use `detrend_mean` for the common mean-removal case.
pub fn Figure::acorr(
  self : Figure,
  values : Array[Double],
  normed~ : Bool = true,
  usevlines~ : Bool = true,
  maxlags~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
  detrend~ : (Array[Double]) -> Array[Double] = detrend_none,
) -> Correlation raise @core.DataError {
  self
  .axes()
  .acorr(values, normed~, usevlines~, maxlags~, color~, label~, detrend~)
}

///|
/// Plot and return a normalized autocorrelation sequence.
///
/// `detrend` receives an owned copy of the samples and must return an array of
/// the same length. Use `detrend_mean` for the common mean-removal case.
pub fn Axes::acorr(
  self : Axes,
  values : Array[Double],
  normed~ : Bool = true,
  usevlines~ : Bool = true,
  maxlags~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
  detrend~ : (Array[Double]) -> Array[Double] = detrend_none,
) -> Correlation raise @core.DataError {
  let result = correlation_result(values, values, maxlags, normed, detrend)
  draw_correlation(self, result, usevlines, color, label)
  result
}

///|
/// Plot and return a normalized cross-correlation sequence.
///
/// The same detrending function is applied independently to both input
/// sequences before correlation.
pub fn Figure::xcorr(
  self : Figure,
  first : Array[Double],
  second : Array[Double],
  normed~ : Bool = true,
  usevlines~ : Bool = true,
  maxlags~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
  detrend~ : (Array[Double]) -> Array[Double] = detrend_none,
) -> Correlation raise @core.DataError {
  self
  .axes()
  .xcorr(first, second, normed~, usevlines~, maxlags~, color~, label~, detrend~)
}

///|
/// Plot and return a normalized cross-correlation sequence.
///
/// The same detrending function is applied independently to both input
/// sequences before correlation.
pub fn Axes::xcorr(
  self : Axes,
  first : Array[Double],
  second : Array[Double],
  normed~ : Bool = true,
  usevlines~ : Bool = true,
  maxlags~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
  detrend~ : (Array[Double]) -> Array[Double] = detrend_none,
) -> Correlation raise @core.DataError {
  let result = correlation_result(first, second, maxlags, normed, detrend)
  draw_correlation(self, result, usevlines, color, label)
  result
}
