///|
/// The four standard borders around an axes panel.
pub(all) enum SpineSide {
  Left
  Right
  Bottom
  Top
}

///|
/// Positioning modes supported by an axes spine.
pub(all) enum SpinePosition {
  Axes
  Data(Double)
  Outward(Double)
}

///|
priv struct SpineState {
  mut visible : Bool
  mut color : String
  mut linewidth : Double
  mut position : SpinePosition
  mut bounds : (Double, Double)?
}

///|
fn default_spines() -> Array[SpineState] {
  [
    {
      visible: true,
      color: "#374151",
      linewidth: 1.2,
      position: SpinePosition::Axes,
      bounds: None,
    },
    {
      visible: true,
      color: "#374151",
      linewidth: 1.2,
      position: SpinePosition::Axes,
      bounds: None,
    },
    {
      visible: true,
      color: "#374151",
      linewidth: 1.2,
      position: SpinePosition::Axes,
      bounds: None,
    },
    {
      visible: true,
      color: "#374151",
      linewidth: 1.2,
      position: SpinePosition::Axes,
      bounds: None,
    },
  ]
}

///|
fn spine_index(side : SpineSide) -> Int32 {
  match side {
    SpineSide::Left => 0
    SpineSide::Right => 1
    SpineSide::Bottom => 2
    SpineSide::Top => 3
  }
}

///|
/// A handle to one of an axes panel's four spines.
pub struct Spine {
  axes : Axes
  side : SpineSide
}

///|
/// Return the side represented by this spine handle.
pub fn Spine::side(self : Spine) -> SpineSide {
  self.side
}

///|
fn Spine::state(self : Spine) -> SpineState {
  self.axes.state.val.spines[spine_index(self.side)]
}

///|
/// Return whether this spine is rendered.
pub fn Spine::visible(self : Spine) -> Bool {
  self.state().visible
}

///|
/// Set whether this spine is rendered.
pub fn Spine::set_visible(self : Spine, visible : Bool) -> Unit {
  self.state().visible = visible
}

///|
/// Return the spine stroke color.
pub fn Spine::color(self : Spine) -> String {
  self.state().color
}

///|
/// Set the spine stroke color.
pub fn Spine::set_color(
  self : Spine,
  color : String,
) -> Unit raise @core.DataError {
  if color.length() == 0 {
    raise @core.DataError::InvalidTicks(message="spine color must not be empty")
  }
  self.state().color = color
}

///|
/// Return the spine stroke width.
pub fn Spine::linewidth(self : Spine) -> Double {
  self.state().linewidth
}

///|
/// Return this spine's positioning mode.
pub fn Spine::position(self : Spine) -> SpinePosition {
  self.state().position
}

///|
/// Set this spine's positioning mode.
pub fn Spine::set_position(
  self : Spine,
  position : SpinePosition,
) -> Unit raise @core.DataError {
  match position {
    SpinePosition::Axes => ()
    SpinePosition::Data(value) | SpinePosition::Outward(value) =>
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidTicks(
          message="spine position must be finite",
        )
      }
  }
  self.state().position = position
}

///|
/// Return optional data-coordinate bounds for this spine.
pub fn Spine::bounds(self : Spine) -> (Double, Double)? {
  self.state().bounds
}

///|
/// Restrict a spine to a finite data-coordinate interval.
pub fn Spine::set_bounds(
  self : Spine,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    raise @core.DataError::InvalidTicks(message="spine bounds must be finite")
  }
  if lower == upper {
    raise @core.DataError::InvalidTicks(
      message="spine bounds must span a non-zero interval",
    )
  }
  self.state().bounds = Some((lower, upper))
}

///|
/// Remove an explicit spine interval.
pub fn Spine::clear_bounds(self : Spine) -> Unit {
  self.state().bounds = None
}

///|
/// Set the spine stroke width.
pub fn Spine::set_linewidth(
  self : Spine,
  linewidth : Double,
) -> Unit raise @core.DataError {
  if linewidth.is_nan() || linewidth.is_inf() || linewidth <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="spine linewidth must be finite and positive",
    )
  }
  self.state().linewidth = linewidth
}

///|
/// Return a handle to the selected spine.
pub fn Axes::spine(self : Axes, side : SpineSide) -> Spine {
  { axes: self, side, }
}

///|
/// Return the four spines in left, right, bottom, top order.
pub fn Axes::spines(self : Axes) -> Array[Spine] {
  [
    self.spine(SpineSide::Left),
    self.spine(SpineSide::Right),
    self.spine(SpineSide::Bottom),
    self.spine(SpineSide::Top),
  ]
}

///|
/// Return a selected spine on the default axes panel.
pub fn Figure::spine(self : Figure, side : SpineSide) -> Spine {
  self.axes().spine(side)
}

///|
/// Return the default axes panel's four spines.
pub fn Figure::spines(self : Figure) -> Array[Spine] {
  self.axes().spines()
}
