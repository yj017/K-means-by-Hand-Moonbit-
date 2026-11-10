///|
/// Source labels, histogram edges, area and mesh semantics for one identity.
/// Coordinates and current category units are resolved by the actual renderer.
pub struct HitMetadata {
  priv series : String
  priv edges : Array[Double]?
  priv band_horizontal : Bool?
  priv band_values : Array[Double]?
  priv mesh : MeshHitData?
  priv hexbin : HexbinHitData?
  priv discrete : DiscreteLineHitData?
  priv stem : StemHitView?
  priv vector : VectorHitData?
  priv barb : BarbHitView?
  priv contour : ContourHitView?
  priv contourf : ContourFHitData?
  priv tricolor : TripcolorHitData?
  priv streamplot : StreamplotHitView?
}

///|
pub fn hit_metadata(
  series : String,
  edges~ : Array[Double]? = None,
  band_horizontal~ : Bool? = None,
  band_values~ : Array[Double]? = None,
  mesh~ : MeshHitData? = None,
  hexbin~ : HexbinHitData? = None,
  discrete~ : DiscreteLineHitData? = None,
  stem~ : StemHitView? = None,
  vector~ : VectorHitData? = None,
  barb~ : BarbHitView? = None,
  contour~ : ContourHitView? = None,
  contourf~ : ContourFHitData? = None,
  tricolor~ : TripcolorHitData? = None,
  streamplot~ : StreamplotHitView? = None,
) -> HitMetadata {
  {
    series,
    edges: edges.map(values => values.copy()),
    band_horizontal,
    band_values: band_values.map(values => values.copy()),
    mesh,
    hexbin,
    discrete,
    stem,
    vector,
    barb,
    contour,
    contourf,
    tricolor,
    streamplot,
  }
}

///|
pub fn HitMetadata::vector(self : HitMetadata) -> VectorHitData? {
  self.vector
}

///|
pub fn HitMetadata::barb(self : HitMetadata) -> BarbHitView? {
  self.barb
}

///|
pub fn HitMetadata::stem(self : HitMetadata) -> StemHitView? {
  self.stem
}

///|
pub fn HitMetadata::discrete(self : HitMetadata) -> DiscreteLineHitData? {
  self.discrete
}

///|
pub fn HitMetadata::series(self : HitMetadata) -> String {
  self.series
}

///|
pub fn HitMetadata::interval(
  self : HitMetadata,
  index : Int32,
) -> (Double, Double)? {
  match self.edges {
    Some(edges) =>
      if index >= 0 && index + 1 < edges.length() {
        Some((edges[index], edges[index + 1]))
      } else {
        None
      }
    None => None
  }
}

///|
pub fn Panel::hit_metadata(self : Panel, index : Int32) -> HitMetadata {
  if index >= 0 && index < self.hit_metadata.length() {
    self.hit_metadata[index]
  } else {
    hit_metadata("")
  }
}

///|
pub fn HitMetadata::band_horizontal(self : HitMetadata) -> Bool? {
  self.band_horizontal
}

///|
pub fn HitMetadata::band_stacked(self : HitMetadata) -> Bool {
  self.band_values is Some(_)
}

///|
pub fn HitMetadata::band_value(self : HitMetadata, index : Int32) -> Double? {
  match self.band_values {
    Some(values) => values.get(index)
    None => None
  }
}

///|
pub fn HitMetadata::mesh(self : HitMetadata) -> MeshHitData? {
  self.mesh
}

///|
pub fn HitMetadata::hexbin(self : HitMetadata) -> HexbinHitData? {
  self.hexbin
}

///|
pub fn HitMetadata::contour(self : HitMetadata) -> ContourHitView? {
  self.contour
}

///|
pub fn HitMetadata::contourf(self : HitMetadata) -> ContourFHitData? {
  self.contourf
}

///|
pub fn HitMetadata::tricolor(self : HitMetadata) -> TripcolorHitData? {
  self.tricolor
}

///|
pub fn HitMetadata::streamplot(self : HitMetadata) -> StreamplotHitView? {
  self.streamplot
}
