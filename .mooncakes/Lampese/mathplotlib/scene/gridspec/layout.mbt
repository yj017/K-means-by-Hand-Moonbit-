///|
/// Errors raised by grid layout construction and indexing.
pub(all) suberror LayoutError {
  InvalidDimension
  InvalidSpacing
  InvalidRatios
  InvalidBounds
  CellOutOfBounds
}

///|
/// A rectangular area. Coordinate units and origin are defined by the
/// producing API: layouts return display pixels; Axes::get_position returns
/// normalized Figure coordinates with a lower-left origin.
pub struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
/// Construct a rectangle without imposing coordinate units.
///
/// ```mbt check
/// test {
///   let bounds = @gridspec.rect(10.0, 20.0, 30.0, 40.0)
///   assert_eq((bounds.x(), bounds.y()), (10.0, 20.0))
///   assert_eq((bounds.width(), bounds.height()), (30.0, 40.0))
/// }
/// ```
pub fn rect(x : Double, y : Double, width : Double, height : Double) -> Rect {
  { x, y, width, height, }
}

///|
/// The mutable layout state shared by a GridSpec and its nested children.
priv struct GridLayout {
  rows : Int32
  columns : Int32
  mut hspace : Double?
  mut vspace : Double?
  mut width_ratios : Array[Double]
  mut height_ratios : Array[Double]
}

///|
/// The span that owns a nested GridSpec.
///
/// The reference keeps changes to a parent GridSpec's ratios visible to
/// children, matching Matplotlib's GridSpecFromSubplotSpec behavior.
priv struct GridParent {
  layout : @ref.Ref[GridLayout]
  row_start : Int32
  row_end : Int32
  column_start : Int32
  column_end : Int32
}

///|
pub fn Rect::x(self : Rect) -> Double {
  self.x
}

///|
pub fn Rect::y(self : Rect) -> Double {
  self.y
}

///|
pub fn Rect::width(self : Rect) -> Double {
  self.width
}

///|
pub fn Rect::height(self : Rect) -> Double {
  self.height
}

///|
/// A regular rows-by-columns grid with deterministic spacing.
pub struct GridSpec {
  rows : Int32
  columns : Int32
  mut hspace : Double
  mut vspace : Double
  mut width_ratios : Array[Double]
  mut height_ratios : Array[Double]
  priv mut parent_chain : Array[GridParent]
  priv layout_ref : @ref.Ref[GridLayout]
  share_x : ShareMode
  share_y : ShareMode
}

///|
/// A rectangular span of rows and columns in a GridSpec.
pub struct SubplotSpec {
  grid : GridSpec
  row_start : Int32
  row_end : Int32
  column_start : Int32
  column_end : Int32
}

///|
/// Construct a regular grid. Spacing is measured as a fraction of the cell size.
/// `hspace` is horizontal and `vspace` vertical. Omitted values inherit the
/// figure's spacing during layout, falling back to 0.1 for standalone grids.
pub fn gridspec(
  rows : Int32,
  columns : Int32,
  hspace? : Double,
  vspace? : Double,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> GridSpec raise LayoutError {
  if rows <= 0 || columns <= 0 {
    raise LayoutError::InvalidDimension
  }
  validate_spacing(hspace.unwrap_or(0.1))
  validate_spacing(vspace.unwrap_or(0.1))
  let width_ratios = normalize_ratios(columns, width_ratios)
  let height_ratios = normalize_ratios(rows, height_ratios)
  let layout_ref = @ref.new({
    rows,
    columns,
    hspace,
    vspace,
    width_ratios: width_ratios.copy(),
    height_ratios: height_ratios.copy(),
  })
  {
    rows,
    columns,
    hspace: hspace.unwrap_or(0.1),
    vspace: vspace.unwrap_or(0.1),
    width_ratios,
    height_ratios,
    parent_chain: [],
    layout_ref,
    share_x: ShareMode::None,
    share_y: ShareMode::None,
  }
}

///|
fn normalize_ratios(
  expected : Int32,
  values : Array[Double],
) -> Array[Double] raise LayoutError {
  let source = if values.length() == 0 {
    let result = Array(capacity=expected)
    for _ in 0..<expected {
      result.push(1.0)
    }
    result
  } else {
    values.copy()
  }
  if source.length() != expected {
    raise LayoutError::InvalidRatios
  }
  let mut total = 0.0
  for value in source {
    if value.is_nan() || value.is_inf() || value <= 0.0 {
      raise LayoutError::InvalidRatios
    }
    total += value
  }
  if total <= 0.0 || total.is_nan() || total.is_inf() {
    raise LayoutError::InvalidRatios
  }
  source
}

///|
fn validate_spacing(value : Double) -> Unit raise LayoutError {
  if value < 0.0 || value.is_nan() || value.is_inf() {
    raise LayoutError::InvalidSpacing
  }
}

///|
pub fn GridSpec::rows(self : GridSpec) -> Int32 {
  self.layout_ref.val.rows
}

///|
pub fn GridSpec::columns(self : GridSpec) -> Int32 {
  self.layout_ref.val.columns
}

///|
pub fn GridSpec::hspace(self : GridSpec) -> Double {
  self.layout_ref.val.hspace.unwrap_or(0.1)
}

///|
pub fn GridSpec::vspace(self : GridSpec) -> Double {
  self.layout_ref.val.vspace.unwrap_or(0.1)
}

///|
/// Update the horizontal gap between grid columns.
///
/// The value is measured as a fraction of the average cell width. Because
/// nested grids retain the parent layout reference, existing child subplot
/// rectangles observe this change immediately.
pub fn GridSpec::set_hspace(
  self : GridSpec,
  value : Double,
) -> Unit raise LayoutError {
  validate_spacing(value)
  self.hspace = value
  self.layout_ref.val.hspace = Some(value)
}

///|
/// Update the vertical gap between grid rows.
///
/// The value is measured as a fraction of the average cell height and is
/// visible through all nested subplot specifications belonging to this grid.
pub fn GridSpec::set_vspace(
  self : GridSpec,
  value : Double,
) -> Unit raise LayoutError {
  validate_spacing(value)
  self.vspace = value
  self.layout_ref.val.vspace = Some(value)
}

///|
/// Return relative widths for the grid columns.
pub fn GridSpec::width_ratios(self : GridSpec) -> Array[Double] {
  self.layout_ref.val.width_ratios.copy()
}

///|
/// Return relative heights for the grid rows.
pub fn GridSpec::height_ratios(self : GridSpec) -> Array[Double] {
  self.layout_ref.val.height_ratios.copy()
}

///|
/// Set relative widths for the grid columns.
pub fn GridSpec::set_width_ratios(
  self : GridSpec,
  values : Array[Double],
) -> Unit raise LayoutError {
  let normalized = normalize_ratios(self.columns, values)
  self.width_ratios = normalized.copy()
  self.layout_ref.val.width_ratios = normalized
}

///|
/// Set relative heights for the grid rows.
pub fn GridSpec::set_height_ratios(
  self : GridSpec,
  values : Array[Double],
) -> Unit raise LayoutError {
  let normalized = normalize_ratios(self.rows, values)
  self.height_ratios = normalized.copy()
  self.layout_ref.val.height_ratios = normalized
}

///|
/// Select a half-open row/column span from this grid.
pub fn GridSpec::subplot(
  self : GridSpec,
  row_start : Int32,
  row_end : Int32,
  column_start : Int32,
  column_end : Int32,
) -> SubplotSpec raise LayoutError {
  if row_start < 0 ||
    row_start >= row_end ||
    row_end > self.rows ||
    column_start < 0 ||
    column_start >= column_end ||
    column_end > self.columns {
    raise LayoutError::CellOutOfBounds
  }
  { grid: self, row_start, row_end, column_start, column_end, }
}

///|
/// Select one cell as a SubplotSpec.
///
/// This is the explicit equivalent of Matplotlib's ``gs[row, column]``
/// indexing, while remaining convenient to call from MoonBit.
pub fn GridSpec::cell_spec(
  self : GridSpec,
  row : Int32,
  column : Int32,
) -> SubplotSpec raise LayoutError {
  let normalized_row = if row < 0 { row + self.rows } else { row }
  let normalized_column = if column < 0 {
    column + self.columns
  } else {
    column
  }
  self.subplot(
    normalized_row,
    normalized_row + 1,
    normalized_column,
    normalized_column + 1,
  )
}

///|
/// Return the row and column dimensions of this grid.
pub fn GridSpec::geometry(self : GridSpec) -> (Int32, Int32) {
  (self.rows(), self.columns())
}

///|
/// Matplotlib-compatible name for `geometry`.
pub fn GridSpec::get_geometry(self : GridSpec) -> (Int32, Int32) {
  self.geometry()
}

///|
/// Matplotlib-compatible name for the width ratios getter.
pub fn GridSpec::get_width_ratios(self : GridSpec) -> Array[Double] {
  self.width_ratios()
}

///|
/// Matplotlib-compatible name for the height ratios getter.
pub fn GridSpec::get_height_ratios(self : GridSpec) -> Array[Double] {
  self.height_ratios()
}

///|
/// Select a cell by its row-major flat index.
///
/// Negative indices count from the end, matching Python's indexing rule.
pub fn GridSpec::index(
  self : GridSpec,
  index : Int32,
) -> SubplotSpec raise LayoutError {
  let total = self.rows() * self.columns()
  let normalized = if index < 0 { index + total } else { index }
  if normalized < 0 || normalized >= total {
    raise LayoutError::CellOutOfBounds
  }
  self.cell_spec(normalized / self.columns(), normalized % self.columns())
}

///|
/// Select a nested grid inside this subplot span.
///
/// The returned GridSpec keeps the parent span in its geometry chain, so a
/// child can be passed directly to `Figure::add_subplot` after selecting one
/// of its own cells.
pub fn SubplotSpec::subgridspec(
  self : SubplotSpec,
  rows : Int32,
  columns : Int32,
  hspace? : Double,
  vspace? : Double,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> GridSpec raise LayoutError {
  let nested = gridspec(
    rows,
    columns,
    hspace?,
    vspace?,
    width_ratios~,
    height_ratios~,
  )
  let parents = copy_parent_chain(self.grid.parent_chain)
  parents.push({
    layout: self.grid.layout_ref,
    row_start: self.row_start,
    row_end: self.row_end,
    column_start: self.column_start,
    column_end: self.column_end,
  })
  nested.parent_chain = parents
  nested
}

///|
/// Copy the parent chain without sharing its ratio arrays.
fn copy_parent_chain(parents : Array[GridParent]) -> Array[GridParent] {
  let result = Array(capacity=parents.length())
  for parent in parents {
    result.push({
      layout: parent.layout,
      row_start: parent.row_start,
      row_end: parent.row_end,
      column_start: parent.column_start,
      column_end: parent.column_end,
    })
  }
  result
}

///|
/// Return the selected row span.
pub fn SubplotSpec::row_start(self : SubplotSpec) -> Int32 {
  self.row_start
}

///|
pub fn SubplotSpec::row_end(self : SubplotSpec) -> Int32 {
  self.row_end
}

///|
/// Return the selected column span.
pub fn SubplotSpec::column_start(self : SubplotSpec) -> Int32 {
  self.column_start
}

///|
pub fn SubplotSpec::column_end(self : SubplotSpec) -> Int32 {
  self.column_end
}

///|
/// Return the inclusive row range occupied by this subplot.
pub fn SubplotSpec::row_span(self : SubplotSpec) -> (Int32, Int32) {
  (self.row_start, self.row_end - 1)
}

///|
/// Return the inclusive column range occupied by this subplot.
pub fn SubplotSpec::column_span(self : SubplotSpec) -> (Int32, Int32) {
  (self.column_start, self.column_end - 1)
}

///|
/// Return whether this subplot touches the first row of its grid.
pub fn SubplotSpec::is_first_row(self : SubplotSpec) -> Bool {
  self.row_start == 0
}

///|
/// Return whether this subplot touches the last row of its grid.
pub fn SubplotSpec::is_last_row(self : SubplotSpec) -> Bool {
  self.row_end == self.grid.rows()
}

///|
/// Return whether this subplot touches the first column of its grid.
pub fn SubplotSpec::is_first_col(self : SubplotSpec) -> Bool {
  self.column_start == 0
}

///|
/// Return whether this subplot touches the last column of its grid.
pub fn SubplotSpec::is_last_col(self : SubplotSpec) -> Bool {
  self.column_end == self.grid.columns()
}

///|
/// Return the GridSpec owning this span.
pub fn SubplotSpec::grid(self : SubplotSpec) -> GridSpec {
  self.grid
}

///|
/// Matplotlib-compatible name for the owning GridSpec getter.
pub fn SubplotSpec::get_gridspec(self : SubplotSpec) -> GridSpec {
  self.grid
}

///|
/// Return grid dimensions and inclusive flat start/end indices.
pub fn SubplotSpec::get_geometry(
  self : SubplotSpec,
) -> (Int32, Int32, Int32, Int32) {
  let rows = self.grid.rows()
  let columns = self.grid.columns()
  let start = self.row_start * columns + self.column_start
  let end = (self.row_end - 1) * columns + self.column_end - 1
  (rows, columns, start, end)
}

///|
/// Return the outermost SubplotSpec that contains this nested span.
pub fn SubplotSpec::get_topmost_subplotspec(self : SubplotSpec) -> SubplotSpec {
  if self.grid.parent_chain.length() == 0 {
    return self
  }
  let parent = self.grid.parent_chain[0]
  let layout = parent.layout.val
  let parent_grid : GridSpec = {
    rows: layout.rows,
    columns: layout.columns,
    hspace: layout.hspace.unwrap_or(0.1),
    vspace: layout.vspace.unwrap_or(0.1),
    width_ratios: layout.width_ratios.copy(),
    height_ratios: layout.height_ratios.copy(),
    parent_chain: [],
    layout_ref: parent.layout,
    share_x: ShareMode::None,
    share_y: ShareMode::None,
  }
  {
    grid: parent_grid,
    row_start: parent.row_start,
    row_end: parent.row_end,
    column_start: parent.column_start,
    column_end: parent.column_end,
  }
}

///|
fn GridSpec::cell_geometry(
  self : GridSpec,
  row_start : Int32,
  row_end : Int32,
  column_start : Int32,
  column_end : Int32,
  figure_width : Int32,
  figure_height : Int32,
  margin : Int32,
) -> Rect {
  let container = {
    x: Double::from_int(margin),
    y: Double::from_int(margin),
    width: Double::from_int(figure_width - margin * 2),
    height: Double::from_int(figure_height - margin * 2),
  }
  self.cell_geometry_in(
    row_start,
    row_end,
    column_start,
    column_end,
    container,
    None,
    None,
  )
}

///|
/// Compute a span inside a caller-provided display rectangle.
fn GridSpec::cell_geometry_in(
  self : GridSpec,
  row_start : Int32,
  row_end : Int32,
  column_start : Int32,
  column_end : Int32,
  container : Rect,
  hspace_override : Double?,
  vspace_override : Double?,
) -> Rect {
  let mut container = container
  for parent in self.parent_chain {
    let layout = parent.layout.val
    container = grid_span_geometry(
      layout,
      container,
      parent.row_start,
      parent.row_end,
      parent.column_start,
      parent.column_end,
      hspace_override,
      vspace_override,
    )
  }
  let layout = self.layout_ref.val
  grid_span_geometry(
    layout, container, row_start, row_end, column_start, column_end, hspace_override,
    vspace_override,
  )
}

///|
/// Compute a span inside an arbitrary display rectangle.
fn grid_span_geometry(
  layout : GridLayout,
  container : Rect,
  row_start : Int32,
  row_end : Int32,
  column_start : Int32,
  column_end : Int32,
  hspace_override : Double?,
  vspace_override : Double?,
) -> Rect {
  let hspace = match layout.hspace {
    Some(value) => value
    None => hspace_override.unwrap_or(0.1)
  }
  let vspace = match layout.vspace {
    Some(value) => value
    None => vspace_override.unwrap_or(0.1)
  }
  let total_width = layout.width_ratios.fold(init=0.0, (sum, ratio) => {
    sum + ratio
  })
  let total_height = layout.height_ratios.fold(init=0.0, (sum, ratio) => {
    sum + ratio
  })
  let base_width = container.width /
    (
      Double::from_int(layout.columns) +
      hspace * Double::from_int(layout.columns - 1)
    )
  let base_height = container.height /
    (Double::from_int(layout.rows) + vspace * Double::from_int(layout.rows - 1))
  let horizontal_gap = hspace * base_width
  let vertical_gap = vspace * base_height
  let width_unit = base_width * Double::from_int(layout.columns) / total_width
  let height_unit = base_height * Double::from_int(layout.rows) / total_height
  let mut x = container.x
  for column in 0..<column_start {
    x += layout.width_ratios[column] * width_unit + horizontal_gap
  }
  let mut right = x
  for column in column_start..<column_end {
    right += layout.width_ratios[column] * width_unit
    if column + 1 < column_end {
      right += horizontal_gap
    }
  }
  let mut y = container.y
  for row in 0..<row_start {
    y += layout.height_ratios[row] * height_unit + vertical_gap
  }
  let mut bottom = y
  for row in row_start..<row_end {
    bottom += layout.height_ratios[row] * height_unit
    if row + 1 < row_end {
      bottom += vertical_gap
    }
  }
  { x, y, width: right - x, height: bottom - y, }
}

///|
/// Compute the display rectangle occupied by this span.
pub fn SubplotSpec::rect(
  self : SubplotSpec,
  figure_width : Int32,
  figure_height : Int32,
  margin : Int32,
) -> Rect {
  self.grid.cell_geometry(
    self.row_start,
    self.row_end,
    self.column_start,
    self.column_end,
    figure_width,
    figure_height,
    margin,
  )
}

///|
/// Compute this span inside normalized figure bounds.
///
/// `left`, `bottom`, `right`, and `top` are fractions of the figure size,
/// with the same orientation as Matplotlib's subplot parameters. Display
/// coordinates still use the SVG top-left origin, so `bottom` is converted
/// to a top-down y coordinate here. Figure spacing applies to each nested
/// grid where that grid has not explicitly set its own spacing. `wspace` is
/// horizontal and `hspace` vertical, following Matplotlib's parameter names.
pub fn SubplotSpec::rect_with_bounds(
  self : SubplotSpec,
  figure_width : Int32,
  figure_height : Int32,
  left : Double,
  bottom : Double,
  right : Double,
  top : Double,
  wspace? : Double,
  hspace? : Double,
) -> Rect {
  let width = Double::from_int(figure_width)
  let height = Double::from_int(figure_height)
  let container = {
    x: width * left,
    y: height * (1.0 - top),
    width: width * (right - left),
    height: height * (top - bottom),
  }
  self.grid.cell_geometry_in(
    self.row_start,
    self.row_end,
    self.column_start,
    self.column_end,
    container,
    wspace,
    hspace,
  )
}

///|
/// Compute one cell rectangle inside a figure display area.
pub fn GridSpec::cell(
  self : GridSpec,
  row : Int32,
  column : Int32,
  figure_width : Int32,
  figure_height : Int32,
  margin : Int32,
) -> Rect raise LayoutError {
  if row < 0 || row >= self.rows || column < 0 || column >= self.columns {
    raise LayoutError::CellOutOfBounds
  }
  self.cell_geometry(
    row,
    row + 1,
    column,
    column + 1,
    figure_width,
    figure_height,
    margin,
  )
}

///|
/// Compute all cell rectangles in row-major order.
pub fn GridSpec::cells(
  self : GridSpec,
  figure_width : Int32,
  figure_height : Int32,
  margin : Int32,
) -> Array[Rect] raise LayoutError {
  let result = Array(capacity=self.rows * self.columns)
  for row in 0..<self.rows {
    for column in 0..<self.columns {
      result.push(self.cell(row, column, figure_width, figure_height, margin))
    }
  }
  result
}
