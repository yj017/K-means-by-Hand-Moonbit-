///|
/// Automatic numeric ticks. All mutable state and arithmetic are shared with MaxNLocator.
pub struct AutoLocator {
  priv state : MaxNLocator
}

///|
/// Capture classic_mode at construction; later rc changes do not replace parameters.
///
/// ```mbt check
/// test {
///   let previous = @config.classic_mode()
///   defer @config.set_classic_mode(previous)
///   @config.set_classic_mode(false)
///   let locator = @ticker.AutoLocator::new()
///   assert_eq(locator.nbins(), @ticker.MaxNBins::Auto)
///   locator.as_maxn_locator().set_params(nbins=@ticker.MaxNBins::Count(3))
///   assert_eq(locator.nbins(), @ticker.MaxNBins::Count(3))
/// }
/// ```
pub fn AutoLocator::new() -> AutoLocator {
  let (nbins, steps) = if @config.classic_mode() {
    (MaxNBins::Count(9), TickValues::from_int64_array([1L, 2L, 5L, 10L]))
  } else {
    (MaxNBins::Auto, TickValues::from_array([1.0, 2.0, 2.5, 5.0, 10.0]))
  }
  { state: try! MaxNLocator::new(nbins~, steps~), }
}

///|
/// Return the live inherited MaxN state, retaining updates and bound providers.
pub fn AutoLocator::as_maxn_locator(self : AutoLocator) -> MaxNLocator {
  self.state
}

///|
pub fn AutoLocator::nbins(self : AutoLocator) -> MaxNBins {
  self.state.nbins()
}

///|
pub fn AutoLocator::steps(self : AutoLocator) -> TickValues {
  self.state.steps()
}

///|
pub fn AutoLocator::extended_steps(self : AutoLocator) -> Array[Double] {
  self.state.extended_steps()
}

///|
pub fn AutoLocator::integer(self : AutoLocator) -> Bool {
  self.state.integer()
}

///|
pub fn AutoLocator::symmetric(self : AutoLocator) -> Bool {
  self.state.symmetric()
}

///|
pub fn AutoLocator::prune(self : AutoLocator) -> String? {
  self.state.prune()
}

///|
pub fn AutoLocator::min_n_ticks(self : AutoLocator) -> Int32 {
  self.state.min_n_ticks()
}

///|
/// Delegate source-order updates, including omitted versus explicit None steps/prune.
pub fn AutoLocator::set_params(
  self : AutoLocator,
  nbins? : MaxNBins,
  steps? : TickValues?,
  integer? : Bool,
  symmetric? : Bool,
  prune? : String?,
  min_n_ticks? : Int32,
) -> Unit raise @core.DataError {
  self.state.set_params(
    nbins?,
    steps?,
    integer?,
    symmetric?,
    prune?,
    min_n_ticks?,
  )
}

///|
/// Shallow-copy inherited arrays/providers while keeping parameter replacement independent.
pub fn AutoLocator::copy(self : AutoLocator) -> AutoLocator {
  { state: self.state.copy(), }
}

///|
pub fn AutoLocator::tick_space_provider(self : AutoLocator) -> (() -> Double)? {
  self.state.tick_space_provider()
}

///|
pub fn AutoLocator::view_interval_provider(
  self : AutoLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.state.view_interval_provider()
}

///|
pub fn AutoLocator::bind_tick_space(
  self : AutoLocator,
  provider : () -> Double,
) -> Unit {
  self.state.bind_tick_space(provider)
}

///|
pub fn AutoLocator::bind_view_interval(
  self : AutoLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.state.bind_view_interval(provider)
}

///|
pub fn AutoLocator::tick_values(
  self : AutoLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  self.state.tick_values(lower, upper)
}

///|
pub fn AutoLocator::view_limits(
  self : AutoLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  self.state.view_limits(lower, upper)
}

///|
pub fn AutoLocator::nonsingular(
  self : AutoLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  self.state.nonsingular(lower, upper)
}

///|
pub fn AutoLocator::call(
  self : AutoLocator,
) -> Array[Double] raise @core.DataError {
  self.state.call()
}
