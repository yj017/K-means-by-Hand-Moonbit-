///|
/// The resolved face's original ordered vertex indices and scalar provenance.
/// `HitInfo.value` is the supplied face value or the existing vertex mean.
pub struct TriColorInfo {
  vertices : (Int32, Int32, Int32)
  vertex_mean : Bool
} derive(Eq, Debug)

///|
pub extend TriColorInfo with Eq::{equal, not_equal}

///|
pub extend TriColorInfo with @debug.Debug::{to_repr}

///|
pub fn tricolor_info(
  vertices : (Int32, Int32, Int32),
  vertex_mean~ : Bool = false,
) -> TriColorInfo {
  { vertices, vertex_mean, }
}
