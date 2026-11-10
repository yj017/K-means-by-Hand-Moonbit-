///|
/// Automatic minor ticks retain their first useful axis-specific rc selection.
pub struct AutoMinorLocator {
  priv mut ndivs : @config.MinorTickDivisions?
  priv mut scale_provider : (() -> String raise @core.DataError)?
  priv mut axis_name_provider : (() -> String raise @core.DataError)?
  priv mut major_ticks_provider : (() -> TickValues raise @core.DataError)?
  priv mut view_interval_provider : (() -> (Double, Double) raise @core.DataError)?
  priv diagnostics : Array[String]
}

///|
/// Store the raw subdivision value without construction-time validation.
pub fn AutoMinorLocator::new(
  ndivs~ : @config.MinorTickDivisions? = None,
) -> AutoMinorLocator {
  {
    ndivs,
    scale_provider: None,
    axis_name_provider: None,
    major_ticks_provider: None,
    view_interval_provider: None,
    diagnostics: [],
  }
}

///|
pub fn AutoMinorLocator::ndivs(
  self : AutoMinorLocator,
) -> @config.MinorTickDivisions? {
  self.ndivs
}

///|
/// Assign None to capture the applicable rc value on the next useful call.
pub fn AutoMinorLocator::set_ndivs(
  self : AutoMinorLocator,
  value : @config.MinorTickDivisions?,
) -> Unit {
  self.ndivs = value
}

///|
pub fn AutoMinorLocator::copy(self : AutoMinorLocator) -> AutoMinorLocator {
  {
    ndivs: self.ndivs,
    scale_provider: self.scale_provider,
    axis_name_provider: self.axis_name_provider,
    major_ticks_provider: self.major_ticks_provider,
    view_interval_provider: self.view_interval_provider,
    diagnostics: self.diagnostics.copy(),
  }
}

///|
pub fn AutoMinorLocator::warnings(self : AutoMinorLocator) -> Array[String] {
  self.diagnostics.copy()
}

///|
/// Preserve the inherited warning-only set_params protocol.
pub fn AutoMinorLocator::set_params(self : AutoMinorLocator) -> Unit {
  self.diagnostics.clear()
  self.diagnostics.push(
    "'set_params()' not defined for locator of type <class 'matplotlib.ticker.AutoMinorLocator'>",
  )
}

///|
pub fn AutoMinorLocator::bind_scale(
  self : AutoMinorLocator,
  provider : () -> String raise @core.DataError,
) -> Unit {
  self.scale_provider = Some(provider)
}

///|
pub fn AutoMinorLocator::bind_axis_name(
  self : AutoMinorLocator,
  provider : () -> String raise @core.DataError,
) -> Unit {
  self.axis_name_provider = Some(provider)
}

///|
pub fn AutoMinorLocator::bind_major_ticks(
  self : AutoMinorLocator,
  provider : () -> TickValues raise @core.DataError,
) -> Unit {
  self.major_ticks_provider = Some(provider)
}

///|
pub fn AutoMinorLocator::bind_view_interval(
  self : AutoMinorLocator,
  provider : () -> (Double, Double) raise @core.DataError,
) -> Unit {
  self.view_interval_provider = Some(provider)
}

///|
pub fn AutoMinorLocator::scale_provider(
  self : AutoMinorLocator,
) -> (() -> String raise @core.DataError)? {
  self.scale_provider
}

///|
pub fn AutoMinorLocator::axis_name_provider(
  self : AutoMinorLocator,
) -> (() -> String raise @core.DataError)? {
  self.axis_name_provider
}

///|
pub fn AutoMinorLocator::major_ticks_provider(
  self : AutoMinorLocator,
) -> (() -> TickValues raise @core.DataError)? {
  self.major_ticks_provider
}

///|
pub fn AutoMinorLocator::view_interval_provider(
  self : AutoMinorLocator,
) -> (() -> (Double, Double) raise @core.DataError)? {
  self.view_interval_provider
}

///|
pub fn AutoMinorLocator::call(
  self : AutoMinorLocator,
) -> Array[Double] raise @core.DataError {
  self.diagnostics.clear()
  let scale = match self.scale_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="auto minor locator is not bound to a scale",
      )
  }
  if scale == "log" {
    self.diagnostics.push(
      "AutoMinorLocator does not work on logarithmic scales",
    )
    return []
  }
  let majors = match self.major_ticks_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="auto minor locator is not bound to major ticks",
      )
  }
  let unique = auto_minor_unique(majors)
  if unique.length() < 2 {
    return []
  }
  let ndivs = match self.ndivs {
    Some(value) => value
    None => {
      let name = match self.axis_name_provider {
        Some(provider) => provider()
        None =>
          raise @core.DataError::InvalidTicks(
            message="auto minor locator is not bound to an axis name",
          )
      }
      let value = @config.minor_tick_divisions(horizontal=name != "y")
      self.ndivs = Some(value)
      value
    }
  }
  let step = auto_minor_step(unique, ndivs)
  let (lower, upper) = match self.view_interval_provider {
    Some(provider) => provider()
    None =>
      raise @core.DataError::InvalidTicks(
        message="auto minor locator is not bound to a view interval",
      )
  }
  auto_minor_grid(unique, step, lower, upper)
}

///|
pub fn AutoMinorLocator::tick_values(
  self : AutoMinorLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  self.diagnostics.clear()
  ignore(lower)
  ignore(upper)
  raise @core.DataError::InvalidTicks(
    message="Cannot get tick locations for a AutoMinorLocator",
  )
}

///|
pub fn AutoMinorLocator::view_limits(
  self : AutoMinorLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  self.diagnostics.clear()
  locator_nonsingular(lower, upper, 0.001)
}

///|
pub fn AutoMinorLocator::nonsingular(
  self : AutoMinorLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  self.diagnostics.clear()
  locator_nonsingular(lower, upper, 0.05)
}
