///|
/// Original symmetric error bounds in data coordinates. A disabled or zero
/// error direction has equal endpoints; ranges are independent of viewport,
/// axis inversion and the domain-valid error segments actually visible.
pub struct ErrorInfo {
  x_range : (Double, Double)
  y_range : (Double, Double)
} derive(Eq, Debug)

///|
pub extend ErrorInfo with Eq::{equal, not_equal}

///|
pub extend ErrorInfo with @debug.Debug::{to_repr}

///|
pub fn error_info(
  x_range : (Double, Double),
  y_range : (Double, Double),
) -> ErrorInfo {
  { x_range, y_range, }
}
