///|
/// Install a minor locator in the stable secondary Axis context.
pub fn SecondaryAxis::set_minor_locator(
  self : SecondaryAxis,
  locator : @ticker.MinorLocator,
) -> Unit {
  // The configured function context excludes the primary-only compatibility
  // errors. Slot assignment and binding do not invoke checked user providers.
  try! self.numeric_axis.set_minor_locator(locator)
}

///|
pub fn SecondaryAxis::minor_locator(
  self : SecondaryAxis,
) -> @ticker.MinorLocator? {
  self.numeric_axis.minor_locator()
}

///|
pub fn SecondaryAxis::clear_minor_locator(self : SecondaryAxis) -> Unit {
  self.numeric_axis.clear_minor_locator()
}

///|
pub fn SecondaryAxis::set_minor_overlap_removal(
  self : SecondaryAxis,
  enabled : Bool,
) -> Unit {
  self.numeric_axis.set_minor_overlap_removal(enabled)
}

///|
pub fn SecondaryAxis::minor_overlap_removal(self : SecondaryAxis) -> Bool {
  self.numeric_axis.minor_overlap_removal()
}

///|
fn SecondaryAxis::major_tick_view_checked(
  self : SecondaryAxis,
) -> @ticker.TickValues raise @core.DataError {
  if self.legacy_sampling {
    return @ticker.TickValues::from_array(self.legacy_parent_grid_ticks())
  }
  match self.locator() {
    Some(@ticker.Locator::NamedFixed(value)) =>
      return value.tick_values(0.0, 0.0)
    Some(@ticker.Locator::NamedLinear(value)) => {
      let (lower, upper) = self.numeric_view_interval()
      return value.tick_values(lower, upper)
    }
    _ => ()
  }
  let locations = self.numeric_axis.formatter_tick_locations_checked(
    self.numeric_axis.stored_view_limits(),
  )
  match locations {
    @ticker.FormatterLocations::NdArray(view) => view
    @ticker.FormatterLocations::Sequence(values) =>
      @ticker.TickValues::from_array(values)
    _ => {
      let values = Array::makei(locations.length(), index => {
        locations.get(index)
      })
      @ticker.TickValues::from_array(values)
    }
  }
}

///|
pub fn SecondaryAxis::tick_values_checked(
  self : SecondaryAxis,
) -> Array[Double] raise @core.DataError {
  let view = self.major_tick_view_checked()
  view.view(0, 1, Int32::min(100000, view.length())).to_array()
}

///|
pub fn SecondaryAxis::minor_tick_values_checked(
  self : SecondaryAxis,
) -> Array[Double] raise @core.DataError {
  self.numeric_axis.minor_tick_values_checked(
    self.numeric_axis.stored_view_limits(),
  )
}
