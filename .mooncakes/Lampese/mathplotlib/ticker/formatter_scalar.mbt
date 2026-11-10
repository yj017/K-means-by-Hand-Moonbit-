// Adapted from Matplotlib v3.11.2 ScalarFormatter; see docs/licenses/LICENSE-MATPLOTLIB
// and docs/THIRD_PARTY_NOTICES.md. Python state and NumPy operations are replaced
// by an immutable layout computed for each MoonBit tick list and viewport.

///|
priv struct ScalarLayout {
  offset : Double
  exponent : Int32
  precision : Int32
}

///|
fn scalar_layout(
  values : Array[Double],
  view : @core.Limits?,
  use_offset : Bool,
  power_min : Int32,
  power_max : Int32,
) -> ScalarLayout {
  let (lower, upper) = formatter_extent(values, view)
  let visible = values.filter(value => {
    !value.is_nan() && !value.is_inf() && value >= lower && value <= upper
  })
  let offset = if use_offset { scalar_offset(visible) } else { 0.0 }
  let exponent = scalar_order(
    visible,
    upper - lower,
    offset,
    power_min,
    power_max,
  )
  let scaled = values
    .filter(value => !value.is_nan() && !value.is_inf())
    .map(value => divide_decimal(value - offset, exponent))
  let span_values = scaled.copy()
  if scaled.length() < 2 {
    span_values.push(divide_decimal(lower - offset, exponent))
    span_values.push(divide_decimal(upper - offset, exponent))
  }
  let precision = scalar_precision(scaled, span_values)
  { offset, exponent, precision, }
}

///|
/// A finite viewport or, when none is supplied, the finite tick extent.
fn formatter_extent(
  values : Array[Double],
  view : @core.Limits?,
) -> (Double, Double) {
  if view is Some(limits) && limits.is_finite() {
    return (
      Double::min(limits.lower(), limits.upper()),
      Double::max(limits.lower(), limits.upper()),
    )
  }
  let mut extent : (Double, Double)? = None
  for value in values {
    if value.is_nan() || value.is_inf() {
      continue
    }
    extent = Some(
      match extent {
        None => (value, value)
        Some((lower, upper)) =>
          (Double::min(lower, value), Double::max(upper, value))
      },
    )
  }
  extent.unwrap_or((0.0, 0.0))
}

///|
/// Divide by a decimal power without constructing an underflowed 10^-324.
fn divide_decimal(value : Double, exponent : Int32) -> Double {
  if exponent < -308 {
    value * 1.0e308 / @math.pow(10.0, (exponent + 308).to_double())
  } else if exponent > 308 {
    value / 1.0e308 / @math.pow(10.0, (exponent - 308).to_double())
  } else {
    value / @math.pow(10.0, exponent.to_double())
  }
}

///|
/// Additive offset selection is independent of scientific power limits.
fn scalar_offset(values : Array[Double]) -> Double {
  let (lower, upper) = formatter_extent(values, None)
  if lower == upper || (lower <= 0.0 && upper >= 0.0) {
    return 0.0
  }
  let abs_min = Double::min(Double::abs(lower), Double::abs(upper))
  let abs_max = Double::max(Double::abs(lower), Double::abs(upper))
  let sign = if lower < 0.0 { -1.0 } else { 1.0 }
  let top_order = decimal_exponent(abs_max) + 1
  let mut order = top_order
  while order > -324 &&
        divide_decimal(abs_min, order).floor() ==
        divide_decimal(abs_max, order).floor() {
    order -= 1
  }
  order += 1
  if divide_decimal(abs_max - abs_min, order) <= 1.0e-2 {
    order = top_order
    while order > -324 &&
          divide_decimal(abs_max, order).floor() -
          divide_decimal(abs_min, order).floor() <=
          1.0 {
      order -= 1
    }
    order += 1
  }
  let prefix = divide_decimal(abs_max, order).floor()
  // rcParams["axes.formatter.offset_threshold"] defaults to 4.
  if prefix < 1000.0 {
    return 0.0
  }
  let offset = sign * divide_decimal(prefix, -order)
  if offset.is_inf() || offset.is_nan() {
    0.0
  } else {
    offset
  }
}

///|
fn scalar_order(
  visible : Array[Double],
  display_range : Double,
  offset : Double,
  power_min : Int32,
  power_max : Int32,
) -> Int32 {
  if visible.is_empty() {
    return 0
  }
  if power_min == power_max && power_min != 0 {
    return power_min
  }
  let mut magnitude = 0.0
  for value in visible {
    magnitude = Double::max(magnitude, Double::abs(value))
  }
  if offset != 0.0 && display_range > 0.0 {
    magnitude = display_range
  }
  let exponent = if magnitude == 0.0 { 0 } else { decimal_exponent(magnitude) }
  if exponent <= power_min || exponent >= power_max {
    exponent
  } else {
    0
  }
}

///|
fn scalar_precision(
  scaled : Array[Double],
  span_values : Array[Double],
) -> Int32 {
  let (lower, upper) = formatter_extent(span_values, None)
  let mut span = upper - lower
  if span == 0.0 {
    span = Double::max(Double::abs(lower), Double::abs(upper))
  }
  if span == 0.0 || span.is_inf() {
    span = 1.0
  }
  let order = decimal_exponent(span)
  let mut places = Int32::max(0, Int32::min(100, 3 - order))
  let threshold = 1.0e-3 * @math.pow(10.0, order.to_double())
  while places >= 0 {
    let mut max_error = 0.0
    for value in scaled {
      if value.is_nan() || value.is_inf() {
        continue
      }
      let rounded = try! @string.parse_double(format_fixed(value, places)[:])
      max_error = Double::max(max_error, Double::abs(value - rounded))
    }
    if max_error < threshold {
      places -= 1
    } else {
      break
    }
  }
  Int32::min(100, places + 1)
}

///|
fn ScalarLayout::labels(
  self : ScalarLayout,
  values : Array[Double],
) -> Array[String] {
  values.map(value => {
    if numeric_special(value) is Some(text) {
      return text
    }
    let residual = divide_decimal(value - self.offset, self.exponent)
    let cleaned = if Double::abs(residual) < 1.0e-8 { 0.0 } else { residual }
    format_fixed(cleaned, self.precision)
  })
}
