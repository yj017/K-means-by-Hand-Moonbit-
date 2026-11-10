///|
/// Probability ticks share live MaxN parameters and retain their own axis context.
pub struct LogitLocator {
  priv maxn : MaxNLocator
  priv mut minor : Bool
  priv mut minpos_provider : (() -> Double raise @core.DataError)?
  priv mut projection_provider : (() -> String raise @core.DataError)?
  priv diagnostics : Array[String]
}

///|
/// Omitted nbins selects auto; explicit None selects the inherited default ten.
pub fn LogitLocator::new(
  minor~ : Bool = false,
  nbins? : MaxNBins?,
) -> LogitLocator raise @core.DataError {
  let nbins = match nbins {
    None => MaxNBins::Auto
    Some(None) => MaxNBins::Count(10)
    Some(Some(value)) => value
  }
  {
    maxn: MaxNLocator::new(
      nbins~,
      steps=TickValues::from_int64_array([1L, 2L, 5L, 10L]),
    ),
    minor,
    minpos_provider: None,
    projection_provider: None,
    diagnostics: [],
  }
}

///|
/// Return live inherited state; its numerical methods retain base MaxN behavior.
pub fn LogitLocator::as_maxn_locator(self : LogitLocator) -> MaxNLocator {
  self.maxn
}

///|
pub fn LogitLocator::minor(self : LogitLocator) -> Bool {
  self.minor
}

///|
/// The Python minor property setter treats None as keep.
pub fn LogitLocator::set_minor(self : LogitLocator, value : Bool?) -> Unit {
  if value is Some(value) {
    self.minor = value
  }
}

///|
/// Set minor first; inherited validation failures retain that earlier write.
pub fn LogitLocator::set_params(
  self : LogitLocator,
  minor? : Bool?,
  nbins? : MaxNBins,
  steps? : TickValues?,
  integer? : Bool,
  symmetric? : Bool,
  prune? : String?,
  min_n_ticks? : Int32,
) -> Unit raise @core.DataError {
  if minor is Some(Some(value)) {
    self.minor = value
  }
  self.maxn.set_params(
    nbins?,
    steps?,
    integer?,
    symmetric?,
    prune?,
    min_n_ticks?,
  )
}

///|
pub fn LogitLocator::copy(self : LogitLocator) -> LogitLocator {
  {
    maxn: self.maxn.copy(),
    minor: self.minor,
    minpos_provider: self.minpos_provider,
    projection_provider: self.projection_provider,
    diagnostics: self.diagnostics.copy(),
  }
}

///|
pub fn LogitLocator::warnings(self : LogitLocator) -> Array[String] {
  self.diagnostics.copy()
}

///|
pub fn LogitLocator::bind_tick_space(
  self : LogitLocator,
  provider : () -> Double,
) -> Unit {
  self.maxn.bind_tick_space(provider)
}

///|
pub fn LogitLocator::tick_space_provider(
  self : LogitLocator,
) -> (() -> Double)? {
  self.maxn.tick_space_provider()
}

///|
pub fn LogitLocator::bind_view_interval(
  self : LogitLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.maxn.bind_view_interval(provider)
}

///|
pub fn LogitLocator::view_interval_provider(
  self : LogitLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.maxn.view_interval_provider()
}

///|
pub fn LogitLocator::bind_minpos(
  self : LogitLocator,
  provider : () -> Double raise @core.DataError,
) -> Unit {
  self.minpos_provider = Some(provider)
}

///|
pub fn LogitLocator::minpos_provider(
  self : LogitLocator,
) -> (() -> Double raise @core.DataError)? {
  self.minpos_provider
}

///|
pub fn LogitLocator::bind_projection(
  self : LogitLocator,
  provider : () -> String raise @core.DataError,
) -> Unit {
  self.projection_provider = Some(provider)
}

///|
pub fn LogitLocator::projection_provider(
  self : LogitLocator,
) -> (() -> String raise @core.DataError)? {
  self.projection_provider
}

///|
fn LogitLocator::is_bound(self : LogitLocator) -> Bool {
  self.maxn.tick_space_provider() is Some(_) ||
  self.maxn.view_interval_provider() is Some(_) ||
  self.minpos_provider is Some(_) ||
  self.projection_provider is Some(_)
}

///|
pub fn LogitLocator::call(
  self : LogitLocator,
) -> Array[Double] raise @core.DataError {
  self.diagnostics.clear()
  let (lower, upper) = match self.maxn.view_interval_provider() {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="logit locator is not bound to a view interval",
      )
  }
  self.tick_values(lower, upper)
}

///|
pub fn LogitLocator::tick_values(
  self : LogitLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  self.diagnostics.clear()
  named_logit_locator_ticks(self, lower, upper)
}

///|
pub fn LogitLocator::nonsingular(
  self : LogitLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  self.diagnostics.clear()
  let (first, last) = if lower > upper {
    (upper, lower)
  } else {
    (lower, upper)
  }
  let mut first = first
  let mut last = last
  let standard = 1.0e-7
  if first.is_nan() || first.is_inf() || last.is_nan() || last.is_inf() {
    return (standard, 1.0 - standard)
  }
  if last <= 0.0 || first >= 1.0 {
    self.diagnostics.push(
      "Data has no values between 0 and 1, and therefore cannot be logit-scaled.",
    )
    return (standard, 1.0 - standard)
  }
  let mut minimum = match self.minpos_provider {
    Some(provider) => provider()
    None =>
      if self.is_bound() {
        raise @core.DataError::InvalidTicks(
          message="bound logit locator has no minimum positive data provider",
        )
      } else {
        standard
      }
  }
  if minimum.is_nan() || minimum.is_inf() {
    minimum = standard
  }
  if first <= 0.0 {
    first = minimum
  }
  if last >= 1.0 {
    last = 1.0 - minimum
  }
  if first == last {
    first = 0.1 * first
    last = 1.0 - first
  }
  (first, last)
}

///|
/// Inherited MaxN view selection does not call the Logit probability nonsingular.
pub fn LogitLocator::view_limits(
  self : LogitLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  self.diagnostics.clear()
  self.inherited_view_limits(lower, upper)
}
