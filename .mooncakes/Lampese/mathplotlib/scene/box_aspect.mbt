///|
/// Set the panel's physical height/width ratio, independently of data units.
/// Supply aspect=... with a positive finite value, or omit it to clear the box
/// constraint. Setting a value selects datalim adjustment; clearing it retains
/// the current strategy. This does not propagate to ordinary shared siblings.
/// clear retains the box ratio and new axes default to no constraint.
///
/// ```mbt check
/// test {
///   let ax = try! @scene.figure(width=400, height=200).add_axes(
///     0.0, 0.0, 1.0, 1.0,
///   )
///   try! ax.set_box_aspect(aspect=1.0)
///   assert_eq(ax.get_position().unwrap().width(), 0.5)
///   assert_eq(ax.get_adjustable(), "datalim")
///   try! ax.set_box_aspect()
///   assert_eq(ax.get_position().unwrap().width(), 1.0)
/// }
/// ```
pub fn Axes::set_box_aspect(
  self : Axes,
  aspect? : Double,
) -> Unit raise @core.DataError {
  if aspect is Some(value) {
    validate_data_aspect(value)
    self.validate_adjustable("datalim", false)
    self.state.val.adjustable = "datalim"
  }
  self.state.val.box_aspect = aspect
}

///|
/// Return the physical box height/width constraint, or None if disabled.
///
/// ```mbt check
/// test {
///   let ax = @scene.figure().axes()
///   assert_true(ax.get_box_aspect() is None)
///   try! ax.set_box_aspect(aspect=2.0)
///   assert_eq(ax.get_box_aspect(), Some(2.0))
/// }
/// ```
pub fn Axes::get_box_aspect(self : Axes) -> Double? {
  self.state.val.box_aspect
}

///|
/// Set or clear the first/default panel's physical box constraint.
/// Invalid input is rejected before creating a panel in an empty Figure.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   try! fig.set_box_aspect(aspect=0.5)
///   assert_eq(fig.axes().get_box_aspect(), Some(0.5))
/// }
/// ```
pub fn Figure::set_box_aspect(
  self : Figure,
  aspect? : Double,
) -> Unit raise @core.DataError {
  if aspect is Some(value) {
    validate_data_aspect(value)
  }
  self.axes().set_box_aspect(aspect?)
}

///|
/// Return the first/default panel's box constraint, creating a panel if needed.
///
/// ```mbt check
/// test {
///   assert_true(@scene.figure().get_box_aspect() is None)
/// }
/// ```
pub fn Figure::get_box_aspect(self : Figure) -> Double? {
  self.axes().get_box_aspect()
}
