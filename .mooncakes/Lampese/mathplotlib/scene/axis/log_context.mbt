///|
pub fn Axis::bind_minpos(
  self : Axis,
  provider : () -> Double raise @core.DataError,
) -> Unit {
  self.minpos_provider = Some(provider)
}

///|
pub fn Axis::get_minpos(self : Axis) -> Double raise @core.DataError {
  match self.minpos_provider {
    Some(provider) => provider()
    None =>
      match self.render_minpos_provider {
        Some(provider) => provider()
        None => 1.0 / 0.0
      }
  }
}

///|
pub fn Axis::bind_shared_minpos(
  self : Axis,
  provider : () -> Array[Double] raise @core.DataError,
) -> Unit {
  self.shared_minpos_provider = Some(provider)
}

///|
pub fn Axis::shared_minpos_checked(
  self : Axis,
) -> Array[Double] raise @core.DataError {
  match self.shared_minpos_provider {
    Some(provider) => provider()
    None =>
      match self.render_shared_minpos_provider {
        Some(provider) => provider()
        None => [self.get_minpos()]
      }
  }
}

///|
/// Supply render-only minimum data when no owning-axis override is bound.
/// Explicit and Scene data providers keep precedence, including their errors.
pub fn Axis::bind_render_minpos(
  self : Axis,
  own : () -> Double raise @core.DataError,
  shared : () -> Array[Double] raise @core.DataError,
) -> Unit {
  self.render_minpos_provider = Some(own)
  self.render_shared_minpos_provider = Some(shared)
}

///|
fn Axis::bind_log_context(self : Axis, value : @ticker.LogLocator) -> Unit {
  value.bind_tick_space(() => {
    @ticker.LogTickSpace::from_integer(self.get_tick_space())
  })
  value.bind_view_interval(() => self.view_interval_checked())
  value.bind_minpos(() => self.get_minpos())
  value.bind_shared_minpos(() => self.shared_minpos_checked())
}

///|
pub fn Axis::has_named_log_locator(self : Axis) -> Bool {
  self.tickers.locator is Some(@ticker.Locator::NamedLog(_))
}

///|
pub fn Axis::numeric_nonsingular_bounds_checked(
  self : Axis,
  lower : Double,
  upper : Double,
) -> @core.Limits raise @core.DataError {
  match self.tickers.locator {
    Some(@ticker.Locator::NamedLogit(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedLog(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    _ => self.numeric_nonsingular_bounds(lower, upper)
  }
}

///|
fn Axis::bind_logit_context(self : Axis, value : @ticker.LogitLocator) -> Unit {
  value.bind_tick_space(() => self.get_tick_space())
  value.bind_view_interval(() => self.view_interval_checked())
  value.bind_minpos(() => self.get_minpos())
  value.bind_projection(() => "rectilinear")
}

///|
pub fn Axis::has_named_logit_locator(self : Axis) -> Bool {
  self.tickers.locator is Some(@ticker.Locator::NamedLogit(_))
}
