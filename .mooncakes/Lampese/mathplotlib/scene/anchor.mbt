///|
/// An axes anchor, measured within the space left by aspect shrinking.
/// Named accepts C, SW, S, SE, E, NE, N, NW, or W. Fraction stores a pair
/// relative to the original box: x=0 is left, y=0 is bottom. Finite values
/// outside [0, 1] place the active box outside the allocated rectangle.
pub(all) enum Anchor {
  Named(String)
  Fraction(Double, Double)
}

///|
fn Anchor::coordinates(self : Anchor) -> (Double, Double) raise @core.DataError {
  match self {
    Named(name) =>
      match name {
        "C" => (0.5, 0.5)
        "SW" => (0.0, 0.0)
        "S" => (0.5, 0.0)
        "SE" => (1.0, 0.0)
        "E" => (1.0, 0.5)
        "NE" => (1.0, 1.0)
        "N" => (0.5, 1.0)
        "NW" => (0.0, 1.0)
        "W" => (0.0, 0.5)
        _ =>
          raise @core.DataError::InvalidReference(
            message="anchor must be C, SW, S, SE, E, NE, N, NW, W, or finite fractions",
          )
      }
    Fraction(x, y) => {
      if x.is_nan() || x.is_inf() || y.is_nan() || y.is_inf() {
        raise @core.DataError::InvalidReference(
          message="anchor fractions must be finite",
        )
      }
      (x, y)
    }
  }
}

///|
fn Axes::apply_anchor(self : Axes, anchor : Anchor, share : Bool) -> Unit {
  self.state.val.anchor = anchor
  if share {
    for state in self.x_group_states() {
      state.val.anchor = anchor
    }
    for state in self.y_group_states() {
      state.val.anchor = anchor
    }
  }
}

///|
/// Place the aspect-constrained active box within its allocated rectangle.
/// The default is Named("C"). Named compass directions and finite Fraction
/// coordinates are accepted. Invalid anchors raise InvalidReference before
/// updating any panel. share=true updates direct x/y shared siblings.
/// With automatic aspect there is no free space, so the position is unchanged.
/// Clearing artists preserves the anchor, and new axes start at the center.
///
/// ```mbt check
/// test {
///   let ax = try! @scene.figure(width=400, height=200).add_axes(
///     0.25, 0.25, 0.5, 0.5,
///   )
///   try! ax.set_xlim(0.0, 1.0)
///   try! ax.set_ylim(0.0, 1.0)
///   ax.set_aspect_equal()
///   try! ax.set_anchor(@scene.Anchor::Named("SW"))
///   assert_eq(ax.get_position().unwrap().x(), 0.25)
///   try! ax.set_anchor(@scene.Anchor::Fraction(1.0, 0.5))
///   assert_eq(ax.get_position().unwrap().x(), 0.5)
/// }
/// ```
pub fn Axes::set_anchor(
  self : Axes,
  anchor : Anchor,
  share~ : Bool = false,
) -> Unit raise @core.DataError {
  ignore(anchor.coordinates())
  self.apply_anchor(anchor, share)
}

///|
/// Return the anchor in the same Named or Fraction form supplied by the caller.
///
/// ```mbt check
/// test {
///   let ax = @scene.figure().axes()
///   assert_true(ax.get_anchor() is @scene.Anchor::Named("C"))
///   try! ax.set_anchor(@scene.Anchor::Fraction(0.25, 0.75))
///   assert_true(ax.get_anchor() is @scene.Anchor::Fraction(0.25, 0.75))
/// }
/// ```
pub fn Axes::get_anchor(self : Axes) -> Anchor {
  self.state.val.anchor
}

///|
/// Set the first/default panel's anchor while preserving the current selection.
/// Invalid anchors are rejected before creating a panel in an empty Figure.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   try! fig.set_anchor(@scene.Anchor::Named("NE"))
///   assert_true(fig.axes().get_anchor() is @scene.Anchor::Named("NE"))
/// }
/// ```
pub fn Figure::set_anchor(
  self : Figure,
  anchor : Anchor,
  share~ : Bool = false,
) -> Unit raise @core.DataError {
  ignore(anchor.coordinates())
  self.axes().set_anchor(anchor, share~)
}

///|
/// Return the first/default panel's anchor, creating a panel if necessary.
///
/// ```mbt check
/// test {
///   assert_true(@scene.figure().get_anchor() is @scene.Anchor::Named("C"))
/// }
/// ```
pub fn Figure::get_anchor(self : Figure) -> Anchor {
  self.axes().get_anchor()
}
