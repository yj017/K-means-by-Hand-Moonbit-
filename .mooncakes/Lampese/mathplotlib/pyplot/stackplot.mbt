///|
/// Draw a stacked area plot on the current axes.
pub fn stackplot(
  xs : Array[Double],
  ys : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  baseline~ : String = "zero",
) -> Array[@scene.Artist] raise @core.DataError {
  require_axes().stackplot(xs, ys, labels~, colors~, baseline~)
}
