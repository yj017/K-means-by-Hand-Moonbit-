///|
priv struct ContourLineage {
  slot : Int32
  level : Double
  series : String
}

///|
/// One immutable lineage per generated path, shared by its inline fragments.
/// Expected geometry is copied once per current fragment, never per edge.
pub struct ContourHitView {
  priv source : ContourLineage
  priv expected : Array[@core.Point]
  priv enabled : Bool
}

///|
pub fn contour_hit_view(
  points : Array[@core.Point],
  slot : Int32,
  level : Double,
  series : String,
) -> ContourHitView {
  { source: { slot, level, series, }, expected: points.copy(), enabled: true, }
}

///|
pub fn ContourHitView::fragment(
  self : ContourHitView,
  points : Array[@core.Point],
) -> ContourHitView {
  { ..self, expected: points.copy(), }
}

///|
pub fn ContourHitView::invalidated(self : ContourHitView) -> ContourHitView {
  { ..self, enabled: false, }
}

///|
pub fn ContourHitView::enabled(self : ContourHitView) -> Bool {
  self.enabled
}

///|
pub fn ContourHitView::slot(self : ContourHitView) -> Int32 {
  self.source.slot
}

///|
pub fn ContourHitView::level(self : ContourHitView) -> Double {
  self.source.level
}

///|
pub fn ContourHitView::series(self : ContourHitView) -> String {
  self.source.series
}

///|
/// Validate the complete current fragment once before the actual writer runs.
/// Nonfinite values use snapshot equality; the writer still splits valid runs.
pub fn ContourHitView::matches_points(
  self : ContourHitView,
  points : Array[@core.Point],
) -> Bool {
  if !self.enabled || points.length() != self.expected.length() {
    return false
  }
  for i, point in points {
    if !stem_point_equal(point, self.expected[i]) {
      return false
    }
  }
  true
}
