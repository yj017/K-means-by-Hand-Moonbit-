// Exact named-color lookup; String grammar and lazy conversion stay in scene.

///|
fn line_color_named(value : String) -> @colors.Rgba? {
  @color_names.lookup(value)
}
