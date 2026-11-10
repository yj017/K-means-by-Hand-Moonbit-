///|
fn Axis::make_default_date_locator(
  self : Axis,
  info : @date.DateAxisInfo,
) -> @date.AutoDateLocator {
  let mut value = info.major_locator().automatic_locator().unwrap().copy()
  if self.tick_count_configured {
    value = try! value.with_maxticks(@date.All(self.tick_count))
  }
  value
}

///|
/// Return a copy of the default automatic date selector and its last state.
/// Explicit calendar locators are available through date_locator().
pub fn Axis::auto_date_locator(self : Axis) -> @date.AutoDateLocator? {
  self.tickers.automatic_date_locator.map(value => value.copy())
}

///|
/// Apply date-locator nonsingular bounds before autoscale margins. Numeric
/// locators and fixed ticks retain their existing range normalization.
pub fn Axis::date_nonsingular_bounds(
  self : Axis,
  lower : Double,
  upper : Double,
) -> @core.Limits {
  if self.tickers.major_locator_kind != Date {
    return @core.limits(lower, upper)
  }
  let (first, last) = match self.tickers.date_locator {
    Some(value) => value.nonsingular(lower, upper)
    None =>
      match self.tickers.automatic_date_locator {
        Some(value) => value.nonsingular(lower, upper)
        None => return @core.limits(lower, upper)
      }
  }
  if !lower.is_nan() &&
    !upper.is_nan() &&
    !lower.is_inf() &&
    !upper.is_inf() &&
    lower > upper {
    @core.limits(last, first)
  } else {
    @core.limits(first, last)
  }
}
