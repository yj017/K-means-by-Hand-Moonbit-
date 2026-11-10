///|
/// The already evaluated statistic stored in a hexagonal bin. Color bins
/// (linear/log) do not change this statistic or its source value.
pub(all) enum HexbinReduction {
  Count
  Mean
  Sum
  Min
  Max
  Custom
} derive(Eq, Debug)

///|
pub extend HexbinReduction with Eq::{equal, not_equal}

///|
pub extend HexbinReduction with @debug.Debug::{to_repr}

///|
/// Original lattice indices and sample count for one occupied hexagonal bin.
/// Even rows use integer grid centers; odd rows offset X by half a column.
/// The original center is HitPoint.data_x/data_y; HitInfo.value is the stored
/// count or reduced scalar, never its normalized color or logarithm.
pub struct HexbinInfo {
  row : Int32
  column : Int32
  count : Int32
  reduction : HexbinReduction
} derive(Eq, Debug)

///|
pub extend HexbinInfo with Eq::{equal, not_equal}

///|
pub extend HexbinInfo with @debug.Debug::{to_repr}

///|
pub fn hexbin_info(
  row : Int32,
  column : Int32,
  count : Int32,
  reduction~ : HexbinReduction = Count,
) -> HexbinInfo {
  { row, column, count, reduction, }
}
