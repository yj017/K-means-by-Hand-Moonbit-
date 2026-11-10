///|
/// Orientation of a colorbar in a rendered figure.
pub(all) enum Orientation {
  Vertical
  Horizontal
}

///|
/// A scalar color scale attached to a figure.
pub struct Colorbar {
  norm : @colors.ColorNorm
  cmap : @colors.ColorMap
  orientation : Orientation
  mut label : String?
  mut tick_count : Int32
}

///|
/// Construct a colorbar with deterministic default ticks.
pub fn colorbar(
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  orientation~ : Orientation = Orientation::Vertical,
) -> Colorbar {
  { norm, cmap, orientation, label: None, tick_count: 5, }
}

///|
/// Return the normalization used by this colorbar.
pub fn Colorbar::norm(self : Colorbar) -> @colors.ColorNorm {
  self.norm
}

///|
/// Return the colormap used by this colorbar.
pub fn Colorbar::cmap(self : Colorbar) -> @colors.ColorMap {
  self.cmap
}

///|
/// Return the colorbar orientation.
pub fn Colorbar::orientation(self : Colorbar) -> Orientation {
  self.orientation
}

///|
/// Set the colorbar label.
pub fn Colorbar::set_label(self : Colorbar, value : String) -> Unit {
  self.label = Some(value)
}

///|
/// Return the optional colorbar label.
pub fn Colorbar::label(self : Colorbar) -> String? {
  self.label
}

///|
/// Set the desired number of colorbar ticks.
pub fn Colorbar::set_tick_count(self : Colorbar, value : Int32) -> Unit {
  self.tick_count = if value < 2 { 2 } else { value }
}

///|
/// Return the desired number of colorbar ticks.
pub fn Colorbar::tick_count(self : Colorbar) -> Int32 {
  self.tick_count
}
