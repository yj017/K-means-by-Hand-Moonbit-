///|
/// Original zero-based matrix indices and the cell's data-space intervals.
/// Intervals retain their source orientation, including reversed extents.
pub struct CellInfo {
  row : Int32
  column : Int32
  x_range : (Double, Double)
  y_range : (Double, Double)
} derive(Eq, Debug)

///|
pub extend CellInfo with Eq::{equal, not_equal}

///|
pub extend CellInfo with @debug.Debug::{to_repr}

///|
pub fn cell_info(
  row : Int32,
  column : Int32,
  x_range : (Double, Double),
  y_range : (Double, Double),
) -> CellInfo {
  { row, column, x_range, y_range, }
}
