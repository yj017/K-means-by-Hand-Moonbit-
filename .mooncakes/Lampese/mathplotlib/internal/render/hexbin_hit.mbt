///|
/// Immutable source information for one emitted hexagonal face. No reducer
/// callback or mutable samples survive into a prepared frame.
pub struct HexbinHitData {
  index : Int32
  center : @core.Point
  value : Double
  info : @drawing.HexbinInfo
}

///|
pub fn hexbin_hit_data(
  index : Int32,
  center : @core.Point,
  value : Double,
  info : @drawing.HexbinInfo,
) -> HexbinHitData {
  { index, center, value, info, }
}
