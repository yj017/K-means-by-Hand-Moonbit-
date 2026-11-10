///|
/// Errors raised while constructing or applying a scalar color normalization.
pub(all) suberror NormalizeError {
  InvalidBounds(message~ : String)
  InvalidBase(message~ : String)
  InvalidValue(message~ : String)
  NoFiniteData
  NotScaled
  NotInvertible
}

///|
/// Linearly map scalar values to the interval [0, 1].
///
/// Missing bounds are filled from the first finite data passed to
/// `autoscale_none` or `transform_array`. Values outside the interval are
/// preserved when `clip` is false and clamped when it is true.
pub struct Normalize {
  mut vmin : Double?
  mut vmax : Double?
  mut clip : Bool
}

///|
/// Logarithmically map positive scalar values to the interval [0, 1].
pub struct LogNorm {
  mut vmin : Double?
  mut vmax : Double?
  mut clip : Bool
  base : Double
}

///|
/// Symmetrically logarithmic normalization around zero.
pub struct SymLogNorm {
  mut vmin : Double?
  mut vmax : Double?
  mut clip : Bool
  linthresh : Double
  linscale : Double
  base : Double
}

///|
/// Power-law normalization of non-negative distances from the lower bound.
pub struct PowerNorm {
  mut vmin : Double?
  mut vmax : Double?
  mut clip : Bool
  gamma : Double
}

///|
/// Linear normalization centered on a value with a symmetric half-range.
pub struct CenteredNorm {
  mut vmin : Double?
  mut vmax : Double?
  mut halfrange : Double?
  mut clip : Bool
  mut vcenter : Double
}

///|
/// Linear normalization with a distinguished value mapped to 0.5.
pub struct TwoSlopeNorm {
  mut vmin : Double?
  mut vmax : Double?
  vcenter : Double
}

///|
/// Map scalar values into discrete intervals defined by monotonically
/// increasing boundaries.
pub struct BoundaryNorm {
  boundaries : Array[Double]
  ncolors : Int32
  clip : Bool
  extend_mode : String
}

///|
/// A normalization that can be attached to a scalar image or colorbar.
pub(all) enum ColorNorm {
  Linear(Normalize)
  Logarithmic(LogNorm)
  SymmetricLog(SymLogNorm)
  TwoSlope(TwoSlopeNorm)
  Power(PowerNorm)
  Centered(CenteredNorm)
  Boundary(BoundaryNorm)
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn validate_optional_bound(
  value : Double?,
  name : String,
) -> Unit raise NormalizeError {
  match value {
    Some(value) =>
      if !finite(value) {
        raise NormalizeError::InvalidBounds(message="\{name} must be finite")
      }
    None => ()
  }
}

///|
fn validate_bounds(vmin : Double?, vmax : Double?) -> Unit raise NormalizeError {
  validate_optional_bound(vmin, "vmin")
  validate_optional_bound(vmax, "vmax")
  match (vmin, vmax) {
    (Some(lower), Some(upper)) =>
      if lower > upper {
        raise NormalizeError::InvalidBounds(
          message="vmin must be less than or equal to vmax",
        )
      }
    _ => ()
  }
}

///|
/// Construct a linear normalization.
pub fn normalize(
  vmin? : Double,
  vmax? : Double,
  clip~ : Bool = false,
) -> Normalize raise NormalizeError {
  validate_bounds(vmin, vmax)
  { vmin, vmax, clip, }
}

///|
/// Construct a logarithmic normalization with the given logarithm base.
pub fn log_norm(
  vmin? : Double,
  vmax? : Double,
  clip~ : Bool = false,
  base~ : Double = 10.0,
) -> LogNorm raise NormalizeError {
  validate_bounds(vmin, vmax)
  match vmin {
    Some(value) =>
      if value <= 0.0 {
        raise NormalizeError::InvalidBounds(message="vmin must be positive")
      }
    None => ()
  }
  match vmax {
    Some(value) =>
      if value <= 0.0 {
        raise NormalizeError::InvalidBounds(message="vmax must be positive")
      }
    None => ()
  }
  if !finite(base) || base <= 1.0 {
    raise NormalizeError::InvalidBase(
      message="base must be finite and greater than 1",
    )
  }
  { vmin, vmax, clip, base, }
}

///|
/// Wrap a linear normalization as a polymorphic color normalization.
pub fn linear_color_norm(value : Normalize) -> ColorNorm {
  ColorNorm::Linear(value)
}

///|
/// Wrap a logarithmic normalization as a polymorphic color normalization.
pub fn log_color_norm(value : LogNorm) -> ColorNorm {
  ColorNorm::Logarithmic(value)
}

///|
/// Wrap a symmetric-log normalization as a polymorphic color normalization.
pub fn symlog_color_norm(value : SymLogNorm) -> ColorNorm {
  ColorNorm::SymmetricLog(value)
}

///|
/// Wrap a two-slope normalization as a polymorphic color normalization.
pub fn two_slope_color_norm(value : TwoSlopeNorm) -> ColorNorm {
  ColorNorm::TwoSlope(value)
}

///|
/// Wrap a power-law normalization as a polymorphic color normalization.
pub fn power_color_norm(value : PowerNorm) -> ColorNorm {
  ColorNorm::Power(value)
}

///|
/// Wrap a centered normalization as a polymorphic color normalization.
pub fn centered_color_norm(value : CenteredNorm) -> ColorNorm {
  ColorNorm::Centered(value)
}

///|
/// Construct a discrete boundary normalization.
/// extend_mode maps Matplotlib's extend parameter, avoiding a MoonBit keyword.
pub fn boundary_norm(
  boundaries : Array[Double],
  ncolors : Int32,
  clip~ : Bool = false,
  extend_mode~ : String = "neither",
) -> BoundaryNorm raise NormalizeError {
  if boundaries.length() < 2 {
    raise NormalizeError::InvalidBounds(
      message="boundary norm requires at least two boundaries",
    )
  }
  if ncolors <= 0 {
    raise NormalizeError::InvalidBounds(
      message="boundary norm requires a positive color count",
    )
  }
  if extend_mode != "neither" &&
    extend_mode != "min" &&
    extend_mode != "max" &&
    extend_mode != "both" {
    raise NormalizeError::InvalidBounds(
      message="extend must be neither, min, max, or both",
    )
  }
  if clip && extend_mode != "neither" {
    raise NormalizeError::InvalidBounds(
      message="clip=True is not compatible with extend",
    )
  }
  let extension_count = if extend_mode == "both" {
    2
  } else if extend_mode == "neither" {
    0
  } else {
    1
  }
  if ncolors < boundaries.length() - 1 + extension_count {
    raise NormalizeError::InvalidBounds(
      message="ncolors must equal or exceed the number of boundary bins",
    )
  }
  for index in 0..<boundaries.length() {
    let value = boundaries[index]
    if !finite(value) {
      raise NormalizeError::InvalidBounds(
        message="boundary values must be finite",
      )
    }
    if index > 0 && value <= boundaries[index - 1] {
      raise NormalizeError::InvalidBounds(
        message="boundary values must be strictly increasing",
      )
    }
  }
  { boundaries: boundaries.copy(), ncolors, clip, extend_mode, }
}

///|
/// Wrap a boundary normalization as a polymorphic color normalization.
pub fn boundary_color_norm(value : BoundaryNorm) -> ColorNorm {
  ColorNorm::Boundary(value)
}

///|
/// Return a copy of the boundary values.
pub fn BoundaryNorm::boundaries(self : BoundaryNorm) -> Array[Double] {
  self.boundaries.copy()
}

///|
/// Return the number of color entries addressed by this normalization.
pub fn BoundaryNorm::ncolors(self : BoundaryNorm) -> Int32 {
  self.ncolors
}

///|
/// Return whether values outside the boundary range are clipped.
pub fn BoundaryNorm::clip(self : BoundaryNorm) -> Bool {
  self.clip
}

///|
/// Return the extension mode used by this normalization.
pub fn BoundaryNorm::extend_mode(self : BoundaryNorm) -> String {
  self.extend_mode
}

///|
fn BoundaryNorm::region_count(self : BoundaryNorm) -> Int32 {
  let extension_count = if self.extend_mode == "neither" {
    0
  } else if self.extend_mode == "both" {
    2
  } else {
    1
  }
  self.boundaries.length() - 1 + extension_count
}

///|
fn BoundaryNorm::bin_index(self : BoundaryNorm, value : Double) -> Int32 {
  if value < self.boundaries[0] {
    -1
  } else if value >= self.boundaries[self.boundaries.length() - 1] {
    self.ncolors
  } else {
    let mut result = self.boundaries.length() - 2
    for index in 0..<(self.boundaries.length() - 1) {
      if value < self.boundaries[index + 1] {
        result = index
        break
      }
    }
    let offset = if self.extend_mode == "min" || self.extend_mode == "both" {
      1
    } else {
      0
    }
    result + offset
  }
}

///|
/// Return the integer colormap index selected by a boundary normalization.
/// Values below and above the boundaries return -1 and `ncolors` respectively
/// when clipping is disabled, matching Matplotlib's under/over conventions.
pub fn BoundaryNorm::index(
  self : BoundaryNorm,
  value : Double,
) -> Int32 raise NormalizeError {
  if !finite(value) {
    raise NormalizeError::InvalidValue(message="value must be finite")
  }
  let raw = self.bin_index(value)
  let index = if self.clip {
    Int32::clamp(raw, min=0, max=self.ncolors - 1)
  } else {
    raw
  }
  let regions = self.region_count()
  if index >= 0 && index < regions && self.ncolors > regions {
    if regions == 1 {
      (self.ncolors - 1) / 2
    } else {
      (Double::from_int(self.ncolors - 1) *
      Double::from_int(index) /
      Double::from_int(regions - 1)).to_int()
    }
  } else {
    index
  }
}

///|
/// Transform a scalar to the normalized position of its discrete color index.
pub fn BoundaryNorm::transform(
  self : BoundaryNorm,
  value : Double,
) -> Double raise NormalizeError {
  let index = self.index(value)
  if self.ncolors == 1 {
    0.0
  } else {
    Double::from_int(index) / Double::from_int(self.ncolors - 1)
  }
}

///|
/// Boundary normalization is discrete and cannot be inverted.
pub fn BoundaryNorm::inverse(
  self : BoundaryNorm,
  value : Double,
) -> Double raise NormalizeError {
  ignore(self)
  ignore(value)
  raise NormalizeError::NotInvertible
}

///|
/// Return whether a value is finite and can be normalized.
pub fn BoundaryNorm::is_valid(self : BoundaryNorm, value : Double) -> Bool {
  ignore(self)
  finite(value)
}

///|
/// Boundary normalizations already have fixed bounds; this is a no-op.
pub fn BoundaryNorm::autoscale_none(
  self : BoundaryNorm,
  values : Array[Double],
) -> Unit {
  ignore(self)
  ignore(values)
}

///|
/// Boundary normalizations are always ready to transform values.
pub fn BoundaryNorm::scaled(self : BoundaryNorm) -> Bool {
  ignore(self)
  true
}

///|
/// Return the lower data bound, if one has been set.
pub fn Normalize::vmin(self : Normalize) -> Double? {
  self.vmin
}

///|
/// Return the upper data bound, if one has been set.
pub fn Normalize::vmax(self : Normalize) -> Double? {
  self.vmax
}

///|
/// Return whether values outside the bounds are clipped.
pub fn Normalize::clip(self : Normalize) -> Bool {
  self.clip
}

///|
/// Set the lower data bound.
pub fn Normalize::set_vmin(
  self : Normalize,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(value, self.vmax)
  self.vmin = value
}

///|
/// Set the upper data bound.
pub fn Normalize::set_vmax(
  self : Normalize,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(self.vmin, value)
  self.vmax = value
}

///|
/// Set the clipping mode.
pub fn Normalize::set_clip(self : Normalize, value : Bool) -> Unit {
  self.clip = value
}

///|
/// Return whether both bounds are set.
pub fn Normalize::scaled(self : Normalize) -> Bool {
  self.vmin is Some(_) && self.vmax is Some(_)
}

///|
/// Set both bounds to the finite minimum and maximum in `values`.
pub fn Normalize::autoscale(
  self : Normalize,
  values : Array[Double],
) -> Unit raise NormalizeError {
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
    (Some(lower), Some(upper)) => {
      self.vmin = Some(lower)
      self.vmax = Some(upper)
    }
    _ => raise NormalizeError::NoFiniteData
  }
}

///|
/// Fill only bounds that are not already set from finite values in `values`.
pub fn Normalize::autoscale_none(
  self : Normalize,
  values : Array[Double],
) -> Unit {
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
  if self.vmin is None {
    self.vmin = minimum
  }
  if self.vmax is None {
    self.vmax = maximum
  }
}

///|
fn clamp_normalized(value : Double, clip : Bool) -> Double {
  if clip {
    Double::clamp(value, min=0.0, max=1.0)
  } else {
    value
  }
}

///|
/// Transform one finite scalar to normalized color space.
pub fn Normalize::transform(
  self : Normalize,
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
    return 0.0
  }
  clamp_normalized((value - lower) / (upper - lower), self.clip)
}

///|
/// Fill missing bounds from `values` and transform every value.
pub fn Normalize::transform_array(
  self : Normalize,
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
/// Convert one normalized scalar back to data space.
pub fn Normalize::inverse(
  self : Normalize,
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
/// Return the lower data bound, if one has been set.
pub fn LogNorm::vmin(self : LogNorm) -> Double? {
  self.vmin
}

///|
/// Return the upper data bound, if one has been set.
pub fn LogNorm::vmax(self : LogNorm) -> Double? {
  self.vmax
}

///|
/// Return whether values outside the bounds are clipped.
pub fn LogNorm::clip(self : LogNorm) -> Bool {
  self.clip
}

///|
/// Return the logarithm base.
pub fn LogNorm::base(self : LogNorm) -> Double {
  self.base
}

///|
/// Set the lower data bound.
pub fn LogNorm::set_vmin(
  self : LogNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(value, self.vmax)
  match value {
    Some(value) =>
      if value <= 0.0 {
        raise NormalizeError::InvalidBounds(message="vmin must be positive")
      }
    None => ()
  }
  self.vmin = value
}

///|
/// Set the upper data bound.
pub fn LogNorm::set_vmax(
  self : LogNorm,
  value : Double?,
) -> Unit raise NormalizeError {
  validate_bounds(self.vmin, value)
  match value {
    Some(value) =>
      if value <= 0.0 {
        raise NormalizeError::InvalidBounds(message="vmax must be positive")
      }
    None => ()
  }
  self.vmax = value
}

///|
/// Set the clipping mode.
pub fn LogNorm::set_clip(self : LogNorm, value : Bool) -> Unit {
  self.clip = value
}

///|
/// Return whether both bounds are set.
pub fn LogNorm::scaled(self : LogNorm) -> Bool {
  self.vmin is Some(_) && self.vmax is Some(_)
}

///|
/// Set both bounds to the positive finite minimum and maximum in `values`.
pub fn LogNorm::autoscale(
  self : LogNorm,
  values : Array[Double],
) -> Unit raise NormalizeError {
  let mut minimum : Double? = None
  let mut maximum : Double? = None
  for value in values {
    if finite(value) && value > 0.0 {
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
    (Some(lower), Some(upper)) => {
      self.vmin = Some(lower)
      self.vmax = Some(upper)
    }
    _ => raise NormalizeError::NoFiniteData
  }
}

///|
/// Fill only bounds that are not already set from positive finite values.
pub fn LogNorm::autoscale_none(self : LogNorm, values : Array[Double]) -> Unit {
  let mut minimum : Double? = None
  let mut maximum : Double? = None
  for value in values {
    if finite(value) && value > 0.0 {
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
  if self.vmin is None {
    self.vmin = minimum
  }
  if self.vmax is None {
    self.vmax = maximum
  }
}

///|
/// Return whether a value can be represented by this logarithmic norm.
pub fn LogNorm::is_valid(self : LogNorm, value : Double) -> Bool {
  ignore(self)
  finite(value) && value > 0.0
}

///|
/// Transform one positive finite scalar to logarithmic color space.
pub fn LogNorm::transform(
  self : LogNorm,
  value : Double,
) -> Double raise NormalizeError {
  if !self.is_valid(value) {
    raise NormalizeError::InvalidValue(
      message="logarithmic values must be positive and finite",
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
    return 0.0
  }
  let result = (
      @math.log10(value) / @math.log10(self.base) -
      @math.log10(lower) / @math.log10(self.base)
    ) /
    (
      @math.log10(upper) / @math.log10(self.base) -
      @math.log10(lower) / @math.log10(self.base)
    )
  clamp_normalized(result, self.clip)
}

///|
/// Fill missing bounds from `values` and transform positive values.
pub fn LogNorm::transform_array(
  self : LogNorm,
  values : Array[Double],
) -> Array[Double] raise NormalizeError {
  self.autoscale_none(values)
  let result = Array(capacity=values.length())
  for value in values {
    if self.is_valid(value) {
      result.push(self.transform(value))
    } else {
      result.push(value)
    }
  }
  result
}

///|
/// Convert one normalized scalar back to data space.
pub fn LogNorm::inverse(
  self : LogNorm,
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
  @math.pow(
    self.base,
    @math.log10(lower) / @math.log10(self.base) +
    value *
    (
      @math.log10(upper) / @math.log10(self.base) -
      @math.log10(lower) / @math.log10(self.base)
    ),
  )
}

///|
/// Return the lower data bound, if one has been set.
pub fn ColorNorm::vmin(self : ColorNorm) -> Double? {
  match self {
    Linear(value) => value.vmin()
    Logarithmic(value) => value.vmin()
    SymmetricLog(value) => value.vmin()
    TwoSlope(value) => value.vmin()
    Power(value) => value.vmin()
    Centered(value) => value.vmin()
    Boundary(value) => Some(value.boundaries[0])
  }
}

///|
/// Return the upper data bound, if one has been set.
pub fn ColorNorm::vmax(self : ColorNorm) -> Double? {
  match self {
    Linear(value) => value.vmax()
    Logarithmic(value) => value.vmax()
    SymmetricLog(value) => value.vmax()
    TwoSlope(value) => value.vmax()
    Power(value) => value.vmax()
    Centered(value) => value.vmax()
    Boundary(value) => Some(value.boundaries[value.boundaries.length() - 1])
  }
}

///|
/// Return whether a value is valid for this normalization.
pub fn ColorNorm::is_valid(self : ColorNorm, value : Double) -> Bool {
  match self {
    Linear(_) => finite(value)
    Logarithmic(norm) => norm.is_valid(value)
    SymmetricLog(norm) => norm.is_valid(value)
    TwoSlope(norm) => norm.is_valid(value)
    Power(norm) => norm.is_valid(value)
    Centered(norm) => norm.is_valid(value)
    Boundary(norm) => norm.is_valid(value)
  }
}

///|
/// Fill missing bounds from an array of scalar values.
pub fn ColorNorm::autoscale_none(
  self : ColorNorm,
  values : Array[Double],
) -> Unit {
  match self {
    Linear(norm) => norm.autoscale_none(values)
    Logarithmic(norm) => norm.autoscale_none(values)
    SymmetricLog(norm) => norm.autoscale_none(values)
    TwoSlope(norm) => norm.autoscale_none(values)
    Power(norm) => norm.autoscale_none(values)
    Centered(norm) => norm.autoscale_none(values)
    Boundary(norm) => norm.autoscale_none(values)
  }
}

///|
/// Set both data bounds from finite values.
pub fn ColorNorm::autoscale(
  self : ColorNorm,
  values : Array[Double],
) -> Unit raise NormalizeError {
  match self {
    Linear(norm) => norm.autoscale(values)
    Logarithmic(norm) => norm.autoscale(values)
    SymmetricLog(norm) => norm.autoscale(values)
    TwoSlope(norm) => norm.autoscale(values)
    Power(norm) => norm.autoscale(values)
    Centered(norm) => norm.autoscale(values)
    Boundary(norm) => norm.autoscale_none(values)
  }
}

///|
/// Return whether both bounds are set.
pub fn ColorNorm::scaled(self : ColorNorm) -> Bool {
  match self {
    Linear(norm) => norm.scaled()
    Logarithmic(norm) => norm.scaled()
    SymmetricLog(norm) => norm.scaled()
    TwoSlope(norm) => norm.scaled()
    Power(norm) => norm.scaled()
    Centered(norm) => norm.scaled()
    Boundary(norm) => norm.scaled()
  }
}

///|
/// Transform one scalar to normalized color space.
pub fn ColorNorm::transform(
  self : ColorNorm,
  value : Double,
) -> Double raise NormalizeError {
  match self {
    Linear(norm) => norm.transform(value)
    Logarithmic(norm) => norm.transform(value)
    SymmetricLog(norm) => norm.transform(value)
    TwoSlope(norm) => norm.transform(value)
    Power(norm) => norm.transform(value)
    Centered(norm) => norm.transform(value)
    Boundary(norm) => norm.transform(value)
  }
}

///|
/// Convert one normalized scalar back to data space.
pub fn ColorNorm::inverse(
  self : ColorNorm,
  value : Double,
) -> Double raise NormalizeError {
  match self {
    Linear(norm) => norm.inverse(value)
    Logarithmic(norm) => norm.inverse(value)
    SymmetricLog(norm) => norm.inverse(value)
    TwoSlope(norm) => norm.inverse(value)
    Power(norm) => norm.inverse(value)
    Centered(norm) => norm.inverse(value)
    Boundary(norm) => norm.inverse(value)
  }
}
