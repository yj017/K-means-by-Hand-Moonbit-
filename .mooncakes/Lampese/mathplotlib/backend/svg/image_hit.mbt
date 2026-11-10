///|
priv struct RenderedCell {
  row : Int32
  column : Int32
  columns : Int32
  value : Double
  x_range : (Double, Double)
  y_range : (Double, Double)
  rectangle : (Double, Double, Double, Double)
}

///|
fn collect_drawing_cell(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  cell : RenderedCell,
  position : (Double, Double, Double, Double),
  kind~ : @drawing.HitKind = Heatmap,
) -> Unit {
  let (left, top, width, height) = position
  let (x, y, w, h) = cell.rectangle
  let x0 = Double::max(left, x)
  let y0 = Double::max(top, y)
  let x1 = Double::min(left + width, x + w)
  let y1 = Double::min(top + height, y + h)
  if x0.is_nan() ||
    x1.is_nan() ||
    y0.is_nan() ||
    y1.is_nan() ||
    x0.is_inf() ||
    x1.is_inf() ||
    y0.is_inf() ||
    y1.is_inf() ||
    x1 <= x0 ||
    y1 <= y0 {
    return
  }
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    cell.row * cell.columns + cell.column,
    cell.x_range.0 / 2.0 + cell.x_range.1 / 2.0,
    cell.y_range.0 / 2.0 + cell.y_range.1 / 2.0,
    x0 / 2.0 + x1 / 2.0,
    y0 / 2.0 + y1 / 2.0,
  )
  let info = @drawing.hit_info(
    point,
    kind,
    value=cell.value,
    cell=Some(
      @drawing.cell_info(cell.row, cell.column, cell.x_range, cell.y_range),
    ),
  )
  output.points.push(point)
  output.targets.push(
    @drawing.hit_target(info, Rectangle(x, y, w, h), position),
  )
}
