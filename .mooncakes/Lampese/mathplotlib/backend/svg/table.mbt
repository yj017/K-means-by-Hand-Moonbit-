///|
fn table_edge_visible(edges : String, edge : String) -> Bool {
  if edges == "closed" {
    true
  } else if edges == "open" {
    false
  } else if edges == "horizontal" {
    edge == "B" || edge == "T"
  } else if edges == "vertical" {
    edge == "L" || edge == "R"
  } else {
    edges.contains(edge)
  }
}

///|
fn append_table(
  writer : @xml.Writer,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  table : @render.Table,
) -> Unit {
  if table.rows() <= 0 || table.columns() <= 0 {
    return
  }
  let cell_height = table.height() / Double::from_int(table.rows())
  for cell in table.cells() {
    let mut column_offset = 0.0
    for index in 0..<cell.column() {
      column_offset += table.column_widths()[index]
    }
    let cell_width = table.column_widths()[cell.column()] * table.width()
    let cell_x = left + (table.x() + column_offset) * plot_width
    let cell_y_norm = table.y() +
      table.height() -
      Double::from_int(cell.row() + 1) * cell_height
    let cell_y = top + (1.0 - cell_y_norm - cell_height) * plot_height
    let pixel_width = cell_width * plot_width
    let pixel_height = cell_height * plot_height
    try! writer.empty_element("rect", [
      ("x", float_text(cell_x)),
      ("y", float_text(cell_y)),
      ("width", float_text(pixel_width)),
      ("height", float_text(pixel_height)),
      ("fill", cell.facecolor()),
      ("stroke", "none"),
    ])
    if table_edge_visible(cell.visible_edges(), "B") {
      try! writer.empty_element("line", [
        ("x1", float_text(cell_x)),
        ("y1", float_text(cell_y + pixel_height)),
        ("x2", float_text(cell_x + pixel_width)),
        ("y2", float_text(cell_y + pixel_height)),
        ("stroke", cell.edgecolor()),
        ("stroke-width", "1"),
      ])
    }
    if table_edge_visible(cell.visible_edges(), "T") {
      try! writer.empty_element("line", [
        ("x1", float_text(cell_x)),
        ("y1", float_text(cell_y)),
        ("x2", float_text(cell_x + pixel_width)),
        ("y2", float_text(cell_y)),
        ("stroke", cell.edgecolor()),
        ("stroke-width", "1"),
      ])
    }
    if table_edge_visible(cell.visible_edges(), "L") {
      try! writer.empty_element("line", [
        ("x1", float_text(cell_x)),
        ("y1", float_text(cell_y)),
        ("x2", float_text(cell_x)),
        ("y2", float_text(cell_y + pixel_height)),
        ("stroke", cell.edgecolor()),
        ("stroke-width", "1"),
      ])
    }
    if table_edge_visible(cell.visible_edges(), "R") {
      try! writer.empty_element("line", [
        ("x1", float_text(cell_x + pixel_width)),
        ("y1", float_text(cell_y)),
        ("x2", float_text(cell_x + pixel_width)),
        ("y2", float_text(cell_y + pixel_height)),
        ("stroke", cell.edgecolor()),
        ("stroke-width", "1"),
      ])
    }
    let (anchor, text_x) = match cell.align() {
      "left" => ("start", cell_x + pixel_width * 0.08)
      "center" => ("middle", cell_x + pixel_width / 2.0)
      _ => ("end", cell_x + pixel_width * 0.92)
    }
    append_text(
      writer,
      text_x,
      cell_y + pixel_height * 0.65,
      cell.text(),
      anchor,
      11,
    )
  }
}
