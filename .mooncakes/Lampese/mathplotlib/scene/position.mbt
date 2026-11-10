///|
fn Axes::original_position_rect(self : Axes) -> @gridspec.Rect {
  self
  .rect()
  .unwrap_or_else(() => {
    @gridspec.rect(
      Double::from_int(self.figure.margin),
      Double::from_int(self.figure.margin),
      Double::from_int(self.figure.width - self.figure.margin * 2),
      Double::from_int(self.figure.height - self.figure.margin * 2),
    )
  })
}

///|
/// Return a normalized Figure rectangle with a lower-left origin.
///
/// The returned Rect stores (left, bottom, width, height), unlike rect(),
/// which returns the allocated display rectangle in pixels from the top left.
/// original=true returns the allocated position. The default active position
/// applies the same data/physical-aspect geometry as SVG rendering.
/// Autoscale margins, shared limits, and image bounds are resolved by the
/// existing renderer. Detached axes or nonpositive Figure dimensions return
/// None. SubFigure axes currently use coordinates of the root Figure.
/// Aspect-resolution failures return None; apply_aspect preserves DataError.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure(width=400, height=200)
///   let ax = try! fig.add_axes(0.25, 0.25, 0.5, 0.5)
///   try! ax.set_xlim(0.0, 1.0)
///   try! ax.set_ylim(0.0, 1.0)
///   ax.set_aspect_equal()
///   assert_eq(ax.get_position(original=true).unwrap().width(), 0.5)
///   assert_eq(ax.get_position().unwrap().width(), 0.25)
/// }
/// ```
pub fn Axes::get_position(
  self : Axes,
  original~ : Bool = false,
) -> @gridspec.Rect? {
  if !self.is_attached() || self.figure.width <= 0 || self.figure.height <= 0 {
    return None
  }
  let rect = if original {
    self.original_position_rect()
  } else {
    self.apply_aspect() catch {
      _ => return None
    }
    self.state.val.active_position.unwrap()
  }
  let figure_width = Double::from_int(self.figure.width)
  let figure_height = Double::from_int(self.figure.height)
  Some(
    @gridspec.rect(
      rect.x() / figure_width,
      1.0 - (rect.y() + rect.height()) / figure_height,
      rect.width() / figure_width,
      rect.height() / figure_height,
    ),
  )
}

///|
/// Set a normalized Figure rectangle (left, bottom, width, height).
///
/// which accepts both, original, or active. GridSpec membership is retained;
/// subplots_adjust restores grid placement. Manual panels keep their new
/// position through subplots_adjust. Zero sizes and positions outside the
/// Figure are allowed. Invalid values leave the state unchanged.
/// Negative sizes, non-finite coordinates, coordinate overflow, invalid which
/// values, and detached handles raise DataError::InvalidReference.
/// As in Matplotlib, an active-only value is overwritten by original and
/// aspect on the next active-position read or draw.
///
/// ```mbt check
/// test {
///   let ax = @scene.figure(width=400, height=200).axes()
///   try! ax.set_position(0.25, 0.25, 0.5, 0.5)
///   let p = ax.get_position(original=true).unwrap()
///   assert_eq((p.x(), p.y(), p.width(), p.height()), (0.25, 0.25, 0.5, 0.5))
/// }
/// ```
pub fn Axes::set_position(
  self : Axes,
  left : Double,
  bottom : Double,
  width : Double,
  height : Double,
  which~ : String = "both",
) -> Unit raise @core.DataError {
  if !self.is_attached() {
    raise @core.DataError::InvalidReference(
      message="axes is detached from its figure",
    )
  }
  if which != "both" && which != "original" && which != "active" {
    raise @core.DataError::InvalidReference(
      message="position which must be both, original, or active",
    )
  }
  let rect = self.figure.position_rect(left, bottom, width, height) catch {
    _ =>
      raise @core.DataError::InvalidReference(message="invalid axes position")
  }
  if which == "both" || which == "original" {
    self.state.val.position_override = Some(rect)
  }
  if which == "both" || which == "active" {
    self.state.val.active_position = Some(rect)
  }
}

///|
/// Reset active to original, preserving the allocated position.
/// The next active-position read or draw reapplies the aspect constraint.
/// Detached handles raise DataError::InvalidReference.
///
/// ```mbt check
/// test {
///   let ax = try! @scene.figure().add_axes(0.25, 0.25, 0.5, 0.5)
///   try! ax.set_position(0.0, 0.0, 0.25, 0.25, which="active")
///   try! ax.reset_position()
///   assert_eq(ax.get_position().unwrap().x(), 0.25)
/// }
/// ```
pub fn Axes::reset_position(self : Axes) -> Unit raise @core.DataError {
  if !self.is_attached() {
    raise @core.DataError::InvalidReference(
      message="axes is detached from its figure",
    )
  }
  self.state.val.active_position = Some(self.original_position_rect())
}
