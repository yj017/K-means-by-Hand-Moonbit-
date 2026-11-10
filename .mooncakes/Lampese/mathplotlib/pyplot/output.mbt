///|
/// Return the current figure as SVG.
pub fn render_svg() -> String {
  require_figure().to_svg()
}

///|
/// Alias for render_svg while file backends are being added.
pub fn savefig_svg() -> String {
  render_svg()
}
