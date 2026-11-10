///|
/// The corner of an axes panel used to anchor its legend box.
/// Shared by the public scene API and output backends.
pub(all) enum LegendPosition {
  UpperRight
  UpperLeft
  LowerRight
  LowerLeft
} derive(Debug, Eq)

///|
pub extend LegendPosition with @debug.Debug::{to_repr}

///|
pub extend LegendPosition with Eq::{equal, not_equal}
