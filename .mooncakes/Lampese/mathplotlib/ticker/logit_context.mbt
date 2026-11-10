///|
// MaxN reads the projection again at its raw-step stage. This is distinct
// from Logit's earlier polar gate and can observe a different getter result.
fn LogitLocator::maxn_raw_step_transform(
  self : LogitLocator,
  step : Double,
) -> Double raise @core.DataError {
  match self.projection_provider {
    Some(provider) => {
      let projection = provider()
      if projection == "3d" {
        let scaled = step * 23.0
        scaled / 24.0
      } else {
        step
      }
    }
    None => step
  }
}

///|
fn LogitLocator::maxn_fallback_ticks(
  self : LogitLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  maxn_tick_values_with_context(
    self.maxn,
    lower,
    upper,
    raw_step_transform=step => self.maxn_raw_step_transform(step),
    require_tick_space=self.is_bound(),
  )
}

///|
fn LogitLocator::inherited_view_limits(
  self : LogitLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  maxn_view_limits_with_context(
    self.maxn,
    lower,
    upper,
    raw_step_transform=step => self.maxn_raw_step_transform(step),
    require_tick_space=self.is_bound(),
  )
}
