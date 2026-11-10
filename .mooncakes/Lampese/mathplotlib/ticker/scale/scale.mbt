///|
/// Coordinate scale used by an axis.
pub(all) enum Scale {
  Linear
  Log
  SymLog(linthresh~ : Double, linscale~ : Double, base~ : Double)
  Asinh(linear_width~ : Double)
  Logit(clip~ : Bool)
}

///|
/// Return the ordinary linear scale.
pub fn linear_scale() -> Scale {
  Scale::Linear
}

///|
/// Return a base-ten logarithmic scale.
pub fn log_scale() -> Scale {
  Scale::Log
}

///|
/// Construct base-ten probability geometry. Tick defaults require an explicit
/// locator; the clip mode does not change the strict valid-data domain.
pub fn logit_scale(
  nonpositive~ : String = "mask",
) -> Scale raise @core.DataError {
  match nonpositive {
    "mask" => Scale::Logit(clip=false)
    "clip" => Scale::Logit(clip=true)
    _ =>
      raise @core.DataError::InvalidTicks(
        message="'\{nonpositive}' is not a valid value for nonpositive; supported values are 'mask', 'clip'",
      )
  }
}

///|
/// Construct inverse-hyperbolic-sine coordinate geometry.
/// Source width validation rejects nonpositive values; NaN and positive
/// infinity remain representable. Tick defaults require an explicit locator.
pub fn asinh_scale(linear_width~ : Double = 1.0) -> Scale raise @core.DataError {
  if linear_width <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="Scale parameter 'linear_width' must be strictly positive",
    )
  }
  Scale::Asinh(linear_width~)
}

///|
/// Construct a symmetric logarithmic scale around zero.
pub fn symlog_scale(
  linthresh~ : Double = 1.0,
  linscale~ : Double = 1.0,
  base~ : Double = 10.0,
) -> Scale raise @core.DataError {
  if linthresh <= 0.0 || linthresh.is_nan() || linthresh.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="symlog linthresh must be positive and finite",
    )
  }
  if linscale <= 0.0 || linscale.is_nan() || linscale.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="symlog linscale must be positive and finite",
    )
  }
  if base <= 1.0 || base.is_nan() || base.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="symlog base must be finite and greater than one",
    )
  }
  Scale::SymLog(linthresh~, linscale~, base~)
}

///|
/// Whether this scale uses base-ten logarithmic coordinates.
pub fn Scale::is_log(self : Scale) -> Bool {
  self is Log
}

///|
/// Whether this scale applies a non-linear coordinate transform.
pub fn Scale::is_nonlinear(self : Scale) -> Bool {
  match self {
    Linear => false
    Log | SymLog(..) | Asinh(..) | Logit(..) => true
  }
}

///|
/// Whether this scale is symmetric logarithmic.
pub fn Scale::is_symlog(self : Scale) -> Bool {
  self is SymLog(..)
}

///|
/// Whether this scale uses inverse-hyperbolic-sine coordinates.
pub fn Scale::is_asinh(self : Scale) -> Bool {
  self is Asinh(..)
}

///|
/// Whether this scale uses log-odds probability coordinates.
pub fn Scale::is_logit(self : Scale) -> Bool {
  self is Logit(..)
}

///|
/// Return the Logit nonpositive mode, if configured.
pub fn Scale::logit_nonpositive(self : Scale) -> String? {
  match self {
    Logit(clip=true) => Some("clip")
    Logit(clip=false) => Some("mask")
    _ => None
  }
}

///|
/// Return the Asinh coordinate width, if configured.
pub fn Scale::asinh_linear_width(self : Scale) -> Double? {
  match self {
    Asinh(linear_width~) => Some(linear_width)
    _ => None
  }
}

///|
/// Return the symmetric-log linear threshold, if configured.
pub fn Scale::symlog_linthresh(self : Scale) -> Double? {
  match self {
    SymLog(linthresh~, ..) => Some(linthresh)
    _ => None
  }
}

///|
/// Return the symmetric-log base, if configured.
pub fn Scale::symlog_base(self : Scale) -> Double? {
  match self {
    SymLog(base~, ..) => Some(base)
    _ => None
  }
}

///|
fn symlog_linscale_adjusted(linscale : Double, base : Double) -> Double {
  linscale / (1.0 - 1.0 / base)
}

///|
fn symlog_transform_value(
  value : Double,
  linthresh : Double,
  linscale : Double,
  base : Double,
) -> Double {
  let adjusted = symlog_linscale_adjusted(linscale, base)
  let magnitude = Double::abs(value)
  if magnitude <= linthresh {
    value * adjusted
  } else {
    let sign = if value == 0.0 { 0.0 } else if value < 0.0 { -1.0 } else { 1.0 }
    let log_base = @math.ln(base)
    sign *
    linthresh *
    (adjusted - @math.ln(linthresh) / log_base + @math.ln(magnitude) / log_base)
  }
}

///|
fn symlog_inverse_value(
  value : Double,
  linthresh : Double,
  linscale : Double,
  base : Double,
) -> Double {
  let adjusted = symlog_linscale_adjusted(linscale, base)
  let linear_limit = symlog_transform_value(
    linthresh, linthresh, linscale, base,
  )
  let magnitude = Double::abs(value)
  if magnitude <= linear_limit {
    value / adjusted
  } else {
    let sign = if value == 0.0 { 0.0 } else if value < 0.0 { -1.0 } else { 1.0 }
    sign *
    linthresh *
    @math.exp((magnitude / linthresh - adjusted) * @math.ln(base))
  }
}

///|
/// Check whether a data value can be represented on this scale.
pub fn Scale::is_valid(self : Scale, value : Double) -> Bool {
  match self {
    Linear => !value.is_nan() && !value.is_inf()
    Log => value > 0.0 && !value.is_nan() && !value.is_inf()
    SymLog(..) | Asinh(..) => !value.is_nan() && !value.is_inf()
    Logit(..) => value > 0.0 && value < 1.0
  }
}

///|
/// Transform one data value into display-space scale coordinates.
pub fn Scale::transform(self : Scale, value : Double) -> Double {
  match self {
    Linear => value
    Log => @math.log10(value)
    SymLog(linthresh~, linscale~, base~) =>
      symlog_transform_value(value, linthresh, linscale, base)
    Asinh(linear_width~) => linear_width * @math.asinh(value / linear_width)
    Logit(clip~) => {
      let result = @math.log10(value / (1.0 - value))
      if clip && value <= 0.0 {
        -1000.0
      } else if clip && value >= 1.0 {
        1000.0
      } else {
        result
      }
    }
  }
}

///|
/// Convert display-space scale coordinates back to data values.
pub fn Scale::inverse(self : Scale, value : Double) -> Double {
  match self {
    Linear => value
    Log => @math.pow(10.0, value)
    SymLog(linthresh~, linscale~, base~) =>
      symlog_inverse_value(value, linthresh, linscale, base)
    Asinh(linear_width~) => linear_width * @math.sinh(value / linear_width)
    Logit(..) => 1.0 / (1.0 + @math.pow(10.0, -value))
  }
}

///|
/// Apply the scale's source domain restriction using raw minimum-positive data.
/// Finite minpos is preserved, including values outside the usual data domain.
pub fn Scale::limit_range_for_scale(
  self : Scale,
  lower : Double,
  upper : Double,
  minpos : Double,
) -> (Double, Double) {
  match self {
    Linear | SymLog(..) | Asinh(..) => (lower, upper)
    Log => {
      let minpos = if minpos.is_nan() || minpos.is_inf() {
        1.0e-300
      } else {
        minpos
      }
      (
        if lower <= 0.0 {
          minpos
        } else {
          lower
        },
        if upper <= 0.0 {
          minpos
        } else {
          upper
        },
      )
    }
    Logit(..) => {
      let minpos = if minpos.is_nan() || minpos.is_inf() {
        1.0e-7
      } else {
        minpos
      }
      (
        if lower <= 0.0 {
          minpos
        } else {
          lower
        },
        if upper >= 1.0 {
          1.0 - minpos
        } else {
          upper
        },
      )
    }
  }
}

///|
fn symlog_ticks(
  limits : @core.Limits,
  linthresh : Double,
  base : Double,
) -> Array[Double] {
  let lower = Double::min(limits.lower(), limits.upper())
  let upper = Double::max(limits.lower(), limits.upper())
  let values : Array[Double] = []
  if lower <= 0.0 && upper >= 0.0 {
    values.push(0.0)
  }
  if lower <= linthresh && upper >= linthresh {
    values.push(linthresh)
  }
  if lower <= -linthresh && upper >= -linthresh {
    values.push(-linthresh)
  }
  let positive_upper = Double::max(upper, linthresh)
  let positive_lower = Double::max(linthresh, 0.0)
  if positive_upper > positive_lower {
    let first = (@math.log10(positive_lower) / @math.log10(base))
      .floor()
      .to_int()
    let last = (@math.log10(positive_upper) / @math.log10(base)).ceil().to_int()
    for exponent in first..<=last {
      let value = @math.pow(base, Double::from_int(exponent))
      if value >= lower && value <= upper {
        values.push(value)
      }
      if -value >= lower && -value <= upper {
        values.push(-value)
      }
    }
  }
  values.sort()
  if limits.lower() <= limits.upper() {
    values
  } else {
    values.rev()
  }
}

///|
fn linear_ticks(limits : @core.Limits, count : Int32) -> Array[Double] {
  if limits.lower() == limits.upper() {
    return [limits.lower()]
  }
  let actual = if count < 2 { 2 } else { count }
  let step = (limits.upper() - limits.lower()) / Double::from_int(actual - 1)
  let values = Array(capacity=actual)
  for i in 0..<actual {
    values.push(limits.lower() + Double::from_int(i) * step)
  }
  values
}

///|
// Display-uniform convenience grids, independent from named locator policies.
fn nonlinear_display_ticks(
  scale : Scale,
  limits : @core.Limits,
  count : Int32,
) -> Array[Double] {
  let lower = limits.lower()
  let upper = limits.upper()
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    return []
  }
  if scale.is_logit() && (!scale.is_valid(lower) || !scale.is_valid(upper)) {
    return []
  }
  let transformed_lower = scale.transform(lower)
  let transformed_upper = scale.transform(upper)
  if transformed_lower.is_nan() ||
    transformed_lower.is_inf() ||
    transformed_upper.is_nan() ||
    transformed_upper.is_inf() {
    return []
  }
  if lower == upper {
    return [lower]
  }
  let actual = if count < 2 { 2 } else { count }
  let returned = Int32::min(actual, 100000)
  let denominator = Double::from_int(actual - 1)
  let delta = transformed_upper - transformed_lower
  let result = Array(capacity=returned)
  for index in 0..<returned {
    let value = if index == 0 {
      lower
    } else if index == actual - 1 {
      upper
    } else {
      let fraction = Double::from_int(index) / denominator
      let transformed = if delta.is_inf() {
        transformed_lower * (1.0 - fraction) + transformed_upper * fraction
      } else {
        transformed_lower + fraction * delta
      }
      scale.inverse(transformed)
    }
    if value.is_nan() || value.is_inf() {
      return []
    }
    if scale.is_logit() && !scale.is_valid(value) {
      return []
    }
    result.push(value)
  }
  result
}

///|
fn log_ticks(limits : @core.Limits, count : Int32) -> Array[Double] {
  ignore(count)
  let lower = Double::min(limits.lower(), limits.upper())
  let upper = Double::max(limits.lower(), limits.upper())
  if lower <= 0.0 ||
    upper <= 0.0 ||
    lower.is_nan() ||
    upper.is_nan() ||
    lower.is_inf() ||
    upper.is_inf() {
    return []
  }
  if lower == upper {
    return [lower]
  }
  let first = @math.log10(lower).floor().to_int()
  let last = @math.log10(upper).ceil().to_int()
  let decades = last - first
  let values = Array(
    capacity=if decades <= 2 { (decades + 1) * 9 } else { decades + 1 },
  )
  if decades <= 2 {
    for exponent in first..<=last {
      let base = @math.pow(10.0, Double::from_int(exponent))
      for mantissa in 1..<=9 {
        let value = base * Double::from_int(mantissa)
        if value >= lower && value <= upper {
          values.push(value)
        }
      }
    }
  } else {
    for exponent in first..<=last {
      let value = @math.pow(10.0, Double::from_int(exponent))
      if value >= lower && value <= upper {
        values.push(value)
      }
    }
  }
  if limits.lower() <= limits.upper() {
    values
  } else {
    values.rev()
  }
}

///|
/// Generate deterministic convenience ticks for this scale.
/// Asinh and Logit use display-uniform samplers; explicitly install a named
/// locator for the corresponding source locator's rounding and count policy.
pub fn Scale::tick_values(
  self : Scale,
  limits : @core.Limits,
  count~ : Int32 = 6,
) -> Array[Double] {
  match self {
    Linear => linear_ticks(limits, count)
    Log => log_ticks(limits, count)
    SymLog(linthresh~, linscale~, base~) => {
      ignore(linscale)
      symlog_ticks(limits, linthresh, base)
    }
    Asinh(..) | Logit(..) => nonlinear_display_ticks(self, limits, count)
  }
}

///|
/// Format one scale tick using a stable decimal representation.
pub fn Scale::format_tick(self : Scale, value : Double) -> String {
  ignore(self)
  Double::to_string(value)
}
