///|
/// One cell in a table artist.
pub struct TableCell {
  row : Int32
  column : Int32
  text : String
  facecolor : String
  edgecolor : String
  align : String
  visible_edges : String
}

///|
/// A table laid out in normalized axes coordinates.
pub struct Table {
  cells : Array[TableCell]
  rows : Int32
  columns : Int32
  x : Double
  y : Double
  width : Double
  height : Double
  column_widths : Array[Double]
}

///|
pub fn TableCell::row(self : TableCell) -> Int32 {
  self.row
}

///|
pub fn TableCell::column(self : TableCell) -> Int32 {
  self.column
}

///|
pub fn TableCell::text(self : TableCell) -> String {
  self.text
}

///|
pub fn TableCell::facecolor(self : TableCell) -> String {
  self.facecolor
}

///|
pub fn TableCell::edgecolor(self : TableCell) -> String {
  self.edgecolor
}

///|
pub fn TableCell::align(self : TableCell) -> String {
  self.align
}

///|
pub fn TableCell::visible_edges(self : TableCell) -> String {
  self.visible_edges
}

///|
pub fn Table::cells(self : Table) -> Array[TableCell] {
  self.cells.copy()
}

///|
pub fn Table::rows(self : Table) -> Int32 {
  self.rows
}

///|
pub fn Table::columns(self : Table) -> Int32 {
  self.columns
}

///|
pub fn Table::x(self : Table) -> Double {
  self.x
}

///|
pub fn Table::y(self : Table) -> Double {
  self.y
}

///|
pub fn Table::width(self : Table) -> Double {
  self.width
}

///|
pub fn Table::height(self : Table) -> Double {
  self.height
}

///|
pub fn Table::column_widths(self : Table) -> Array[Double] {
  self.column_widths.copy()
}

///|
pub fn Table::cell(self : Table, row : Int32, column : Int32) -> TableCell? {
  for value in self.cells {
    if value.row == row && value.column == column {
      return Some(value)
    }
  }
  None
}

///|
fn finite_table(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn validate_table_alignment(
  value : String,
  name : String,
) -> Unit raise @core.DataError {
  ignore(name)
  if value != "left" && value != "center" && value != "right" {
    raise @core.DataError::InvalidReference(
      message="table {name} must be left, center, or right",
    )
  }
}

///|
fn validate_table_matrix(
  matrix : Array[Array[String]],
  name : String,
) -> Int32 raise @core.DataError {
  ignore(name)
  if matrix.length() == 0 {
    return 0
  }
  let columns = matrix[0].length()
  for row in matrix {
    if row.length() != columns {
      raise @core.DataError::InvalidReference(
        message="table {name} rows must have equal length",
      )
    }
  }
  columns
}

///|
fn validate_table_colors(
  colors : Array[Array[String]],
  rows : Int32,
  columns : Int32,
) -> Unit raise @core.DataError {
  if colors.length() != 0 {
    if colors.length() != rows {
      raise @core.DataError::InvalidReference(
        message="table cell colours must match text rows",
      )
    }
    for row in colors {
      if row.length() != columns {
        raise @core.DataError::InvalidReference(
          message="table cell colours must match text columns",
        )
      }
    }
  }
}

///|
fn table_edge_mode(value : String) -> Bool {
  value == "closed" ||
  value == "open" ||
  value == "horizontal" ||
  value == "vertical" ||
  (
    value.length() > 0 &&
    value.to_array().all(c => c is ('B' | 'T' | 'L' | 'R'))
  )
}

///|
fn table_color(
  colors : Array[Array[String]],
  row : Int32,
  column : Int32,
  fallback : String,
) -> String {
  if colors.length() == 0 {
    fallback
  } else if colors[row][column] == "" {
    fallback
  } else {
    colors[row][column]
  }
}

///|
fn copy_table(value : Table) -> Table {
  let cells = Array(capacity=value.cells.length())
  for cell in value.cells {
    cells.push(cell)
  }
  {
    cells,
    rows: value.rows,
    columns: value.columns,
    x: value.x,
    y: value.y,
    width: value.width,
    height: value.height,
    column_widths: value.column_widths.copy(),
  }
}

///|
fn make_table(
  cell_text : Array[Array[String]],
  cell_colours : Array[Array[String]],
  row_labels : Array[String],
  row_colours : Array[String],
  col_labels : Array[String],
  col_colours : Array[String],
  cell_loc : String,
  row_loc : String,
  col_loc : String,
  loc : String,
  bbox : Array[Double],
  edges : String,
  col_widths : Array[Double],
) -> Table raise @core.DataError {
  validate_table_alignment(cell_loc, "cell_loc")
  validate_table_alignment(row_loc, "row_loc")
  validate_table_alignment(col_loc, "col_loc")
  if !table_edge_mode(edges) {
    raise @core.DataError::InvalidReference(
      message="table edges must be closed, open, horizontal, vertical, or edge letters",
    )
  }
  let text_columns = validate_table_matrix(cell_text, "cell_text")
  let colour_columns = if cell_colours.length() == 0 {
    text_columns
  } else {
    validate_table_matrix(cell_colours, "cell_colours")
  }
  let columns = Int32::max(text_columns, colour_columns)
  let data_rows = Int32::max(cell_text.length(), cell_colours.length())
  if cell_text.length() != 0 && cell_colours.length() != 0 {
    validate_table_colors(cell_colours, data_rows, columns)
  }
  if row_colours.length() != 0 && row_colours.length() != row_labels.length() {
    raise @core.DataError::InvalidReference(
      message="table row colours must match row labels",
    )
  }
  if col_colours.length() != 0 && col_colours.length() != columns {
    raise @core.DataError::InvalidReference(
      message="table column colours must match columns",
    )
  }
  if col_labels.length() != 0 && col_labels.length() != columns {
    raise @core.DataError::InvalidReference(
      message="table column labels must match columns",
    )
  }
  if row_labels.length() != 0 && row_labels.length() != data_rows {
    raise @core.DataError::InvalidReference(
      message="table row labels must match data rows",
    )
  }
  let header_count = if col_labels.length() == 0 { 0 } else { 1 }
  let row_label_count = if row_labels.length() == 0 { 0 } else { 1 }
  let rows = data_rows + header_count
  let total_columns = columns + row_label_count
  if rows == 0 || total_columns == 0 {
    raise @core.DataError::InvalidReference(
      message="table needs at least one cell",
    )
  }
  let actual_widths = if col_widths.length() == 0 {
    let result = Array(capacity=total_columns)
    for _ in 0..<total_columns {
      result.push(1.0 / Double::from_int(total_columns))
    }
    result
  } else {
    if col_widths.length() != total_columns {
      raise @core.DataError::LengthMismatch(
        expected=total_columns,
        actual=col_widths.length(),
      )
    }
    let mut sum = 0.0
    for width in col_widths {
      if !finite_table(width) || width <= 0.0 {
        raise @core.DataError::InvalidReference(
          message="table column widths must be finite and positive",
        )
      }
      sum += width
    }
    let result = Array(capacity=total_columns)
    for width in col_widths {
      result.push(width / sum)
    }
    result
  }
  let height = Double::min(
    0.8,
    Double::max(0.08, 0.08 * Double::from_int(rows)),
  )
  let (x, y, width, actual_height) = if bbox.length() == 0 {
    let position = match loc {
      "top" | "upper" => (0.05, 1.0 - height - 0.02)
      "center" | "centre" => (0.05, (1.0 - height) / 2.0)
      "bottom" | "lower" => (0.05, 0.02)
      _ =>
        raise @core.DataError::InvalidReference(
          message="table loc must be top, center, or bottom",
        )
    }
    (position.0, position.1, 0.90, height)
  } else {
    if bbox.length() != 4 {
      raise @core.DataError::InvalidReference(
        message="table bbox must contain x, y, width, and height",
      )
    }
    for value in bbox {
      if !finite_table(value) {
        raise @core.DataError::InvalidReference(
          message="table bbox must be finite",
        )
      }
    }
    if bbox[2] <= 0.0 || bbox[3] <= 0.0 {
      raise @core.DataError::InvalidReference(
        message="table bbox size must be positive",
      )
    }
    (bbox[0], bbox[1], bbox[2], bbox[3])
  }
  let cells = Array(capacity=rows * total_columns)
  let header_rows = header_count
  for row in 0..<rows {
    for column in 0..<total_columns {
      let is_header = header_rows == 1 && row == 0
      let is_row_label = row_labels.length() != 0 && column == 0
      let is_corner = is_header && is_row_label
      let data_row = row - header_rows
      let data_column = column - row_label_count
      let text = if is_corner {
        ""
      } else if is_header {
        col_labels[data_column]
      } else if is_row_label {
        row_labels[data_row]
      } else if cell_text.length() == 0 {
        ""
      } else {
        cell_text[data_row][data_column]
      }
      let facecolor = if is_corner {
        "#e5e7eb"
      } else if is_header {
        if col_colours.length() == 0 {
          "#e5e7eb"
        } else {
          col_colours[data_column]
        }
      } else if is_row_label {
        if row_colours.length() == 0 {
          "#f3f4f6"
        } else {
          row_colours[data_row]
        }
      } else {
        table_color(cell_colours, data_row, data_column, "#ffffff")
      }
      let align = if is_corner {
        col_loc
      } else if is_header {
        col_loc
      } else if is_row_label {
        row_loc
      } else {
        cell_loc
      }
      cells.push({
        row,
        column,
        text,
        facecolor,
        edgecolor: "#9ca3af",
        align,
        visible_edges: edges,
      })
    }
  }
  {
    cells,
    rows,
    columns: total_columns,
    x,
    y,
    width,
    height: actual_height,
    column_widths: actual_widths,
  }
}

///|
/// Add a table to the figure's default axes.
pub fn Figure::table(
  self : Figure,
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
) -> Table raise @core.DataError {
  self
  .axes()
  .table(
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

///|
/// Add a table through the axes view.
pub fn Axes::table(
  self : Axes,
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
) -> Table raise @core.DataError {
  let result = make_table(
    cell_text, cell_colours, row_labels, row_colours, col_labels, col_colours, cell_loc,
    row_loc, col_loc, loc, bbox, edges, col_widths,
  )
  self.push_artist(Artist::Table(copy_table(result)))
  result
}
