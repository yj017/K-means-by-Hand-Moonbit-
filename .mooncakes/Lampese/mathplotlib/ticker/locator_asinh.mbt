///|
/// Raw Asinh parameters and the most recently bound axis view.
pub struct AsinhLocator {
  priv mut linear_width : Double
  priv mut numticks : LogNumTicks?
  priv mut symthresh : Double
  priv mut base : Double
  priv mut subs : AsinhSubs?
  priv mut view_interval_provider : (() -> (Double, Double) raise @core.DataError)?
}

///|
/// Omitted numticks selects eleven; explicit None retains an invalid raw None.
pub fn AsinhLocator::new(
  linear_width : Double,
  numticks? : LogNumTicks?,
  symthresh~ : Double = 0.2,
  base~ : Double = 10.0,
  subs~ : AsinhSubs? = None,
) -> AsinhLocator {
  {
    linear_width,
    numticks: numticks.unwrap_or(Some(Integer(@bigint.BigInt::from_int(11)))),
    symthresh,
    base,
    subs,
    view_interval_provider: None,
  }
}

///|
pub fn AsinhLocator::linear_width(self : AsinhLocator) -> Double {
  self.linear_width
}

///|
pub fn AsinhLocator::set_linear_width(
  self : AsinhLocator,
  value : Double,
) -> Unit {
  self.linear_width = value
}

///|
pub fn AsinhLocator::numticks(self : AsinhLocator) -> LogNumTicks? {
  self.numticks
}

///|
pub fn AsinhLocator::set_numticks(
  self : AsinhLocator,
  value : LogNumTicks?,
) -> Unit {
  self.numticks = value
}

///|
pub fn AsinhLocator::symthresh(self : AsinhLocator) -> Double {
  self.symthresh
}

///|
pub fn AsinhLocator::set_symthresh(self : AsinhLocator, value : Double) -> Unit {
  self.symthresh = value
}

///|
pub fn AsinhLocator::base(self : AsinhLocator) -> Double {
  self.base
}

///|
pub fn AsinhLocator::set_base(self : AsinhLocator, value : Double) -> Unit {
  self.base = value
}

///|
pub fn AsinhLocator::subs(self : AsinhLocator) -> AsinhSubs? {
  self.subs
}

///|
/// Assign the raw slot, without the set_params empty-container normalization.
pub fn AsinhLocator::set_subs(self : AsinhLocator, value : AsinhSubs?) -> Unit {
  self.subs = value
}

///|
/// Update in source order; a final scalar-subs len error keeps earlier writes.
pub fn AsinhLocator::set_params(
  self : AsinhLocator,
  numticks? : LogNumTicks?,
  symthresh? : Double?,
  base? : Double?,
  subs? : AsinhSubs?,
) -> Unit raise @core.DataError {
  if numticks is Some(Some(value)) {
    self.numticks = Some(value)
  }
  if symthresh is Some(Some(value)) {
    self.symthresh = value
  }
  if base is Some(Some(value)) {
    self.base = value
  }
  if subs is Some(Some(value)) {
    let empty = match value {
      Sequence(values) => values.is_empty()
      Tuple(values) => values.length() == 0
      NdArray(values) => values.length() == 0
      Text(value) => value.is_empty()
      Number(_) =>
        raise @core.DataError::InvalidTicks(
          message="object of type 'float' has no len()",
        )
    }
    self.subs = if empty { None } else { Some(value) }
  }
}

///|
pub fn AsinhLocator::copy(self : AsinhLocator) -> AsinhLocator {
  {
    linear_width: self.linear_width,
    numticks: self.numticks,
    symthresh: self.symthresh,
    base: self.base,
    subs: self.subs,
    view_interval_provider: self.view_interval_provider,
  }
}

///|
pub fn AsinhLocator::bind_view_interval(
  self : AsinhLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.view_interval_provider = Some(provider)
}

///|
pub fn AsinhLocator::view_interval_provider(
  self : AsinhLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.view_interval_provider
}

///|
pub fn AsinhLocator::call(
  self : AsinhLocator,
) -> Array[Double] raise @core.DataError {
  let (lower, upper) = match self.view_interval_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="asinh locator is not bound to a view interval",
      )
  }
  if lower * upper < 0.0 && Double::abs(1.0 + upper / lower) < self.symthresh {
    let bound = Double::max(Double::abs(lower), Double::abs(upper))
    self.tick_values(-bound, bound)
  } else {
    self.tick_values(lower, upper)
  }
}

///|
pub fn AsinhLocator::tick_values(
  self : AsinhLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  named_asinh_locator_ticks(self, lower, upper)
}

///|
pub fn AsinhLocator::nonsingular(
  _self : AsinhLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.05)
}

///|
pub fn AsinhLocator::view_limits(
  _self : AsinhLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.001)
}
