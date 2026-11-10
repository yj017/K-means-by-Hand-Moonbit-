///|
/// An ordered pair of axis limits. The direction is preserved, so reversed
/// limits represent an inverted axis.
pub struct Limits {
  lower : Double
  upper : Double
}

///|
/// Construct axis limits without reordering or padding them.
pub fn limits(lower : Double, upper : Double) -> Limits {
  { lower, upper, }
}

///|
/// Return the first limit exactly as supplied.
pub fn Limits::lower(self : Limits) -> Double {
  self.lower
}

///|
/// Return the second limit exactly as supplied.
pub fn Limits::upper(self : Limits) -> Double {
  self.upper
}

///|
/// Whether both limits are finite numbers.
pub fn Limits::is_finite(self : Limits) -> Bool {
  !self.lower.is_nan() &&
  !self.lower.is_inf() &&
  !self.upper.is_nan() &&
  !self.upper.is_inf()
}
