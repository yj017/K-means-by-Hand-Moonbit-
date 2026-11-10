///|
/// Adapt this object while sharing its live selection state. Independent
/// configuration/state copies are available through copy(); axes copy on install.
pub fn AutoDateLocator::as_locator(self : AutoDateLocator) -> DateLocator {
  {
    kind: Automatic,
    interval: 1,
    selector: 0,
    secondary: 0,
    selector_enabled: false,
    offset_minutes: self.settings.offset_minutes,
    timezone: self.settings.timezone,
    selection: None,
    secondary_selection: None,
    holidays: [],
    rule: None,
    automatic: Some(self),
    wrapper_locator: None,
    microsecond_object: None,
  }
}

///|
/// Copy a locator, isolating automatic selection state and private arrays.
/// RRuleLocator adapters retain their shared wrapper handle.
pub fn DateLocator::copy(self : DateLocator) -> DateLocator {
  {
    ..self,
    selection: self.selection.map(values => values.copy()),
    secondary_selection: self.secondary_selection.map(values => values.copy()),
    holidays: self.holidays.copy(),
    automatic: self.automatic.map(value => value.copy()),
  }
}

///|
/// Return the live automatic selector behind this adapter, if any.
pub fn DateLocator::automatic_locator(self : DateLocator) -> AutoDateLocator? {
  self.automatic
}

///|
/// Return locator-specific nonsingular bounds. Automatic locators expand exact
/// points by two years; explicit units use the base unit and interval.
pub fn DateLocator::nonsingular(
  self : DateLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  if self.automatic is Some(value) {
    return value.nonsingular(lower, upper)
  }
  if lower.is_nan() || upper.is_nan() || lower.is_inf() || upper.is_inf() {
    return (
      try! datetime(1970, 1, 1).to_ordinal(),
      try! datetime(1970, 1, 2).to_ordinal(),
    )
  }
  let first = Double::min(lower, upper)
  let last = Double::max(lower, upper)
  if Double::abs(last - first) < 1.0e-6 {
    let delta = 2.0 * self.unit_scale() * self.interval_value()
    (first - delta, last + delta)
  } else {
    (first, last)
  }
}
