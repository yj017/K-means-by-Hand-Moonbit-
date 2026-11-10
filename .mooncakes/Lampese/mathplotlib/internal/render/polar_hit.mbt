///|
priv enum PolarSourceKind {
  Curve
  Marker
  Bars(Double)
} derive(Eq)

///|
/// One typed polar call's immutable original samples and presentation identity.
/// The original array is retained only to verify the actual artist's provenance.
pub struct PolarHitData {
  priv original : Array[@core.Point]
  priv expected : Array[@core.Point]
  priv series : String
  priv categories : Array[String]?
  priv kind : PolarSourceKind
}

///|
pub fn polar_hit_data(
  points : Array[@core.Point],
  series : String,
  scatter~ : Bool = false,
  categories~ : Array[String]? = None,
) -> PolarHitData {
  {
    original: points,
    expected: points.copy(),
    series,
    categories: categories.map(values => values.copy()),
    kind: if scatter {
      Marker
    } else {
      Curve
    },
  }
}

///|
pub fn PolarHitData::with_categories(
  self : PolarHitData,
  categories : Array[String],
) -> PolarHitData {
  { ..self, categories: Some(categories.copy()), }
}

///|
pub fn PolarHitData::length(self : PolarHitData) -> Int32 {
  self.expected.length()
}

///|
pub fn PolarHitData::point(self : PolarHitData, index : Int32) -> @core.Point? {
  self.expected.get(index)
}

///|
pub fn PolarHitData::series(self : PolarHitData) -> String {
  self.series
}

///|
pub fn PolarHitData::category(self : PolarHitData, index : Int32) -> String? {
  match self.categories {
    Some(values) => values.get(index)
    None => None
  }
}

///|
/// Validate the original identity and complete content once per actual artist.
pub fn PolarHitData::matches_points(
  self : PolarHitData,
  points : Array[@core.Point],
  scatter~ : Bool = false,
) -> Bool {
  self.kind == (if scatter { Marker } else { Curve }) &&
  self.matches_source(points)
}

///|
fn PolarHitData::matches_source(
  self : PolarHitData,
  points : Array[@core.Point],
) -> Bool {
  if !physical_equal(self.original, points) ||
    self.expected.length() != points.length() ||
    (self.categories is Some(values) && values.length() != points.length()) {
    return false
  }
  for i, point in points {
    if !stem_point_equal(point, self.expected[i]) {
      return false
    }
  }
  true
}

///|
/// Preserve the angular width independently of whether capture is still valid.
pub fn polar_bar_hit_data(
  points : Array[@core.Point],
  series : String,
  width : Double,
) -> PolarHitData {
  { ..polar_hit_data(points, series), kind: Bars(width), }
}

///|
pub fn PolarHitData::bar_width(self : PolarHitData) -> Double? {
  match self.kind {
    Bars(width) => Some(width)
    _ => None
  }
}

///|
pub fn PolarHitData::matches_bar(
  self : PolarHitData,
  points : Array[@core.Point],
) -> Bool {
  self.kind is Bars(_) && self.matches_source(points)
}
