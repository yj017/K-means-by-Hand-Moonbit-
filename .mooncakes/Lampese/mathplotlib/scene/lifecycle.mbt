///|
/// Return the most recently selected surviving axes.
/// An empty Figure receives a new 1-by-1 subplot using its current bounds.
/// axes() remains the separate first/default-panel convenience API.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let panels = try! fig.subplots(1, 2)
///   panels[1].set_title("last")
///   assert_eq(fig.gca().title(), Some("last"))
///   try! panels[1].remove()
///   panels[0].set_title("remaining")
///   assert_eq(fig.gca().title(), Some("remaining"))
/// }
/// ```
pub fn Figure::gca(self : Figure) -> Axes {
  match self.axes_selection.last() {
    Some(state) => { figure: self, state, }
    None => self.axes()
  }
}

///|
/// Select axes in this Figure, returning the selected handle.
/// Foreign or detached handles raise InvalidReference without changing state.
/// Selection does not change creation or SVG drawing order.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let panels = try! fig.subplots(1, 2)
///   panels[0].set_title("first")
///   ignore(try! fig.sca(panels[0]))
///   assert_eq(fig.gca().title(), Some("first"))
///   assert_eq(fig.axes_list().length(), 2)
/// }
/// ```
pub fn Figure::sca(self : Figure, axes : Axes) -> Axes raise @core.DataError {
  if !physical_equal(self, axes.figure) || !axes.is_attached() {
    raise @core.DataError::InvalidReference(
      message="cannot select detached or foreign axes",
    )
  }
  self.axes_selection.retain(state => !physical_equal(state, axes.state))
  self.axes_selection.push(axes.state)
  axes
}

///|
fn SubFigureData::forget_axes(
  self : SubFigureData,
  state : @ref.Ref[AxesData],
) -> Unit {
  self.axes.retain(item => !physical_equal(item, state))
  for child in self.subfigures {
    child.val.forget_axes(state)
  }
}

///|
/// Remove axes from this Figure, preserving the order of remaining panels.
/// This also removes membership in nested SubFigures. The current selection
/// falls back to the most recently selected surviving panel. Removing the
/// last panel leaves the Figure empty until axes() or gca() is requested.
/// Foreign or detached handles raise InvalidReference before any state changes.
/// Figure-level colorbars are independent and remain registered.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let ax = fig.axes()
///   try! fig.delaxes(ax)
///   assert_eq(fig.axes_list().length(), 0)
///   assert_true(!ax.is_attached())
///   assert_true(fig.gca().is_attached())
/// }
/// ```
pub fn Figure::delaxes(
  self : Figure,
  axes : Axes,
) -> Unit raise @core.DataError {
  if !physical_equal(self, axes.figure) || !axes.is_attached() {
    raise @core.DataError::InvalidReference(
      message="cannot remove axes outside this figure",
    )
  }
  self.axes.retain(state => !physical_equal(state, axes.state))
  self.axes_selection.retain(state => !physical_equal(state, axes.state))
  for data in self.subfigures {
    data.val.forget_axes(axes.state)
  }
  for horizontal in [true, false] {
    let remaining_states = axes.unregister_shared_axis(horizontal)
    if remaining_states.length() > 0 {
      let state = remaining_states[0]
      let axis = if horizontal { state.val.x_axis } else { state.val.y_axis }
      axis.bind_locator_data()
      axis.bind_locator_data(minor=true)
      axis.bind_formatter_axis()
      axis.bind_formatter_axis(minor=true)
    }
  }
}

///|
/// Remove this panel from its Figure and any containing SubFigure.
/// Other handles to this panel become detached; its artists remain inspectable.
/// Repeated removal raises InvalidReference. figure() retains the source Figure
/// as provenance, and does not imply continued attachment.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let ax = try! fig.add_axes(0.25, 0.25, 0.5, 0.5)
///   ax.set_title("removed")
///   try! ax.remove()
///   assert_true(!fig.to_svg().contains(">removed<"))
///   assert_eq(ax.title(), Some("removed"))
/// }
/// ```
pub fn Axes::remove(self : Axes) -> Unit raise @core.DataError {
  self.figure.delaxes(self)
}

///|
/// Remove axes created directly through this SubFigure.
/// Axes in another region or a child SubFigure raise InvalidReference.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   let grid = try! fig.grid_spec(1, 1)
///   let sub = fig.add_subfigure(try! grid.cell_spec(0, 0))
///   let ax = try! sub.subplots(1, 1)[0]
///   try! sub.delaxes(ax)
///   assert_eq(sub.axes_list().length(), 0)
///   assert_eq(fig.axes_list().length(), 0)
/// }
/// ```
pub fn SubFigure::delaxes(
  self : SubFigure,
  axes : Axes,
) -> Unit raise @core.DataError {
  if !self.data.val.axes.any(state => physical_equal(state, axes.state)) {
    raise @core.DataError::InvalidReference(
      message="axes does not belong to this subfigure",
    )
  }
  self.figure.delaxes(axes)
  self.data.val.forget_axes(axes.state)
}
