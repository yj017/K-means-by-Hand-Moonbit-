///|
fn validate_data_aspect(value : Double) -> Unit raise @core.DataError {
  if value <= 0.0 || value.is_nan() || value.is_inf() {
    raise @core.DataError::InvalidReference(
      message="aspect must be finite and positive",
    )
  }
}

///|
fn Axes::apply_data_aspect(self : Axes, value : Double?, share : Bool) -> Unit {
  self.state.val.data_aspect = value
  if share {
    for state in self.x_group_states() {
      state.val.data_aspect = value
    }
    for state in self.y_group_states() {
      state.val.data_aspect = value
    }
  }
}

///|
/// Set the display size of one y data unit relative to one x data unit.
/// Values must be finite and positive; invalid input raises InvalidReference
/// without changing this panel or its shared siblings. With box adjustment,
/// the allocated box shrinks using the anchor, preserving data limits.
/// Datalim adjustment keeps the box and changes x or y view limits instead.
/// share=true updates the union of the panel's direct x/y shared siblings.
/// Use set_aspect_auto() for automatic aspect, or set_aspect_equal() for 1.
/// An optional anchor is validated and applied along with the ratio.
/// adjustable accepts "box" or "datalim"; omitted settings inherit this panel's
/// strategy and are propagated with share. The default anchor is the center.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure(width=400, height=200)
///   let ax = try! fig.add_axes(0.25, 0.25, 0.5, 0.5)
///   try! ax.set_xlim(0.0, 1.0)
///   try! ax.set_ylim(0.0, 1.0)
///   try! ax.set_aspect(2.0)
///   assert_eq(ax.get_aspect(), Some(2.0))
///   assert_eq(ax.get_position().unwrap().width(), 0.125)
///   assert_eq(ax.get_position(original=true).unwrap().width(), 0.5)
/// }
/// ```
pub fn Axes::set_aspect(
  self : Axes,
  value : Double,
  share~ : Bool = false,
  anchor? : Anchor,
  adjustable? : String,
) -> Unit raise @core.DataError {
  validate_data_aspect(value)
  if anchor is Some(anchor) {
    ignore(anchor.coordinates())
  }
  let mode = adjustable.unwrap_or(self.state.val.adjustable)
  self.validate_adjustable(mode, share, fixed_aspect=true)
  self.apply_data_aspect(Some(value), share)
  self.apply_adjustable(mode, share)
  if anchor is Some(anchor) {
    self.apply_anchor(anchor, share)
  }
}

///|
/// Return the numeric y/x display scale ratio, or None for automatic aspect.
/// Matplotlib's "auto" maps to None and "equal" to Some(1.0).
///
/// ```mbt check
/// test {
///   let ax = @scene.figure().axes()
///   assert_true(ax.get_aspect() is None)
///   ax.set_aspect_equal()
///   assert_eq(ax.get_aspect(), Some(1.0))
///   ax.set_aspect_auto()
///   assert_true(ax.get_aspect() is None)
/// }
/// ```
pub fn Axes::get_aspect(self : Axes) -> Double? {
  self.state.val.data_aspect
}

///|
/// Set numeric aspect on the first/default panel, preserving gca selection.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   try! fig.set_aspect(0.5)
///   assert_eq(fig.axes().get_aspect(), Some(0.5))
/// }
/// ```
pub fn Figure::set_aspect(
  self : Figure,
  value : Double,
  share~ : Bool = false,
  anchor? : Anchor,
  adjustable? : String,
) -> Unit raise @core.DataError {
  validate_data_aspect(value)
  if anchor is Some(anchor) {
    ignore(anchor.coordinates())
  }
  if adjustable is Some(mode) {
    validate_adjustable_name(mode)
  }
  self.axes().set_aspect(value, share~, anchor?, adjustable?)
}

///|
/// Return the first/default panel's numeric aspect, or None for auto.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   fig.set_aspect_equal()
///   assert_eq(fig.get_aspect(), Some(1.0))
/// }
/// ```
pub fn Figure::get_aspect(self : Figure) -> Double? {
  self.axes().get_aspect()
}
