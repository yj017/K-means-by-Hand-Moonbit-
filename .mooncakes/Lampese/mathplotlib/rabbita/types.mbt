///|
/// Fail explicitly when an SVG feature cannot be represented by public Rabbita APIs.
pub(all) suberror AdapterError {
  InvalidSvg(String)
  UnsupportedElement(String)
  UnsupportedAttribute(String, String)
} derive(Eq, Debug)

///|
pub extend AdapterError with Eq::{equal, not_equal}

///|
pub extend AdapterError with @debug.Debug::{to_repr}

///|
/// Messages describe interactions; the application owns its model and updates.
pub(all) enum Interaction {
  Hover(@drawing.HitPoint?)
  Click(@drawing.HitPoint?)
  ToggleSeries(String)
} derive(Eq, Debug)

///|
pub extend Interaction with Eq::{equal, not_equal}

///|
pub extend Interaction with @debug.Debug::{to_repr}

///|
/// An application-defined series key and its current legend presentation.
pub struct LegendItem {
  priv key : String
  priv label : String
  priv color : String
  priv visible : Bool
}

///|
pub fn legend_item(
  key : String,
  label : String,
  color : String,
  visible : Bool,
) -> LegendItem {
  { key, label, color, visible, }
}
