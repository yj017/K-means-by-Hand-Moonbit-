///|
/// Immutable source information for one flat rectangular mesh face.
/// Color normalization affects paint only; value remains the original scalar.
pub struct MeshHitData {
  cell : @drawing.CellInfo
  columns : Int32
  value : Double
  histogram : Bool
}

///|
pub fn mesh_hit_data(
  row : Int32,
  column : Int32,
  columns : Int32,
  value : Double,
  x_range : (Double, Double),
  y_range : (Double, Double),
  histogram~ : Bool = false,
) -> MeshHitData {
  {
    cell: @drawing.cell_info(row, column, x_range, y_range),
    columns,
    value,
    histogram,
  }
}
