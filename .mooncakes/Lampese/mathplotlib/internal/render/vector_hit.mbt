///|
/// Immutable scalar data for a single original vector.
pub struct VectorDatum {
  index : Int32
  point : @core.Point
  vector : @drawing.VectorInfo
}

///|
/// One copied source table per Quiver call, never per arrow part.
pub struct VectorHitData {
  priv points : Array[@core.Point]
  priv vectors : Array[@core.Point]
}

///|
pub fn vector_hit_data(
  points : Array[@core.Point],
  vectors : Array[@core.Point],
) -> VectorHitData? {
  if points.length() != vectors.length() {
    return None
  }
  Some({ points: points.copy(), vectors: vectors.copy(), })
}

///|
pub fn VectorHitData::datum(
  self : VectorHitData,
  index : Int32,
) -> VectorDatum? {
  guard self.points.get(index) is Some(point) else { return None }
  let vector = self.vectors[index]
  Some({ index, point, vector: @drawing.vector_info(vector.x(), vector.y()), })
}

///|
/// Called once for the complete current artist before its actual paint.
pub fn VectorHitData::matches(
  self : VectorHitData,
  points : Array[@core.Point],
  vectors : Array[@core.Point],
) -> Bool {
  if points.length() != self.points.length() ||
    vectors.length() != self.vectors.length() {
    return false
  }
  for i, p in points {
    let expected = self.points[i]
    let vector = vectors[i]
    let expected_vector = self.vectors[i]
    if !discrete_number_equal(p.x(), expected.x()) ||
      !discrete_number_equal(p.y(), expected.y()) ||
      !discrete_number_equal(vector.x(), expected_vector.x()) ||
      !discrete_number_equal(vector.y(), expected_vector.y()) {
      return false
    }
  }
  true
}
