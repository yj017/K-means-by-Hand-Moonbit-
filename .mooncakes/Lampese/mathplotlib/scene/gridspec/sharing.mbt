///|
/// How a regular subplot grid links coordinate axes.
pub(all) enum ShareMode {
  None
  All
  Row
  Column
}

///|
/// Return the sharing mode for x coordinates in this grid.
pub fn GridSpec::share_x_mode(self : GridSpec) -> ShareMode {
  self.share_x
}

///|
/// Return the sharing mode for y coordinates in this grid.
pub fn GridSpec::share_y_mode(self : GridSpec) -> ShareMode {
  self.share_y
}

///|
/// Return a copy of this grid with explicit x and y sharing constraints.
pub fn GridSpec::with_shared_axes(
  self : GridSpec,
  share_x : ShareMode,
  share_y : ShareMode,
) -> GridSpec {
  { ..self, share_x, share_y, }
}
