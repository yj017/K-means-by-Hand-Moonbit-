///|
/// Symmetric logarithmic ticks retain raw parameters and their last axis view.
pub struct SymmetricalLogLocator {
  priv base : Double
  priv linthresh : Double
  priv mut subs : SymLogSubs
  priv mut numticks : LogNumTicks
  priv mut view_interval_provider : (() -> (Double, Double) raise @core.DataError)?
}

///|
/// Capture a SymLog transform's base/threshold, or require both explicit values.
/// The transform's linscale and explicit overrides are ignored when it is present.
pub fn SymmetricalLogLocator::new(
  transform? : @scale.Scale,
  base? : Double,
  linthresh? : Double,
  subs~ : SymLogSubs? = None,
) -> SymmetricalLogLocator raise @core.DataError {
  let (base, linthresh) = match transform {
    Some(@scale.Scale::SymLog(base~, linthresh~, ..)) => (base, linthresh)
    Some(_) =>
      raise @core.DataError::InvalidTicks(
        message="symlog locator transform must expose base and linthresh",
      )
    None =>
      match (base, linthresh) {
        (Some(base), Some(linthresh)) => (base, linthresh)
        _ =>
          raise @core.DataError::InvalidTicks(
            message="Either transform, or both linthresh and base, must be provided.",
          )
      }
  }
  {
    base,
    linthresh,
    subs: subs.unwrap_or_else(fn() { Values(TickValues::from_array([1.0])) }),
    numticks: Integer(@bigint.BigInt::from_int(15)),
    view_interval_provider: None,
  }
}

///|
pub fn SymmetricalLogLocator::base(self : SymmetricalLogLocator) -> Double {
  self.base
}

///|
pub fn SymmetricalLogLocator::linthresh(self : SymmetricalLogLocator) -> Double {
  self.linthresh
}

///|
pub fn SymmetricalLogLocator::subs(self : SymmetricalLogLocator) -> SymLogSubs {
  self.subs
}

///|
pub fn SymmetricalLogLocator::numticks(
  self : SymmetricalLogLocator,
) -> LogNumTicks {
  self.numticks
}

///|
pub fn SymmetricalLogLocator::set_numticks(
  self : SymmetricalLogLocator,
  value : LogNumTicks,
) -> Unit {
  self.numticks = value
}

///|
/// Store numticks before subs; absent values preserve the corresponding slot.
pub fn SymmetricalLogLocator::set_params(
  self : SymmetricalLogLocator,
  subs? : SymLogSubs,
  numticks? : LogNumTicks,
) -> Unit {
  if numticks is Some(value) {
    self.numticks = value
  }
  if subs is Some(value) {
    self.subs = value
  }
}

///|
pub fn SymmetricalLogLocator::copy(
  self : SymmetricalLogLocator,
) -> SymmetricalLogLocator {
  {
    base: self.base,
    linthresh: self.linthresh,
    subs: self.subs,
    numticks: self.numticks,
    view_interval_provider: self.view_interval_provider,
  }
}

///|
pub fn SymmetricalLogLocator::bind_view_interval(
  self : SymmetricalLogLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.view_interval_provider = Some(provider)
}

///|
pub fn SymmetricalLogLocator::view_interval_provider(
  self : SymmetricalLogLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.view_interval_provider
}

///|
pub fn SymmetricalLogLocator::call(
  self : SymmetricalLogLocator,
) -> Array[Double] raise @core.DataError {
  let (lower, upper) = match self.view_interval_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="symlog locator is not bound to a view interval",
      )
  }
  self.tick_values(lower, upper)
}

///|
pub fn SymmetricalLogLocator::tick_values(
  self : SymmetricalLogLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  named_symlog_locator_ticks(self, lower, upper)
}

///|
pub fn SymmetricalLogLocator::nonsingular(
  _self : SymmetricalLogLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.05)
}

///|
/// Round original endpoints first, expand equal decades, then apply .001 nonsingular.
pub fn SymmetricalLogLocator::view_limits(
  self : SymmetricalLogLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  let mut first = lower
  let mut last = upper
  if last < first {
    let previous = first
    first = last
    last = previous
  }
  if @config.axes_autolimit_mode() == "round_numbers" {
    // A zero short-circuits the original helper and keeps its Python float.
    // Other inputs produce NumPy scalars, including an underflowed zero.
    let lower_is_python_float = first == 0.0
    first = log_decade_less_equal(first, self.base)
    last = log_decade_greater_equal(last, self.base)
    if first == last {
      // The strict helper divides this retained Python float by the base.
      // NumPy scalar division instead retains its IEEE infinity/NaN result.
      if lower_is_python_float && self.base == 0.0 {
        raise @core.DataError::InvalidTicks(message="float division by zero")
      }
      first = log_decade_less(first, self.base)
      last = log_decade_greater(last, self.base)
    }
  }
  locator_nonsingular(first, last, 0.001)
}
