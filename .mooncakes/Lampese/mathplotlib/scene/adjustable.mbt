///|
fn validate_adjustable_name(mode : String) -> Unit raise @core.DataError {
  if mode != "box" && mode != "datalim" {
    raise @core.DataError::InvalidReference(
      message="adjustable must be box or datalim",
    )
  }
}

///|
fn Axes::adjustable_targets(self : Axes, share : Bool) -> Array[Axes] {
  if !share {
    return [self]
  }
  let result = self
    .x_group_states()
    .map(state => { figure: self.figure, state, })
  for state in self.y_group_states() {
    if !result.any(axes => physical_equal(axes.state, state)) {
      result.push({ figure: self.figure, state, })
    }
  }
  result
}

///|
fn Axes::validate_adjustable(
  self : Axes,
  mode : String,
  share : Bool,
  fixed_aspect~ : Bool = false,
) -> Unit raise @core.DataError {
  validate_adjustable_name(mode)
  if mode == "datalim" {
    for axes in self.adjustable_targets(share) {
      if (fixed_aspect || axes.state.val.data_aspect is Some(_)) &&
        axes.x_group_states().length() > 1 &&
        axes.y_group_states().length() > 1 {
        raise @core.DataError::InvalidReference(
          message="datalim aspect cannot adjust axes sharing both x and y",
        )
      }
    }
  }
}

///|
fn Axes::apply_adjustable(self : Axes, mode : String, share : Bool) -> Unit {
  for axes in self.adjustable_targets(share) {
    axes.state.val.adjustable = mode
  }
}

///|
/// Choose whether fixed aspect shrinks the box or changes data limits.
/// mode is "box" (default) or "datalim". share updates direct x/y shared
/// siblings. datalim may overwrite fixed limits while retaining their direction
/// and automatic/explicit selection. Numeric two-axis sharing is rejected here, before
/// any changes, rather than failing during a later non-throwing draw.
/// clear retains the setting; new axes start with box adjustment.
///
/// ```mbt check
/// test {
///   let ax = @scene.figure().axes()
///   try! ax.set_adjustable("datalim")
///   assert_eq(ax.get_adjustable(), "datalim")
///   ax.clear()
///   assert_eq(ax.get_adjustable(), "datalim")
/// }
/// ```
pub fn Axes::set_adjustable(
  self : Axes,
  mode : String,
  share~ : Bool = false,
) -> Unit raise @core.DataError {
  self.validate_adjustable(mode, share)
  self.apply_adjustable(mode, share)
}

///|
/// Return "box" or "datalim" for the aspect adjustment strategy.
///
/// ```mbt check
/// test {
///   assert_eq(@scene.figure().axes().get_adjustable(), "box")
/// }
/// ```
pub fn Axes::get_adjustable(self : Axes) -> String {
  self.state.val.adjustable
}

///|
/// Set the first/default panel's adjustment strategy, preserving gca selection.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   try! fig.set_adjustable("datalim")
///   assert_eq(fig.axes().get_adjustable(), "datalim")
/// }
/// ```
pub fn Figure::set_adjustable(
  self : Figure,
  mode : String,
  share~ : Bool = false,
) -> Unit raise @core.DataError {
  validate_adjustable_name(mode)
  self.axes().set_adjustable(mode, share~)
}

///|
/// Return the first/default panel's adjustment strategy.
///
/// ```mbt check
/// test {
///   assert_eq(@scene.figure().get_adjustable(), "box")
/// }
/// ```
pub fn Figure::get_adjustable(self : Figure) -> String {
  self.axes().get_adjustable()
}

///|
fn Axes::commit_aspect_view(
  self : Axes,
  view : ((Double, Double, Double, Double), @core.Limits, @core.Limits),
) -> Unit {
  if self.state.val.adjustable == "datalim" &&
    self.state.val.data_aspect is Some(_) {
    // panel_view validated the endpoints against these same axis scales.
    try! self.state.val.x_axis.set_view_limits(view.1.lower(), view.1.upper())
    try! self.state.val.y_axis.set_view_limits(view.2.lower(), view.2.upper())
  }
  let (left, top, width, height) = view.0
  self.state.val.active_position = Some(
    @gridspec.rect(left, top, width, height),
  )
}

///|
/// Apply aspect immediately, updating active position and datalim views.
/// Detached handles or unrepresentable transformed ranges raise DataError.
/// In datalim mode x_limits/y_limits expose the resolved view after this call.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure(width=400, height=200)
///   let ax = try! fig.add_axes(0.0, 0.0, 1.0, 1.0)
///   try! ax.plot([0.0, 1.0], [0.0, 1.0])
///   try! ax.set_xlim(0.0, 1.0)
///   try! ax.set_ylim(0.0, 1.0)
///   try! ax.set_aspect(1.0, adjustable="datalim")
///   try! ax.apply_aspect()
///   assert_eq(ax.get_xlim().unwrap().lower(), -0.5)
///   assert_eq(ax.get_position().unwrap().width(), 1.0)
/// }
/// ```
pub fn Axes::apply_aspect(self : Axes) -> Unit raise @core.DataError {
  if !self.is_attached() {
    raise @core.DataError::InvalidReference(
      message="cannot apply aspect to detached axes",
    )
  }
  if self.state.val.data_aspect is None && self.state.val.box_aspect is None {
    self.state.val.active_position = Some(self.original_position_rect())
    return
  }
  self.commit_aspect_view(self.resolve_aspect_view())
}

///|
fn Axes::resolve_aspect_view(
  self : Axes,
) -> ((Double, Double, Double, Double), @core.Limits, @core.Limits) raise @core.DataError {
  for index, state in self.figure.axes {
    if physical_equal(state, self.state) {
      return @svg.panel_view(self.figure.to_render_figure(), index).unwrap()
    }
  }
  raise @core.DataError::InvalidReference(
    message="cannot resolve aspect for detached axes",
  )
}

///|
fn Figure::apply_position_aspects(self : Figure) -> Unit raise @core.DataError {
  if !self.axes.any(state => {
      state.val.polar is None &&
      (
        state.val.box_aspect is Some(_) ||
        (state.val.adjustable == "datalim" && state.val.data_aspect is Some(_))
      )
    }) {
    return
  }
  let figure = self.to_render_figure()
  let views = []
  for index, state in self.axes {
    if state.val.polar is None &&
      (
        state.val.box_aspect is Some(_) ||
        (state.val.adjustable == "datalim" && state.val.data_aspect is Some(_))
      ) {
      let view = @svg.panel_view(figure, index).unwrap()
      views.push(({ figure: self, state, }, view))
    }
  }
  // Resolution precedes every write, including when a later panel fails.
  for (axes, view) in views {
    axes.commit_aspect_view(view)
  }
}
