///|
/// One immutable band lineage and geometry snapshot, with pinned outer/inner
/// identities. No original field grid or per-edge metadata copy is retained.
pub struct ContourFHitData {
  priv original : Array[Array[@core.Point]]
  priv rings : Array[Array[@core.Point]]
  priv expected : Array[Array[@core.Point]]
  priv slot : Int32
  priv lower : Double
  priv upper : Double
  priv value : Double
  priv series : String
  priv enabled : Bool
}

///|
pub fn contourf_hit_data(
  rings : Array[Array[@core.Point]],
  slot : Int32,
  lower : Double,
  upper : Double,
  series : String,
) -> ContourFHitData {
  let sum = lower + upper
  let value = if sum.is_inf() { lower / 2.0 + upper / 2.0 } else { sum / 2.0 }
  {
    original: rings,
    rings: rings.copy(),
    expected: rings.map(ring => ring.copy()),
    slot,
    lower,
    upper,
    value,
    series,
    enabled: true,
  }
}

///|
pub fn ContourFHitData::invalidated(self : ContourFHitData) -> ContourFHitData {
  { ..self, enabled: false, }
}

///|
pub fn ContourFHitData::enabled(self : ContourFHitData) -> Bool {
  self.enabled
}

///|
pub fn ContourFHitData::slot(self : ContourFHitData) -> Int32 {
  self.slot
}

///|
pub fn ContourFHitData::interval(self : ContourFHitData) -> (Double, Double) {
  (self.lower, self.upper)
}

///|
pub fn ContourFHitData::value(self : ContourFHitData) -> Double {
  self.value
}

///|
pub fn ContourFHitData::series(self : ContourFHitData) -> String {
  self.series
}

///|
fn ContourFHitData::matches_ring(
  self : ContourFHitData,
  index : Int32,
  points : Array[@core.Point],
) -> Bool {
  if !self.enabled ||
    index >= self.rings.length() ||
    !physical_equal(self.rings[index], points) ||
    points.length() != self.expected[index].length() {
    return false
  }
  for i, point in points {
    if !stem_point_equal(point, self.expected[index][i]) {
      return false
    }
  }
  true
}

///|
pub fn ContourFHitData::matches_polygon(
  self : ContourFHitData,
  points : Array[@core.Point],
) -> Bool {
  self.rings.length() == 1 && self.matches_ring(0, points)
}

///|
pub fn ContourFHitData::matches_rings(
  self : ContourFHitData,
  rings : Array[Array[@core.Point]],
) -> Bool {
  if !self.enabled ||
    !physical_equal(self.original, rings) ||
    rings.length() != self.rings.length() {
    return false
  }
  for i, ring in rings {
    if !self.matches_ring(i, ring) {
      return false
    }
  }
  true
}
