///|
/// Add a labeled table to the current axes.
pub fn table(
  cell_text~ : Array[Array[String]] = [],
  cell_colours~ : Array[Array[String]] = [],
  cell_loc~ : String = "right",
  col_widths~ : Array[Double] = [],
  row_labels~ : Array[String] = [],
  row_colours~ : Array[String] = [],
  row_loc~ : String = "left",
  col_labels~ : Array[String] = [],
  col_colours~ : Array[String] = [],
  col_loc~ : String = "center",
  loc~ : String = "bottom",
  bbox~ : Array[Double] = [],
  edges~ : String = "closed",
) -> @scene.Table raise @core.DataError {
  require_axes().table(
    cell_text~,
    cell_colours~,
    cell_loc~,
    col_widths~,
    row_labels~,
    row_colours~,
    row_loc~,
    col_labels~,
    col_colours~,
    col_loc~,
    loc~,
    bbox~,
    edges~,
  )
}
