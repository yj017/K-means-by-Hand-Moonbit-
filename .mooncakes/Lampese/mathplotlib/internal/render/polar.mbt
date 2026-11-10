///|
/// A copied, backend-neutral full-circle linear radial projection. Series
/// retain raw theta/r points in ordinary Line/Scatter artists.
pub struct PolarProjection {
  priv radius_max : Double?
  priv theta_offset : Double
  priv clockwise : Bool
  priv theta_ticks : Array[Double]
  priv theta_labels : Array[String]
  priv radius_ticks : Array[Double]?
  priv radius_labels : Array[String]
  priv closed : Array[Bool]
  priv cartesian_compatible : Bool
  priv hit_data : Array[PolarHitData]
}

///|
pub fn polar_projection(
  radius_max : Double?,
  theta_offset : Double,
  clockwise : Bool,
  theta_ticks : Array[Double],
  theta_labels : Array[String],
  radius_ticks : Array[Double]?,
  radius_labels : Array[String],
  closed : Array[Bool],
  cartesian_compatible~ : Bool = true,
  hit_data~ : Array[PolarHitData] = [],
) -> PolarProjection {
  {
    radius_max,
    theta_offset,
    clockwise,
    theta_ticks: theta_ticks.copy(),
    theta_labels: theta_labels.copy(),
    radius_ticks: radius_ticks.map(values => values.copy()),
    radius_labels: radius_labels.copy(),
    closed: closed.copy(),
    cartesian_compatible,
    hit_data: hit_data.copy(),
  }
}

///|
pub fn PolarProjection::radius_max(self : PolarProjection) -> Double? {
  self.radius_max
}

///|
pub fn PolarProjection::theta_offset(self : PolarProjection) -> Double {
  self.theta_offset
}

///|
pub fn PolarProjection::clockwise(self : PolarProjection) -> Bool {
  self.clockwise
}

///|
pub fn PolarProjection::theta_ticks(self : PolarProjection) -> Array[Double] {
  self.theta_ticks.copy()
}

///|
pub fn PolarProjection::theta_labels(self : PolarProjection) -> Array[String] {
  self.theta_labels.copy()
}

///|
pub fn PolarProjection::radius_ticks(self : PolarProjection) -> Array[Double]? {
  self.radius_ticks.map(values => values.copy())
}

///|
pub fn PolarProjection::radius_labels(self : PolarProjection) -> Array[String] {
  self.radius_labels.copy()
}

///|
pub fn PolarProjection::series_count(self : PolarProjection) -> Int32 {
  self.closed.length()
}

///|
pub fn PolarProjection::closed(self : PolarProjection, index : Int32) -> Bool {
  self.closed.get(index).unwrap_or(false)
}

///|
pub fn Panel::polar(self : Panel) -> PolarProjection? {
  self.polar
}

///|
pub fn PolarProjection::cartesian_compatible(self : PolarProjection) -> Bool {
  self.cartesian_compatible
}

///|
pub fn PolarProjection::hit_data(
  self : PolarProjection,
  index : Int32,
) -> PolarHitData? {
  self.hit_data.get(index)
}
