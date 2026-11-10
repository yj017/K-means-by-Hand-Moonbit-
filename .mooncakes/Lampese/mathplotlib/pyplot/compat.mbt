///|
/// Common pyplot naming aliases used by Matplotlib examples.

///|
pub fn suptitle(value : String) -> Unit {
  require_figure().suptitle(value)
}

///|
pub fn savefig() -> String {
  render_svg()
}
