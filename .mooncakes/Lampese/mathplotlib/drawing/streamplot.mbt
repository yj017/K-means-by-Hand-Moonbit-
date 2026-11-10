///|
/// Bilinear field samples at a generated trajectory-edge midpoint, not original
/// observations or a vector re-evaluated under the pointer. HitInfo.value is v.
pub struct StreamplotInfo {
  seed_index : Int32
  u : Double
  v : Double
  color_value : Double?
} derive(Eq, Debug)

///|
pub extend StreamplotInfo with Eq::{equal, not_equal}

///|
pub extend StreamplotInfo with @debug.Debug::{to_repr}

///|
pub fn streamplot_info(
  seed_index : Int32,
  u : Double,
  v : Double,
  color_value~ : Double? = None,
) -> StreamplotInfo {
  { seed_index, u, v, color_value, }
}
