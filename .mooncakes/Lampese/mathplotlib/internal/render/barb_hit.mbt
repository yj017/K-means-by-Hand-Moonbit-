///|
pub(all) enum BarbComponent {
  Stroke
  Flag
  Calm
}

///|
/// One immutable input table and label per call, shared by all components.
pub struct BarbHitData {
  priv source : VectorHitData
  priv series : String
}

///|
/// Only the component's one, two or three expected points are copied here.
pub struct BarbHitView {
  priv source : BarbHitData
  priv index : Int32
  priv component : BarbComponent
  priv expected : Array[@core.Point]
  priv enabled : Bool
}

///|
pub fn barb_hit_data(
  points : Array[@core.Point],
  vectors : Array[@core.Point],
  series : String,
) -> BarbHitData? {
  vector_hit_data(points, vectors).map(source => { source, series, })
}

///|
pub fn BarbHitData::view(
  self : BarbHitData,
  index : Int32,
  component : BarbComponent,
  points : Array[@core.Point],
) -> BarbHitView? {
  let size = match component {
    Stroke => 2
    Flag => 3
    Calm => 1
  }
  if self.source.datum(index) is None || points.length() != size {
    return None
  }
  Some({
    source: self,
    index,
    component,
    expected: points.copy(),
    enabled: true,
  })
}

///|
/// Preserve known Barbs intent after an identity miss, without authorizing hits.
pub fn BarbHitView::invalidated(self : BarbHitView) -> BarbHitView {
  { ..self, enabled: false, }
}

///|
pub fn BarbHitView::enabled(self : BarbHitView) -> Bool {
  self.enabled
}

///|
pub fn BarbHitView::datum(self : BarbHitView) -> VectorDatum? {
  self.source.source.datum(self.index)
}

///|
pub fn BarbHitView::series(self : BarbHitView) -> String {
  self.source.series
}

///|
pub fn BarbHitView::component(self : BarbHitView) -> BarbComponent {
  self.component
}

///|
/// O(1) in the input call size, including partially completed calls.
pub fn BarbHitView::matches_points(
  self : BarbHitView,
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
