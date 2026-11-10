///|
fn grid_share_target(
  previous : Array[Axes],
  mode : @gridspec.ShareMode,
  row : Int32,
  column : Int32,
  columns : Int32,
) -> @ref.Ref[AxesData]? {
  let index = match mode {
    @gridspec.ShareMode::None => return None
    @gridspec.ShareMode::All => 0
    @gridspec.ShareMode::Row => row * columns
    @gridspec.ShareMode::Column => column
  }
  if index < previous.length() {
    Some(previous[index].state)
  } else {
    None
  }
}

///|
/// Create axes sequentially, retaining each coordinate's construction target.
pub fn Figure::subplots_with_grid(
  self : Figure,
  grid : @gridspec.GridSpec,
) -> Array[Axes] raise @gridspec.LayoutError {
  self.axes.clear()
  self.axes_selection.clear()
  self.colorbars.clear()
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
      let axes = self.add_subplot_with_targets(
        grid.cell_spec(row, column),
        x_target,
        y_target,
      )
      axes.apply_grid_label_visibility(grid, row, column)
      result.push(axes)
    }
  }
  result
}

///|
fn Axes::apply_grid_label_visibility(
  self : Axes,
  grid : @gridspec.GridSpec,
  row : Int32,
  column : Int32,
) -> Unit {
  self.state.val.show_x_tick_labels = match grid.share_x_mode() {
    @gridspec.ShareMode::All | @gridspec.ShareMode::Column =>
      row == grid.rows() - 1
    @gridspec.ShareMode::None | @gridspec.ShareMode::Row => true
  }
  self.state.val.show_y_tick_labels = match grid.share_y_mode() {
    @gridspec.ShareMode::All | @gridspec.ShareMode::Row => column == 0
    @gridspec.ShareMode::None | @gridspec.ShareMode::Column => true
  }
}

///|
/// Create axes panels arranged in row-major order.
///
/// The boolean sharing arguments preserve the original convenience API and
/// correspond to the `All` or `None` GridSpec modes. Use
/// `subplots_with_grid` for row- or column-level sharing.
pub fn Figure::subplots(
  self : Figure,
  rows : Int32,
  columns : Int32,
  hspace? : Double,
  vspace? : Double,
  share_x~ : Bool = false,
  share_y~ : Bool = false,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> Array[Axes] raise @gridspec.LayoutError {
  let grid = self.grid_spec(
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
/// Show or hide x tick labels on this panel without changing shared ticks.
pub fn Axes::set_x_tick_labels_visible(self : Axes, visible : Bool) -> Unit {
  self.state.val.show_x_tick_labels = visible
}

///|
/// Show or hide y tick labels on this panel without changing shared ticks.
pub fn Axes::set_y_tick_labels_visible(self : Axes, visible : Bool) -> Unit {
  self.state.val.show_y_tick_labels = visible
}

///|
/// Return whether this handle still belongs to its figure's axes list.
/// Replacing a figure's subplot grid detaches its previous handles.
/// Removing a panel also detaches all handles that refer to it.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let old = fig.axes()
///   assert_true(old.is_attached())
///   let panels = try! fig.subplots(1, 2)
///   assert_true(!old.is_attached())
///   assert_true(panels[0].is_attached())
/// }
/// ```
pub fn Axes::is_attached(self : Axes) -> Bool {
  for state in self.figure.axes {
    if physical_equal(state, self.state) {
      return true
    }
  }
  false
}

///|
fn Axes::x_group_states(self : Axes) -> Array[@ref.Ref[AxesData]] {
  match self.state.val.share_x_members {
    Some(group) => group.members.copy()
    None => [self.state]
  }
}

///|
fn Axes::y_group_states(self : Axes) -> Array[@ref.Ref[AxesData]] {
  match self.state.val.share_y_members {
    Some(group) => group.members.copy()
    None => [self.state]
  }
}
