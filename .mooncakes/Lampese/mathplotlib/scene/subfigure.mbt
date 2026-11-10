///|
/// A nested figure region backed by a parent Figure and a SubplotSpec span.
///
/// SubFigure axes are regular scene Axes owned by the parent Figure, so they
/// participate in the same SVG render and retain the parent GridSpec's live
/// ratio updates.
pub struct SubFigure {
  figure : Figure
  data : @ref.Ref[SubFigureData]
}

///|
/// Add a nested figure region at a GridSpec span.
pub fn Figure::add_subfigure(
  self : Figure,
  spec : @gridspec.SubplotSpec,
) -> SubFigure {
  let data = @ref.new({ spec, title: None, axes: [], subfigures: [], })
  self.subfigures.push(data)
  { figure: self, data, }
}

///|
/// Return all nested figure regions registered on this Figure.
pub fn Figure::subfigures(self : Figure) -> Array[SubFigure] {
  let result = Array(capacity=self.subfigures.length())
  for data in self.subfigures {
    result.push({ figure: self, data, })
  }
  result
}

///|
/// Return the parent Figure.
pub fn SubFigure::figure(self : SubFigure) -> Figure {
  self.figure
}

///|
/// Return the GridSpec span occupied by this nested figure.
pub fn SubFigure::subplot_spec(self : SubFigure) -> @gridspec.SubplotSpec {
  self.data.val.spec
}

///|
/// Return the current display rectangle of this nested figure.
pub fn SubFigure::rect(self : SubFigure) -> @gridspec.Rect {
  self.figure.subplot_rect(self.data.val.spec)
}

///|
/// Set the nested figure title.
pub fn SubFigure::set_title(self : SubFigure, title : String) -> Unit {
  self.data.val.title = Some(title)
}

///|
/// Matplotlib-compatible alias for `set_title`.
pub fn SubFigure::suptitle(self : SubFigure, title : String) -> Unit {
  self.set_title(title)
}

///|
/// Return the nested figure title, if one was configured.
pub fn SubFigure::title(self : SubFigure) -> String? {
  self.data.val.title
}

///|
/// Add an Axes owned by the parent Figure to this nested region.
pub fn SubFigure::add_subplot(
  self : SubFigure,
  spec : @gridspec.SubplotSpec,
) -> Axes {
  let axes = self.figure.add_subplot(spec)
  self.data.val.axes.push(axes.state)
  axes
}

///|
/// Create a regular nested grid and add all of its axes.
pub fn SubFigure::subplots(
  self : SubFigure,
  rows : Int32,
  columns : Int32,
  hspace? : Double,
  vspace? : Double,
  share_x~ : Bool = false,
  share_y~ : Bool = false,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> Array[Axes] raise @gridspec.LayoutError {
  let grid = self.data.val.spec.subgridspec(
    rows,
    columns,
    hspace?,
    vspace?,
    width_ratios~,
    height_ratios~,
  )
  let configured = grid.with_shared_axes(
    if share_x {
      @gridspec.ShareMode::All
    } else {
      @gridspec.ShareMode::None
    },
    if share_y {
      @gridspec.ShareMode::All
    } else {
      @gridspec.ShareMode::None
    },
  )
  self.subplots_with_grid(configured)
}

///|
/// Create nested axes according to a GridSpec's sharing constraints.
pub fn SubFigure::subplots_with_grid(
  self : SubFigure,
  grid : @gridspec.GridSpec,
) -> Array[Axes] raise @gridspec.LayoutError {
  let result : Array[Axes] = []
  for row in 0..<grid.rows() {
    for column in 0..<grid.columns() {
      let x_target = grid_share_target(
        result,
        grid.share_x_mode(),
        row,
        column,
        grid.columns(),
      )
      let y_target = grid_share_target(
        result,
        grid.share_y_mode(),
        row,
        column,
        grid.columns(),
      )
      let axes = self.figure.add_subplot_with_targets(
        grid.cell_spec(row, column),
        x_target,
        y_target,
      )
      self.data.val.axes.push(axes.state)
      axes.apply_grid_label_visibility(grid, row, column)
      result.push(axes)
    }
  }
  result
}

///|
/// Add a child nested figure region inside this SubFigure.
pub fn SubFigure::add_subfigure(
  self : SubFigure,
  spec : @gridspec.SubplotSpec,
) -> SubFigure {
  let data = @ref.new({ spec, title: None, axes: [], subfigures: [], })
  self.data.val.subfigures.push(data)
  { figure: self.figure, data, }
}

///|
/// Return child nested figures registered on this SubFigure.
pub fn SubFigure::subfigures(self : SubFigure) -> Array[SubFigure] {
  let result = Array(capacity=self.data.val.subfigures.length())
  for data in self.data.val.subfigures {
    result.push({ figure: self.figure, data, })
  }
  result
}

///|
/// Return attached axes created directly through this SubFigure handle.
pub fn SubFigure::axes_list(self : SubFigure) -> Array[Axes] {
  let result = Array(capacity=self.data.val.axes.length())
  for state in self.data.val.axes {
    let axes = { figure: self.figure, state, }
    if axes.is_attached() {
      result.push(axes)
    }
  }
  result
}

///|
/// Matplotlib-compatible alias for `axes_list`.
pub fn SubFigure::get_axes(self : SubFigure) -> Array[Axes] {
  self.axes_list()
}

///|
/// Clear this nested region's axes and title.
pub fn SubFigure::clear(self : SubFigure) -> Unit {
  try! self.clear_checked()
}

///|
/// Clear each panel in this retained nested region through the same checked path.
pub fn SubFigure::clear_checked(self : SubFigure) -> Unit raise @core.DataError {
  self.data.val.clear_axes_checked(self.figure)
}

///|
fn SubFigureData::clear_axes_checked(
  self : SubFigureData,
  figure : Figure,
) -> Unit raise @core.DataError {
  for state in self.axes.copy() {
    ({ figure, state, } : Axes).clear_checked()
  }
  for child in self.subfigures {
    child.val.clear_axes_checked(figure)
  }
  self.title = None
}
