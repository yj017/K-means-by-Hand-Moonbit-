///|
/// A fixed interval budget or an axis-dependent automatic interval budget.
pub(all) enum MaxNBins {
  Auto
  Count(Int32)
} derive(Debug, Eq)

///|
pub extend MaxNBins with @debug.Debug::{to_repr}

///|
pub extend MaxNBins with Eq::{equal, not_equal}

///|
/// Mutable MaxN state. Step inputs remain borrowed; the extended staircase is a snapshot.
pub struct MaxNLocator {
  priv mut nbins : MaxNBins
  priv mut steps : TickValues
  priv mut extended_steps : Array[Double]
  priv mut integer : Bool
  priv mut symmetric : Bool
  priv mut prune : String?
  priv mut min_n_ticks : Int32
  priv mut tick_space_provider : (() -> Double)?
  priv mut view_interval_provider : (() -> (Double, Double) raise @core.DataError)?
}

///|
fn maxn_default_steps() -> TickValues {
  TickValues::from_array([1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0])
}

///|
fn maxn_validate_steps(steps : TickValues) -> TickValues raise @core.DataError {
  let length = steps.length()
  if length == 0 {
    raise @core.DataError::InvalidTicks(
      message="maxn locator steps have no first or last element",
    )
  }
  for index in 1..<length {
    let nonincreasing = if steps.is_int64() {
      let difference = steps.get_int64(index).reinterpret_as_uint64() -
        steps.get_int64(index - 1).reinterpret_as_uint64()
      difference.reinterpret_as_int64() <= 0L
    } else {
      steps.get(index) - steps.get(index - 1) <= 0.0
    }
    if nonincreasing {
      raise @core.DataError::InvalidTicks(
        message="maxn locator steps must be increasing between one and ten",
      )
    }
  }
  let first = steps.get(0)
  let last = steps.get(-1)
  if last > 10.0 || first < 1.0 {
    raise @core.DataError::InvalidTicks(
      message="maxn locator steps must be increasing between one and ten",
    )
  }
  if first == 1.0 && last == 10.0 {
    return steps
  }
  steps.with_endpoints(first != 1.0, last != 10.0)
}

///|
fn maxn_staircase(steps : TickValues) -> Array[Double] raise @core.DataError {
  let result : Array[Double] = []
  for index in 0..<(steps.length() - 1) {
    result.push(0.1 * steps.get(index))
  }
  for index in 0..<steps.length() {
    result.push(steps.get(index))
  }
  let last = if steps.is_int64() {
    let product = steps.get_int64(1).reinterpret_as_uint64() * 10UL
    product.reinterpret_as_int64().to_double()
  } else {
    10.0 * steps.get(1)
  }
  result.push(last)
  result
}

///|
pub fn MaxNLocator::new(
  nbins? : MaxNBins,
  steps? : TickValues,
  integer~ : Bool = false,
  symmetric~ : Bool = false,
  prune? : String,
  min_n_ticks~ : Int32 = 2,
) -> MaxNLocator raise @core.DataError {
  let defaults = maxn_default_steps()
  let locator = {
    nbins: MaxNBins::Count(10),
    steps: defaults,
    extended_steps: maxn_staircase(defaults),
    integer: false,
    symmetric: false,
    prune: None,
    min_n_ticks: 2,
    tick_space_provider: None,
    view_interval_provider: None,
  }
  locator.set_params(
    nbins=nbins.unwrap_or(MaxNBins::Count(10)),
    steps~,
    integer~,
    symmetric~,
    prune~,
    min_n_ticks~,
  )
  locator
}

///|
/// Preserve the source update order; later validation errors retain earlier updates.
/// Explicit None resets steps/prune, while omission leaves each value unchanged.
pub fn MaxNLocator::set_params(
  self : MaxNLocator,
  nbins? : MaxNBins,
  steps? : TickValues?,
  integer? : Bool,
  symmetric? : Bool,
  prune? : String?,
  min_n_ticks? : Int32,
) -> Unit raise @core.DataError {
  if nbins is Some(value) {
    self.nbins = value
  }
  if symmetric is Some(value) {
    self.symmetric = value
  }
  if prune is Some(value) {
    if value is Some(text) &&
      text != "lower" &&
      text != "upper" &&
      text != "both" {
      raise @core.DataError::InvalidTicks(
        message="maxn locator prune must be lower, upper, both, or None",
      )
    }
    self.prune = value
  }
  if min_n_ticks is Some(value) {
    self.min_n_ticks = Int32::max(1, value)
  }
  if steps is Some(value) {
    self.steps = match value {
      Some(steps) => maxn_validate_steps(steps)
      None => maxn_default_steps()
    }
    self.extended_steps = maxn_staircase(self.steps)
  }
  if integer is Some(value) {
    self.integer = value
  }
}

///|
pub fn MaxNLocator::nbins(self : MaxNLocator) -> MaxNBins {
  self.nbins
}

///|
pub fn MaxNLocator::steps(self : MaxNLocator) -> TickValues {
  self.steps
}

///|
/// Return an independent copy of the internally captured extended staircase.
pub fn MaxNLocator::extended_steps(self : MaxNLocator) -> Array[Double] {
  self.extended_steps.copy()
}

///|
pub fn MaxNLocator::integer(self : MaxNLocator) -> Bool {
  self.integer
}

///|
pub fn MaxNLocator::symmetric(self : MaxNLocator) -> Bool {
  self.symmetric
}

///|
pub fn MaxNLocator::prune(self : MaxNLocator) -> String? {
  self.prune
}

///|
pub fn MaxNLocator::min_n_ticks(self : MaxNLocator) -> Int32 {
  self.min_n_ticks
}

///|
pub fn MaxNLocator::tick_space_provider(self : MaxNLocator) -> (() -> Double)? {
  self.tick_space_provider
}

///|
pub fn MaxNLocator::view_interval_provider(
  self : MaxNLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.view_interval_provider
}

///|
pub fn MaxNLocator::bind_tick_space(
  self : MaxNLocator,
  provider : () -> Double,
) -> Unit {
  self.tick_space_provider = Some(provider)
}

///|
pub fn MaxNLocator::bind_view_interval(
  self : MaxNLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.view_interval_provider = Some(provider)
}

///|
/// Share step buffers, captured staircase and providers; later assignments stay independent.
pub fn MaxNLocator::copy(self : MaxNLocator) -> MaxNLocator {
  {
    nbins: self.nbins,
    steps: self.steps,
    extended_steps: self.extended_steps,
    integer: self.integer,
    symmetric: self.symmetric,
    prune: self.prune,
    min_n_ticks: self.min_n_ticks,
    tick_space_provider: self.tick_space_provider,
    view_interval_provider: self.view_interval_provider,
  }
}
