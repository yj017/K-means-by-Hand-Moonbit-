///|
/// Original data-space vector components. Position remains in HitPoint.
/// Quiver's general HitInfo.value is the original v, not a magnitude.
pub struct VectorInfo {
  u : Double
  v : Double
} derive(Eq, Debug)

///|
pub extend VectorInfo with Eq::{equal, not_equal}

///|
pub extend VectorInfo with @debug.Debug::{to_repr}

///|
pub fn vector_info(u : Double, v : Double) -> VectorInfo {
  { u, v, }
}
