///|
/// The visible component of a box-and-whisker plot. Outlier carries the
/// original outlier value; other parts share their group's summary statistics.
pub(all) enum BoxPart {
  Box
  LowerWhisker
  UpperWhisker
  LowerCap
  UpperCap
  Outlier(Double)
} derive(Eq, Debug)

///|
pub extend BoxPart with Eq::{equal, not_equal}

///|
pub extend BoxPart with @debug.Debug::{to_repr}

///|
/// A scalar snapshot of one original zero-based boxplot group. No source
/// arrays or mutable BoxStats collections are retained by an interactive frame.
pub struct BoxInfo {
  group_index : Int32
  q1 : Double
  median : Double
  q3 : Double
  lower_whisker : Double
  upper_whisker : Double
  part : BoxPart
} derive(Eq, Debug)

///|
pub extend BoxInfo with Eq::{equal, not_equal}

///|
pub extend BoxInfo with @debug.Debug::{to_repr}

///|
pub fn box_info(
  group_index : Int32,
  q1~ : Double,
  median~ : Double,
  q3~ : Double,
  lower_whisker~ : Double,
  upper_whisker~ : Double,
  part~ : BoxPart = Box,
) -> BoxInfo {
  { group_index, q1, median, q3, lower_whisker, upper_whisker, part, }
}
