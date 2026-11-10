///|
/// Immutable effective Line stroke appearance. Dash arrays are copied at both
/// construction and inspection, so an old Style remains a stable snapshot.
pub struct LineStroke {
  priv canonical : String
  priv offset : Double
  priv dashes : Array[Double]?
}

///|
/// Construct an effective stroke from an already canonical linestyle.
/// This low-level appearance carrier does not reconstruct Line setter history.
pub fn line_stroke(
  canonical : String,
  offset~ : Double = 0.0,
  dashes~ : Array[Double]? = None,
) -> LineStroke {
  { canonical, offset, dashes: dashes.map(values => values.copy()), }
}

///|
pub fn LineStroke::linestyle(self : LineStroke) -> String {
  self.canonical
}

///|
pub fn LineStroke::dash_offset(self : LineStroke) -> Double {
  self.offset
}

///|
pub fn LineStroke::dash_sequence(self : LineStroke) -> Array[Double]? {
  self.dashes.map(values => values.copy())
}

///|
fn default_line_stroke() -> LineStroke {
  line_stroke("-")
}
