///|
/// Body carries an original KDE sample index, coordinate and estimated density,
/// rather than an input observation or probability mass. Quantile carries the
/// original quantile index and value; its requested probability is not retained.
pub(all) enum ViolinPart {
  Body(Int32, Double, Double)
  Mean
  Median
  Minimum
  Maximum
  Range
  Quantile(Int32, Double)
} derive(Eq, Debug)

///|
pub extend ViolinPart with Eq::{equal, not_equal}

///|
pub extend ViolinPart with @debug.Debug::{to_repr}

///|
/// Immutable scalar summary of an original zero-based violin group.
/// No source observations, KDE arrays or mutable statistics are retained.
pub struct ViolinInfo {
  group_index : Int32
  position : Double
  horizontal : Bool
  mean : Double
  median : Double
  minimum : Double
  maximum : Double
  part : ViolinPart
} derive(Eq, Debug)

///|
pub extend ViolinInfo with Eq::{equal, not_equal}

///|
pub extend ViolinInfo with @debug.Debug::{to_repr}

///|
pub fn violin_info(
  group_index : Int32,
  position~ : Double,
  mean~ : Double,
  median~ : Double,
  minimum~ : Double,
  maximum~ : Double,
  part~ : ViolinPart,
  horizontal~ : Bool = false,
) -> ViolinInfo {
  { group_index, position, horizontal, mean, median, minimum, maximum, part, }
}
