///|
/// Draw maps parent limits through the OLD child context before checking scale.
pub fn SecondaryAxis::prepare_draw(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  let (lower, upper) = self.mapped_parent_view_interval()
  self.store_formatter_view(lower, upper)
  self.synchronize_parent_scale()
}

///|
fn SecondaryAxis::synchronize_parent_scale(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  let name = match self.parent_axis {
    Some(parent) => parent.coordinate_scale_name()
    None => "linear"
  }
  if self.parent_scale_name == Some(name) {
    return
  }
  // Source snapshots the CURRENT locator before the ordinary scale lifecycle.
  // Keep its dtype and borrowed buffer when restoring FixedLocator afterward.
  let saved = if self.ticks_set {
    Some(self.major_tick_view_checked())
  } else {
    None
  }
  let source_ticks_current = self.source_ticks_current
  let (old_lower, old_upper) = self.numeric_axis.locator_default_limits()
  self.numeric_axis.configure_function_scale(
    self.forward,
    self.inverse,
    logarithmic=name == "log",
  )
  self.legacy_sampling = false
  self.source_ticks_current = false
  let (new_lower, new_upper) = self.numeric_axis.locator_default_limits()
  if old_lower != new_lower || old_upper != new_upper {
    self.autoscale_empty_data()
  }
  if saved is Some(values) {
    self.numeric_axis.set_locator(
      @ticker.FixedLocator::from_view(values).as_locator(),
    )
    self.source_ticks_current = source_ticks_current
  }
  self.parent_scale_name = Some(name)
}

///|
fn SecondaryAxis::autoscale_empty_data(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  let margin = if self.horizontal {
    @config.x_margin()
  } else {
    @config.y_margin()
  }
  if self.numeric_axis.autoscale_bounds_checked(
      [],
      margin~,
      stickies=[],
      tight=false,
    )
    is Some(candidate) {
    // set_bound performs both view reads even with two supplied endpoints.
    ignore(self.numeric_axis.lifecycle_view_interval_checked())
    let (first, last) = self.numeric_axis.lifecycle_view_interval_checked()
    let low = Double::min(candidate.lower(), candidate.upper())
    let high = Double::max(candidate.lower(), candidate.upper())
    let (lower, upper) = if first > last { (high, low) } else { (low, high) }
    ignore(self.numeric_axis.set_bound_limits_checked(lower, upper))
  }
}

///|
// This sampler is enabled only by explicit compatibility methods, never defaults.
fn SecondaryAxis::legacy_parent_grid_ticks(
  self : SecondaryAxis,
) -> Array[Double] raise @core.DataError {
  let values = match self.parent_axis {
    Some(parent) => {
      let (lower, upper) = parent.view_interval_checked()
      parent.tick_values_checked(@core.limits(lower, upper))
    }
    None => [0.0, 1.0]
  }
  let count = self.tick_count()
  let ticks = if values.length() < 2 || count < 2 {
    values
  } else {
    let first = values[0]
    let last = values[values.length() - 1]
    Array::makei(count, index => {
      first + (last - first) * index.to_double() / (count - 1).to_double()
    })
  }
  ticks.map(self.forward)
}
