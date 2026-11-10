///|
/// Date-specific AxisInfo. Locator and formatter getters share this object's
/// live selection; copy() creates an independent, correctly rebound pair.
pub struct DateAxisInfo {
  priv locator : DateLocator
  priv formatter : DateFormatter
  priv label : String
  priv default_limits : (DateTime, DateTime)
}

///|
pub fn DateAxisInfo::major_locator(self : DateAxisInfo) -> DateLocator {
  self.locator
}

///|
pub fn DateAxisInfo::major_formatter(self : DateAxisInfo) -> DateFormatter {
  self.formatter.copy()
}

///|
pub fn DateAxisInfo::label(self : DateAxisInfo) -> String {
  self.label
}

///|
pub fn DateAxisInfo::default_limits(
  self : DateAxisInfo,
) -> (DateTime, DateTime) {
  self.default_limits
}

///|
pub fn DateAxisInfo::copy(self : DateAxisInfo) -> DateAxisInfo {
  let locator = self.locator.copy()
  let formatter = self.formatter.copy()
  let formatter = match formatter.mode {
    Auto(settings) =>
      { ..formatter, mode: Auto({ ..settings, locator: Some(locator), }), }
    _ => formatter
  }
  { ..self, locator, formatter, }
}
