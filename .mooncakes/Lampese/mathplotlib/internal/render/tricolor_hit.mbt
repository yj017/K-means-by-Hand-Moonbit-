///|
/// One constant-size face snapshot; no mesh or scalar array per face.
pub struct TripcolorHitData {
  priv original : Array[@core.Point]
  priv expected : Array[@core.Point]
  priv slot : Int32
  priv value : Double
  priv info : @drawing.TriColorInfo
  priv series : String
  priv enabled : Bool
}

///|
pub fn tripcolor_hit_data(
  points : Array[@core.Point],
  slot : Int32,
  value : Double,
  vertices : (Int32, Int32, Int32),
  vertex_mean : Bool,
  series : String,
) -> TripcolorHitData {
  {
    original: points,
    expected: points.copy(),
    slot,
    value,
    info: @drawing.tricolor_info(vertices, vertex_mean~),
    series,
    enabled: true,
  }
}

///|
pub fn TripcolorHitData::invalidated(
  self : TripcolorHitData,
) -> TripcolorHitData {
  { ..self, enabled: false, }
}

///|
pub fn TripcolorHitData::enabled(self : TripcolorHitData) -> Bool {
  self.enabled
}

///|
pub fn TripcolorHitData::slot(self : TripcolorHitData) -> Int32 {
  self.slot
}

///|
pub fn TripcolorHitData::value(self : TripcolorHitData) -> Double {
  self.value
}

///|
pub fn TripcolorHitData::info(self : TripcolorHitData) -> @drawing.TriColorInfo {
  self.info
}

///|
pub fn TripcolorHitData::series(self : TripcolorHitData) -> String {
  self.series
}

///|
// A binary scale avoids introducing division-rounding into a collinearity
// decision. Subnormal inputs use the smallest normal power of two.
fn tripcolor_binary_scale(magnitude : Double) -> Double {
  let exponent = magnitude.reinterpret_as_int64() & 0x7FF0000000000000L
  if exponent == 0L {
    0x0010000000000000L.reinterpret_as_double()
  } else {
    exponent.reinterpret_as_double()
  }
}

///|
// Normalize each axis separately: a valid face may have very different units
// on X and Y. Both overflow fallback and product scaling must retain that axis.
fn tripcolor_axis_spans(
  a : Double,
  b : Double,
  c : Double,
) -> (Double, Double)? {
  if a.is_nan() ||
    a.is_inf() ||
    b.is_nan() ||
    b.is_inf() ||
    c.is_nan() ||
    c.is_inf() {
    return None
  }
  let raw = (b - a, c - a)
  let (first, second) = if raw.0.is_inf() || raw.1.is_inf() {
    let scale = a.abs().max(b.abs()).max(c.abs())
    if scale == 0.0 || scale.is_nan() || scale.is_inf() {
      return None
    }
    let scale = tripcolor_binary_scale(scale)
    (b / scale - a / scale, c / scale - a / scale)
  } else {
    raw
  }
  let scale = first.abs().max(second.abs())
  if scale == 0.0 || scale.is_nan() || scale.is_inf() {
    return None
  }
  let scale = tripcolor_binary_scale(scale)
  Some((first / scale, second / scale))
}

///|
// Keep source collinearity independent of separately rounded screen transforms.
// No hit tolerance is used; ambiguous/nonfinite geometry stays static.
fn tripcolor_source_area(points : Array[@core.Point]) -> Bool {
  let a = points[0]
  let b = points[1]
  let c = points[2]
  guard tripcolor_axis_spans(a.x(), b.x(), c.x()) is Some((dx, qx)) else {
    return false
  }
  guard tripcolor_axis_spans(a.y(), b.y(), c.y()) is Some((dy, qy)) else {
    return false
  }
  let cross = dx * qy - dy * qx
  !cross.is_nan() && !cross.is_inf() && cross != 0.0
}

///|
/// Guard the actual original array once before its successful-write callback.
pub fn TripcolorHitData::matches_points(
  self : TripcolorHitData,
  points : Array[@core.Point],
) -> Bool {
  if !self.enabled ||
    points.length() != 3 ||
    self.expected.length() != 3 ||
    !physical_equal(self.original, points) {
    return false
  }
  for i, point in points {
    if !stem_point_equal(point, self.expected[i]) {
      return false
    }
  }
  tripcolor_source_area(points)
}
