///|
/// Logarithmic locator with ordered parameter updates and live axis context.
pub struct LogLocator {
  priv mut base : Double
  priv mut subs : LogSubs
  priv mut numticks : LogNumTicks
  priv mut tick_space_provider : (() -> LogTickSpace raise @core.DataError)?
  priv mut view_interval_provider : (() -> (Double, Double) raise @core.DataError)?
  priv mut minpos_provider : (() -> Double raise @core.DataError)?
  priv mut shared_minpos_provider : (() -> Array[Double] raise @core.DataError)?
  priv diagnostics : Array[String]
}

///|
fn log_normalize_subs(subs : LogSubs?) -> LogSubs raise @core.DataError {
  match subs {
    None => Text("auto")
    Some(Text(value)) => {
      if value != "auto" && value != "all" {
        raise @core.DataError::InvalidTicks(
          message="log subs must be all, auto, or a sequence of floats",
        )
      }
      Text(value)
    }
    Some(Values(value)) =>
      if value.is_int64() {
        Values(TickValues::from_array(value.to_array()))
      } else {
        Values(value)
      }
  }
}

///|
/// Omitted subs use [1]; explicit None selects auto. Numeric values are not validated.
pub fn LogLocator::new(
  base~ : Double = 10.0,
  subs? : LogSubs?,
  numticks~ : LogNumTicks? = None,
) -> LogLocator raise @core.DataError {
  let numticks = match numticks {
    Some(value) => value
    None =>
      if @config.classic_mode() {
        Integer(@bigint.BigInt::from_int(15))
      } else {
        Text("auto")
      }
  }
  let subs = match subs {
    None => LogSubs::Values(TickValues::from_array([1.0]))
    Some(value) => log_normalize_subs(value)
  }
  {
    base,
    subs,
    numticks,
    tick_space_provider: None,
    view_interval_provider: None,
    minpos_provider: None,
    shared_minpos_provider: None,
    diagnostics: [],
  }
}

///|
pub fn LogLocator::base(self : LogLocator) -> Double {
  self.base
}

///|
pub fn LogLocator::subs(self : LogLocator) -> LogSubs {
  self.subs
}

///|
pub fn LogLocator::numticks(self : LogLocator) -> LogNumTicks {
  self.numticks
}

///|
/// Assign the raw public numticks slot without validation or classic recapture.
pub fn LogLocator::set_numticks(self : LogLocator, value : LogNumTicks) -> Unit {
  self.numticks = value
}

///|
/// Preserve source order and partial state: base, then subs, then numticks.
pub fn LogLocator::set_params(
  self : LogLocator,
  base? : Double?,
  subs? : LogSubs?,
  numticks? : LogNumTicks?,
) -> Unit raise @core.DataError {
  if base is Some(Some(value)) {
    self.base = value
  }
  if subs is Some(Some(value)) {
    self.subs = log_normalize_subs(Some(value))
  }
  if numticks is Some(Some(value)) {
    self.numticks = value
  }
}

///|
pub fn LogLocator::copy(self : LogLocator) -> LogLocator {
  {
    base: self.base,
    subs: self.subs,
    numticks: self.numticks,
    tick_space_provider: self.tick_space_provider,
    view_interval_provider: self.view_interval_provider,
    minpos_provider: self.minpos_provider,
    shared_minpos_provider: self.shared_minpos_provider,
    diagnostics: self.diagnostics.copy(),
  }
}

///|
pub fn LogLocator::warnings(self : LogLocator) -> Array[String] {
  self.diagnostics.copy()
}

///|
pub fn LogLocator::bind_tick_space(
  self : LogLocator,
  provider : () -> LogTickSpace raise @core.DataError,
) -> Unit {
  self.tick_space_provider = Some(provider)
}

///|
pub fn LogLocator::bind_view_interval(
  self : LogLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.view_interval_provider = Some(provider)
}

///|
pub fn LogLocator::bind_minpos(
  self : LogLocator,
  provider : () -> Double raise @core.DataError,
) -> Unit {
  self.minpos_provider = Some(provider)
}

///|
pub fn LogLocator::bind_shared_minpos(
  self : LogLocator,
  provider : () -> Array[Double] raise @core.DataError,
) -> Unit {
  self.shared_minpos_provider = Some(provider)
}

///|
pub fn LogLocator::tick_space_provider(
  self : LogLocator,
) -> (() -> LogTickSpace raise @core.DataError)? {
  self.tick_space_provider
}

///|
pub fn LogLocator::view_interval_provider(
  self : LogLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.view_interval_provider
}

///|
pub fn LogLocator::minpos_provider(
  self : LogLocator,
) -> (() -> Double raise @core.DataError)? {
  self.minpos_provider
}

///|
pub fn LogLocator::shared_minpos_provider(
  self : LogLocator,
) -> (() -> Array[Double] raise @core.DataError)? {
  self.shared_minpos_provider
}

///|
fn LogLocator::is_bound(self : LogLocator) -> Bool {
  self.tick_space_provider is Some(_) ||
  self.view_interval_provider is Some(_) ||
  self.minpos_provider is Some(_) ||
  self.shared_minpos_provider is Some(_)
}

///|
pub fn LogLocator::tick_values(
  self : LogLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  self.diagnostics.clear()
  named_log_locator_ticks(self, lower, upper)
}

///|
pub fn LogLocator::call(
  self : LogLocator,
) -> Array[Double] raise @core.DataError {
  self.diagnostics.clear()
  let (lower, upper) = match self.view_interval_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="log locator is not bound to a view interval",
      )
  }
  self.tick_values(lower, upper)
}

///|
/// Positive finite ranges consult every shared minpos, even when already nonsingular.
pub fn LogLocator::nonsingular(
  self : LogLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  self.diagnostics.clear()
  let mut first = lower
  let mut last = upper
  if first > last {
    let previous = first
    first = last
    last = previous
  }
  if first.is_nan() || first.is_inf() || last.is_nan() || last.is_inf() {
    return (1.0, 10.0)
  }
  if last <= 0.0 {
    self.diagnostics.push(
      "Data has no positive values, and therefore cannot be log-scaled.",
    )
    return (1.0, 10.0)
  }
  let minpos = match self.shared_minpos_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="log locator is not bound to shared minimum positive values",
      )
  }
  if minpos.is_empty() {
    raise @core.DataError::InvalidTicks(
      message="log locator shared minimum positive values are empty",
    )
  }
  let mut minimum = minpos[0]
  // Python min keeps the first NaN and ignores later NaNs via strict comparison.
  for index in 1..<minpos.length() {
    if minpos[index] < minimum {
      minimum = minpos[index]
    }
  }
  if minimum.is_nan() || minimum.is_inf() {
    minimum = 1.0e-300
  }
  if first <= 0.0 {
    first = minimum
  }
  if first == last {
    first = log_decade_less(first, self.base)
    last = log_decade_greater(last, self.base)
  }
  (first, last)
}

///|
pub fn LogLocator::view_limits(
  self : LogLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  let (first, last) = self.nonsingular(lower, upper)
  if @config.axes_autolimit_mode() == "round_numbers" {
    (
      log_decade_less_equal(first, self.base),
      log_decade_greater_equal(last, self.base),
    )
  } else {
    (first, last)
  }
}
