///|
/// One bar's explicit category-axis position, width, value and starting baseline.
/// The value is the original segment magnitude; its endpoint is baseline + value.
/// Invalid or nonfinite geometry is skipped when rendering, like missing Points.
pub struct BarSegment {
  position : Double
  value : Double
  baseline : Double
  width : Double
  category : String?
}

///|
/// Construct a bar segment without conflating its original value and endpoint.
pub fn bar_segment(
  position : Double,
  value : Double,
  baseline~ : Double = 0.0,
  width~ : Double = 0.8,
  category~ : String? = None,
) -> BarSegment {
  { position, value, baseline, width, category, }
}
