///|
/// Whether Line setters scale captured dash lengths by their current width.
pub fn lines_scale_dashes() -> Bool {
  current.val.lines_scale_dashes
}

///|
/// This takes effect on the next linestyle or linewidth setter, including equal width.
pub fn set_lines_scale_dashes(value : Bool) -> Unit {
  current.val.lines_scale_dashes = value
}

///|
pub fn RcParams::lines_scale_dashes(self : RcParams) -> Bool {
  self.lines_scale_dashes
}

///|
/// Return a copy of the template captured by the next dashed linestyle setter.
pub fn lines_dashed_pattern() -> Array[Double] {
  current.val.lines_dashed_pattern.copy()
}

///|
/// Copy the template without imposing the later graphics-context validation.
pub fn set_lines_dashed_pattern(value : Array[Double]) -> Unit {
  current.val.lines_dashed_pattern = value.copy()
}

///|
pub fn RcParams::lines_dashed_pattern(self : RcParams) -> Array[Double] {
  self.lines_dashed_pattern.copy()
}

///|
/// Return a copy of the template captured by the next dash-dot linestyle setter.
pub fn lines_dashdot_pattern() -> Array[Double] {
  current.val.lines_dashdot_pattern.copy()
}

///|
pub fn set_lines_dashdot_pattern(value : Array[Double]) -> Unit {
  current.val.lines_dashdot_pattern = value.copy()
}

///|
pub fn RcParams::lines_dashdot_pattern(self : RcParams) -> Array[Double] {
  self.lines_dashdot_pattern.copy()
}

///|
/// Return a copy of the template captured by the next dotted linestyle setter.
pub fn lines_dotted_pattern() -> Array[Double] {
  current.val.lines_dotted_pattern.copy()
}

///|
pub fn set_lines_dotted_pattern(value : Array[Double]) -> Unit {
  current.val.lines_dotted_pattern = value.copy()
}

///|
pub fn RcParams::lines_dotted_pattern(self : RcParams) -> Array[Double] {
  self.lines_dotted_pattern.copy()
}
