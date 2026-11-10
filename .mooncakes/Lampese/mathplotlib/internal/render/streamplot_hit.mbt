///|
pub struct StreamplotDatum {
  index : Int32
  point : @core.Point
  info : @drawing.StreamplotInfo
}

///|
pub fn streamplot_datum(
  index : Int32,
  point : @core.Point,
  info : @drawing.StreamplotInfo,
) -> StreamplotDatum {
  { index, point, info, }
}

///|
/// One immutable generated trajectory and optional samples, shared by split views.
pub struct StreamplotHitData {
  priv points : Array[@core.Point]
  priv datums : Array[StreamplotDatum?]
}

///|
pub fn streamplot_hit_data(
  points : Array[@core.Point],
  datums : Array[StreamplotDatum?],
) -> StreamplotHitData {
  { points: points.copy(), datums: datums.copy(), }
}

///|
/// None source means an owned-static actual arrow component, including a shaft
/// absent from the returned set. No public arrow-part semantics are inferred.
pub struct StreamplotHitView {
  priv source : StreamplotHitData?
  priv original : Array[@core.Point]
  priv point_count : Int32
  priv first_edge : Int32
  priv series : String
  priv enabled : Bool
}

///|
pub fn streamplot_body_hit(
  source : StreamplotHitData,
  points : Array[@core.Point],
  first_edge : Int32,
  series : String,
) -> StreamplotHitView {
  {
    source: Some(source),
    original: points,
    point_count: points.length(),
    first_edge,
    series,
    enabled: true,
  }
}

///|
pub fn streamplot_static_hit(
  points : Array[@core.Point],
  series : String,
) -> StreamplotHitView {
  {
    source: None,
    original: points,
    point_count: points.length(),
    first_edge: 0,
    series,
    enabled: true,
  }
}

///|
pub fn StreamplotHitView::invalidated(
  self : StreamplotHitView,
) -> StreamplotHitView {
  { ..self, enabled: false, }
}

///|
pub fn StreamplotHitView::enabled(self : StreamplotHitView) -> Bool {
  self.enabled
}

///|
pub fn StreamplotHitView::body(self : StreamplotHitView) -> Bool {
  self.source is Some(_)
}

///|
pub fn StreamplotHitView::series(self : StreamplotHitView) -> String {
  self.series
}

///|
/// Once per actual Line: a split view checks only its own two points.
pub fn StreamplotHitView::matches_points(
  self : StreamplotHitView,
  points : Array[@core.Point],
) -> Bool {
  guard self.source is Some(data) else { return false }
  if !self.enabled ||
    !physical_equal(self.original, points) ||
    points.length() != self.point_count ||
    self.first_edge < 0 ||
    points.length() > data.points.length() ||
    self.first_edge > data.points.length() - points.length() {
    return false
  }
  for i, p in points {
    if !stem_point_equal(p, data.points[self.first_edge + i]) {
      return false
    }
  }
  true
}

///|
pub fn StreamplotHitView::datum(
  self : StreamplotHitView,
  local_edge : Int32,
) -> StreamplotDatum? {
  guard self.enabled && self.source is Some(data) else { return None }
  if local_edge < 0 ||
    local_edge >= self.point_count - 1 ||
    self.first_edge < 0 ||
    self.first_edge >= data.datums.length() ||
    local_edge >= data.datums.length() - self.first_edge {
    return None
  }
  match data.datums.get(self.first_edge + local_edge) {
    Some(datum) => datum
    None => None
  }
}
