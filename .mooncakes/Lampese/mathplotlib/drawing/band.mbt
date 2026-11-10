///|
/// Bounds at the selected original area sample, retaining their input direction.
/// Horizontal bands are sampled at data_y; vertical bands at data_x.
/// A stacked area's HitInfo.value is the original series value, rather than a
/// subtraction of its accumulated bounds. For other bands it is the second bound.
pub struct BandInfo {
  lower : Double
  upper : Double
  horizontal : Bool
  stacked : Bool
} derive(Eq, Debug)

///|
pub extend BandInfo with Eq::{equal, not_equal}

///|
pub extend BandInfo with @debug.Debug::{to_repr}

///|
pub fn band_info(
  lower : Double,
  upper : Double,
  horizontal~ : Bool = false,
  stacked~ : Bool = false,
) -> BandInfo {
  { lower, upper, horizontal, stacked, }
}
