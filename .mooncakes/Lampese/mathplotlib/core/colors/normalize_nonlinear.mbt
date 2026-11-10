///|
/// Construct a symmetric-log normalization around zero.
///
/// `linthresh` controls the linear region around zero. `linscale` controls
/// the visual width of that region and `base` controls the logarithmic
/// decades outside it. Missing bounds are filled by `autoscale_none`.
pub fn symlog_norm(
  linthresh : Double,
  linscale~ : Double = 1.0,
  vmin? : Double,
  vmax? : Double,
  clip~ : Bool = false,
  base~ : Double = 10.0,
) -> SymLogNorm raise NormalizeError {
  validate_bounds(vmin, vmax)
  validate_symlog_parameters(linthresh, linscale, base)
  { vmin, vmax, clip, linthresh, linscale, base, }
}

///|
/// Construct a two-slope normalization with `vcenter` mapped to 0.5.
pub fn two_slope_norm(
  vcenter : Double,
  vmin? : Double,
  vmax? : Double,
) -> TwoSlopeNorm raise NormalizeError {
  if !finite(vcenter) {
    raise NormalizeError::InvalidBounds(message="vcenter must be finite")
  }
  validate_bounds(vmin, vmax)
  validate_two_slope_bounds(vcenter, vmin, vmax)
  { vmin, vmax, vcenter, }
}

///|
/// Return the linear threshold used by the symmetric-log transform.
pub fn SymLogNorm::linthresh(self : SymLogNorm) -> Double {
  self.linthresh
}

///|
/// Return the linear-region scale used by the symmetric-log transform.
pub fn SymLogNorm::linscale(self : SymLogNorm) -> Double {
  self.linscale
}

///|
/// Return the logarithm base used by the symmetric-log transform.
pub fn SymLogNorm::base(self : SymLogNorm) -> Double {
  self.base
}

///|
/// Return the lower data bound, if one has been set.
pub fn SymLogNorm::vmin(self : SymLogNorm) -> Double? {
  self.vmin
}

///|
/// Return the upper data bound, if one has been set.
pub fn SymLogNorm::vmax(self : SymLogNorm) -> Double? {
  self.vmax
}

///|
/// Return whether values outside the bounds are clipped.
pub fn SymLogNorm::clip(self : SymLogNorm) -> Bool {
  self.clip
}

///|
/// Set the lower data bound.
pub fn SymLogNorm::set_vmin(
  self : SymLogNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(value, self.vmax)
  self.vmin = value
}

///|
/// Set the upper data bound.
pub fn SymLogNorm::set_vmax(
  self : SymLogNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(self.vmin, value)
  self.vmax = value
}

///|
/// Set the clipping mode.
pub fn SymLogNorm::set_clip(self : SymLogNorm, value : Bool) -> Unit {
  self.clip = value
}

///|
/// Return whether both symmetric-log bounds are set.
pub fn SymLogNorm::scaled(self : SymLogNorm) -> Bool {
  self.vmin is Some(_) && self.vmax is Some(_)
}

///|
/// Set both bounds to the finite minimum and maximum in `values`.
pub fn SymLogNorm::autoscale(
  self : SymLogNorm,
  values : Array[Double],
) -> Unit raise NormalizeError {
  match finite_bounds(values) {
    Some((lower, upper)) => {
      self.vmin = Some(lower)
      self.vmax = Some(upper)
    }
    None => raise NormalizeError::NoFiniteData
  }
}

///|
/// Fill only missing symmetric-log bounds from finite values.
pub fn SymLogNorm::autoscale_none(
  self : SymLogNorm,
  values : Array[Double],
) -> Unit {
  match finite_bounds(values) {
    Some((lower, upper)) => {
      if self.vmin is None {
        self.vmin = Some(lower)
      }
      if self.vmax is None {
        self.vmax = Some(upper)
      }
    }
    None => ()
  }
}

///|
/// Return whether a value can be represented by this normalization.
pub fn SymLogNorm::is_valid(self : SymLogNorm, value : Double) -> Bool {
  ignore(self)
  finite(value)
}

///|
/// Transform one finite scalar to symmetric-log color space.
pub fn SymLogNorm::transform(
  self : SymLogNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !self.is_valid(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return 0.0
  }
  let transformed_lower = symlog_transform_value(
    lower,
    self.linthresh,
    self.linscale,
    self.base,
  )
  let transformed_upper = symlog_transform_value(
    upper,
    self.linthresh,
    self.linscale,
    self.base,
  )
  let transformed_value = symlog_transform_value(
    value,
    self.linthresh,
    self.linscale,
    self.base,
  )
  clamp_normalized(
    (transformed_value - transformed_lower) /
    (transformed_upper - transformed_lower),
    self.clip,
  )
}

///|
/// Fill missing bounds and transform every finite value.
pub fn SymLogNorm::transform_array(
  self : SymLogNorm,
  values : Array[Double],
) -> Array[Double] raise NormalizeError {
  self.autoscale_none(values)
  let result = Array(capacity=values.length())
  for value in values {
    if finite(value) {
      result.push(self.transform(value))
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Convert one normalized value back to symmetric-log data space.
pub fn SymLogNorm::inverse(
  self : SymLogNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !finite(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return lower
  }
  let transformed_lower = symlog_transform_value(
    lower,
    self.linthresh,
    self.linscale,
    self.base,
  )
  let transformed_upper = symlog_transform_value(
    upper,
    self.linthresh,
    self.linscale,
    self.base,
  )
  symlog_inverse_value(
    transformed_lower + value * (transformed_upper - transformed_lower),
    self.linthresh,
    self.linscale,
    self.base,
  )
}

///|
/// Return the center value mapped to 0.5.
pub fn TwoSlopeNorm::vcenter(self : TwoSlopeNorm) -> Double {
  self.vcenter
}

///|
/// Return the lower data bound, if one has been set.
pub fn TwoSlopeNorm::vmin(self : TwoSlopeNorm) -> Double? {
  self.vmin
}

///|
/// Return the upper data bound, if one has been set.
pub fn TwoSlopeNorm::vmax(self : TwoSlopeNorm) -> Double? {
  self.vmax
}

///|
/// Set the lower data bound while preserving the center ordering.
pub fn TwoSlopeNorm::set_vmin(
  self : TwoSlopeNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(value, self.vmax)
  validate_two_slope_bounds(self.vcenter, value, self.vmax)
  self.vmin = value
}

///|
/// Set the upper data bound while preserving the center ordering.
pub fn TwoSlopeNorm::set_vmax(
  self : TwoSlopeNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(self.vmin, value)
  validate_two_slope_bounds(self.vcenter, self.vmin, value)
  self.vmax = value
}

///|
/// Return whether both two-slope bounds are set.
pub fn TwoSlopeNorm::scaled(self : TwoSlopeNorm) -> Bool {
  self.vmin is Some(_) && self.vmax is Some(_)
}

///|
/// Set both bounds to finite data bounds, including the center when needed.
pub fn TwoSlopeNorm::autoscale(
  self : TwoSlopeNorm,
  values : Array[Double],
) -> Unit raise NormalizeError {
  match finite_bounds(values) {
    Some((lower, upper)) => {
      self.vmin = Some(Double::min(lower, self.vcenter))
      self.vmax = Some(Double::max(upper, self.vcenter))
    }
    None => raise NormalizeError::NoFiniteData
  }
}

///|
/// Fill missing two-slope bounds from finite values and include the center.
pub fn TwoSlopeNorm::autoscale_none(
  self : TwoSlopeNorm,
  values : Array[Double],
) -> Unit {
  match finite_bounds(values) {
    Some((lower, upper)) => {
      if self.vmin is None {
        self.vmin = Some(Double::min(lower, self.vcenter))
      }
      if self.vmax is None {
        self.vmax = Some(Double::max(upper, self.vcenter))
      }
    }
    None => ()
  }
}

///|
/// Return whether a value can be represented by this normalization.
pub fn TwoSlopeNorm::is_valid(self : TwoSlopeNorm, value : Double) -> Bool {
  ignore(self)
  finite(value)
}

///|
/// Transform one finite scalar with the center at 0.5.
pub fn TwoSlopeNorm::transform(
  self : TwoSlopeNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !self.is_valid(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return 0.0
  }
  if value == self.vcenter {
    return 0.5
  }
  if value < self.vcenter && lower < self.vcenter {
    0.5 * (value - lower) / (self.vcenter - lower)
  } else if value > self.vcenter && upper > self.vcenter {
    0.5 + 0.5 * (value - self.vcenter) / (upper - self.vcenter)
  } else if value < self.vcenter {
    0.0
  } else {
    1.0
  }
}

///|
/// Fill missing bounds and transform every finite value.
pub fn TwoSlopeNorm::transform_array(
  self : TwoSlopeNorm,
  values : Array[Double],
) -> Array[Double] raise NormalizeError {
  self.autoscale_none(values)
  let result = Array(capacity=values.length())
  for value in values {
    if finite(value) {
      result.push(self.transform(value))
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Convert one normalized value back to two-slope data space.
pub fn TwoSlopeNorm::inverse(
  self : TwoSlopeNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !finite(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return lower
  }
  if value <= 0.5 && lower < self.vcenter {
    lower + 2.0 * value * (self.vcenter - lower)
  } else if value >= 0.5 && upper > self.vcenter {
    self.vcenter + 2.0 * (value - 0.5) * (upper - self.vcenter)
  } else if value < 0.5 {
    self.vcenter
  } else {
    self.vcenter
  }
}

///|
/// Construct a power-law normalization.
pub fn power_norm(
  gamma : Double,
  vmin? : Double,
  vmax? : Double,
  clip~ : Bool = false,
) -> PowerNorm raise NormalizeError {
  validate_bounds(vmin, vmax)
  if !finite(gamma) || gamma <= 0.0 {
    raise NormalizeError::InvalidBounds(
      message="gamma must be finite and positive",
    )
  }
  { vmin, vmax, clip, gamma, }
}

///|
/// Return the exponent used by the power-law normalization.
pub fn PowerNorm::gamma(self : PowerNorm) -> Double {
  self.gamma
}

///|
/// Return the lower data bound, if one has been set.
pub fn PowerNorm::vmin(self : PowerNorm) -> Double? {
  self.vmin
}

///|
/// Return the upper data bound, if one has been set.
pub fn PowerNorm::vmax(self : PowerNorm) -> Double? {
  self.vmax
}

///|
/// Return whether values outside the bounds are clipped.
pub fn PowerNorm::clip(self : PowerNorm) -> Bool {
  self.clip
}

///|
/// Set the lower data bound.
pub fn PowerNorm::set_vmin(
  self : PowerNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(value, self.vmax)
  self.vmin = value
}

///|
/// Set the upper data bound.
pub fn PowerNorm::set_vmax(
  self : PowerNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(self.vmin, value)
  self.vmax = value
}

///|
/// Set the clipping mode.
pub fn PowerNorm::set_clip(self : PowerNorm, value : Bool) -> Unit {
  self.clip = value
}

///|
/// Return whether both power-law bounds are set.
pub fn PowerNorm::scaled(self : PowerNorm) -> Bool {
  self.vmin is Some(_) && self.vmax is Some(_)
}

///|
/// Set both bounds to the finite minimum and maximum in `values`.
pub fn PowerNorm::autoscale(
  self : PowerNorm,
  values : Array[Double],
) -> Unit raise NormalizeError {
  match finite_bounds(values) {
    Some((lower, upper)) => {
      self.vmin = Some(lower)
      self.vmax = Some(upper)
    }
    None => raise NormalizeError::NoFiniteData
  }
}

///|
/// Fill only missing power-law bounds from finite values.
pub fn PowerNorm::autoscale_none(
  self : PowerNorm,
  values : Array[Double],
) -> Unit {
  match finite_bounds(values) {
    Some((lower, upper)) => {
      if self.vmin is None {
        self.vmin = Some(lower)
      }
      if self.vmax is None {
        self.vmax = Some(upper)
      }
    }
    None => ()
  }
}

///|
/// Return whether a value can be represented by this normalization.
pub fn PowerNorm::is_valid(self : PowerNorm, value : Double) -> Bool {
  ignore(self)
  finite(value)
}

///|
/// Transform one finite scalar with a power-law color scale.
pub fn PowerNorm::transform(
  self : PowerNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !self.is_valid(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return 0.0
  }
  let shifted = Double::max(value - lower, 0.0)
  let denominator = upper - lower
  let result = @math.pow(shifted, self.gamma) /
    @math.pow(denominator, self.gamma)
  clamp_normalized(result, self.clip)
}

///|
/// Fill missing bounds and transform every finite value.
pub fn PowerNorm::transform_array(
  self : PowerNorm,
  values : Array[Double],
) -> Array[Double] raise NormalizeError {
  self.autoscale_none(values)
  let result = Array(capacity=values.length())
  for value in values {
    if finite(value) {
      result.push(self.transform(value))
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Convert one normalized value back to power-law data space.
pub fn PowerNorm::inverse(
  self : PowerNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !finite(value) || value < 0.0 {
    raise NormalizeError::InvalidValue(
      message="inverse power-normalized values must be finite and non-negative",
    )
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return lower
  }
  lower + @math.pow(value, 1.0 / self.gamma) * (upper - lower)
}

///|
/// Construct a centered normalization around `vcenter`.
pub fn centered_norm(
  vcenter~ : Double = 0.0,
  halfrange? : Double,
  clip~ : Bool = false,
) -> CenteredNorm raise NormalizeError {
  if !finite(vcenter) {
    raise NormalizeError::InvalidBounds(message="vcenter must be finite")
  }
  match halfrange {
    Some(value) =>
      if !finite(value) || value < 0.0 {
        raise NormalizeError::InvalidBounds(
          message="halfrange must be finite and non-negative",
        )
      }
    None => ()
  }
  let (vmin, vmax) = match halfrange {
    Some(value) => (Some(vcenter - value), Some(vcenter + value))
    None => (None, None)
  }
  { vmin, vmax, halfrange, clip, vcenter, }
}

///|
/// Return the center value mapped to 0.5.
pub fn CenteredNorm::vcenter(self : CenteredNorm) -> Double {
  self.vcenter
}

///|
/// Set the center while preserving a configured half-range.
pub fn CenteredNorm::set_vcenter(
  self : CenteredNorm,
  value : Double,
) -> Unit raise NormalizeError {
  if !finite(value) {
    raise NormalizeError::InvalidBounds(message="vcenter must be finite")
  }
  self.vcenter = value
  match self.halfrange {
    Some(range) => {
      self.vmin = Some(value - range)
      self.vmax = Some(value + range)
    }
    None => ()
  }
}

///|
/// Return the configured symmetric half-range, if one has been set.
pub fn CenteredNorm::halfrange(self : CenteredNorm) -> Double? {
  self.halfrange
}

///|
/// Set the symmetric half-range and update both bounds.
pub fn CenteredNorm::set_halfrange(
  self : CenteredNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  match value {
    Some(range) =>
      if !finite(range) || range < 0.0 {
        raise NormalizeError::InvalidBounds(
          message="halfrange must be finite and non-negative",
        )
      }
    None => ()
  }
  self.halfrange = value
  match value {
    Some(range) => {
      self.vmin = Some(self.vcenter - range)
      self.vmax = Some(self.vcenter + range)
    }
    None => {
      self.vmin = None
      self.vmax = None
    }
  }
}

///|
/// Return the clipping mode.
pub fn CenteredNorm::clip(self : CenteredNorm) -> Bool {
  self.clip
}

///|
/// Set the clipping mode.
pub fn CenteredNorm::set_clip(self : CenteredNorm, value : Bool) -> Unit {
  self.clip = value
}

///|
/// Return the lower data bound, if one has been set.
pub fn CenteredNorm::vmin(self : CenteredNorm) -> Double? {
  self.vmin
}

///|
/// Return the upper data bound, if one has been set.
pub fn CenteredNorm::vmax(self : CenteredNorm) -> Double? {
  self.vmax
}

///|
/// Return whether both centered bounds are set.
pub fn CenteredNorm::scaled(self : CenteredNorm) -> Bool {
  self.vmin is Some(_) && self.vmax is Some(_)
}

///|
/// Set the half-range to the largest finite distance from the center.
pub fn CenteredNorm::autoscale(
  self : CenteredNorm,
  values : Array[Double],
) -> Unit raise NormalizeError {
  let mut maximum : Double? = None
  for value in values {
    if finite(value) {
      let distance = Double::abs(value - self.vcenter)
      maximum = match maximum {
        Some(current) => Some(Double::max(current, distance))
        None => Some(distance)
      }
    }
  }
  match maximum {
    Some(range) => self.set_halfrange(Some(range))
    None => raise NormalizeError::NoFiniteData
  }
}

///|
/// Fill an unset half-range from finite values.
pub fn CenteredNorm::autoscale_none(
  self : CenteredNorm,
  values : Array[Double],
) -> Unit {
  if self.halfrange is None {
    let mut maximum : Double? = None
    for value in values {
      if finite(value) {
        let distance = Double::abs(value - self.vcenter)
        maximum = match maximum {
          Some(current) => Some(Double::max(current, distance))
          None => Some(distance)
        }
      }
    }
    match maximum {
      Some(range) => {
        self.halfrange = Some(range)
        self.vmin = Some(self.vcenter - range)
        self.vmax = Some(self.vcenter + range)
      }
      None => ()
    }
  }
}

///|
/// Return whether a value can be represented by this normalization.
pub fn CenteredNorm::is_valid(self : CenteredNorm, value : Double) -> Bool {
  ignore(self)
  finite(value)
}

///|
/// Transform one finite scalar using a symmetric center and half-range.
pub fn CenteredNorm::transform(
  self : CenteredNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !self.is_valid(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  if lower == upper {
    return 0.0
  }
  clamp_normalized((value - lower) / (upper - lower), self.clip)
}

///|
/// Fill a missing half-range and transform every finite value.
pub fn CenteredNorm::transform_array(
  self : CenteredNorm,
  values : Array[Double],
) -> Array[Double] raise NormalizeError {
  self.autoscale_none(values)
  let result = Array(capacity=values.length())
  for value in values {
    if finite(value) {
      result.push(self.transform(value))
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Convert one normalized scalar back to centered data space.
pub fn CenteredNorm::inverse(
  self : CenteredNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !finite(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let lower = match self.vmin {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  let upper = match self.vmax {
    Some(value) => value
    None => raise NormalizeError::NotScaled
  }
  lower + value * (upper - lower)
}

///|
fn validate_symlog_parameters(
  linthresh : Double,
  linscale : Double,
  base : Double,
) -> Unit raise NormalizeError {
  if !finite(linthresh) || linthresh <= 0.0 {
    raise NormalizeError::InvalidBounds(
      message="linthresh must be finite and positive",
    )
  }
  if !finite(linscale) || linscale <= 0.0 {
    raise NormalizeError::InvalidBounds(
      message="linscale must be finite and positive",
    )
  }
  if !finite(base) || base <= 1.0 {
    raise NormalizeError::InvalidBase(
      message="base must be finite and greater than 1",
    )
  }
}

///|
fn validate_two_slope_bounds(
  vcenter : Double,
  vmin : Double?,
  vmax : Double?,
) -> Unit raise NormalizeError {
  match vmin {
    Some(value) =>
      if value >= vcenter {
        raise NormalizeError::InvalidBounds(
          message="vmin must be less than vcenter",
        )
      }
    None => ()
  }
  match vmax {
    Some(value) =>
      if value <= vcenter {
        raise NormalizeError::InvalidBounds(
          message="vmax must be greater than vcenter",
        )
      }
    None => ()
  }
}

///|
fn finite_bounds(values : Array[Double]) -> (Double, Double)? {
  let mut minimum : Double? = None
  let mut maximum : Double? = None
  for value in values {
    if finite(value) {
      match minimum {
        None => {
          minimum = Some(value)
          maximum = Some(value)
        }
        Some(current) => {
          minimum = Some(Double::min(current, value))
          maximum = Some(Double::max(maximum.unwrap(), value))
        }
      }
    }
  }
  match (minimum, maximum) {
    (Some(lower), Some(upper)) => Some((lower, upper))
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
    let sign = if value < 0.0 { -1.0 } else { 1.0 }
    sign *
    linthresh *
    (adjusted + @math.log10(magnitude / linthresh) / @math.log10(base))
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
  let linear_limit = linthresh * adjusted
  let magnitude = Double::abs(value)
  if magnitude <= linear_limit {
    value / adjusted
  } else {
    let sign = if value < 0.0 { -1.0 } else { 1.0 }
    sign * linthresh * @math.pow(base, magnitude / linthresh - adjusted)
  }
}
