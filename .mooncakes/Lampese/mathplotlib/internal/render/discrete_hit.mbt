///|
/// One source datum shared by piecewise constant curve geometry.
pub struct DiscreteDatum {
  index : Int32
  point : @core.Point
  value : Double
  interval : (Double, Double)?
  fraction : Double?
  band : @drawing.BandInfo?
}

///|
pub fn discrete_datum(
  index : Int32,
  point : @core.Point,
  value : Double,
  interval~ : (Double, Double)? = None,
  fraction~ : Double? = None,
  band~ : @drawing.BandInfo? = None,
) -> DiscreteDatum {
  { index, point, value, interval, fraction, band, }
}

///|
/// A copied source path and its edge-to-datum map. No expanded corner is a
/// source sample; the same immutable carrier serves Step, Stairs and Ecdf.
pub struct DiscreteLineHitData {
  kind : @drawing.HitKind
  priv points : Array[@core.Point]
  priv datums : Array[DiscreteDatum]
  priv owners : Array[Int32]
}

///|
pub fn discrete_line_hit_data(
  kind : @drawing.HitKind,
  points : Array[@core.Point],
  datums : Array[DiscreteDatum],
  owners : Array[Int32],
) -> DiscreteLineHitData? {
  if (kind != Step && kind != Stairs && kind != Ecdf) ||
    owners.length() != (points.length() - 1).max(0) {
    return None
  }
  for owner in owners {
    if owner < 0 || owner >= datums.length() {
      return None
    }
  }
  Some({
    kind,
    points: points.copy(),
    datums: datums.copy(),
    owners: owners.copy(),
  })
}

///|
pub fn DiscreteLineHitData::datum(
  self : DiscreteLineHitData,
  index : Int32,
) -> DiscreteDatum? {
  self.datums.get(index)
}

///|
pub fn DiscreteLineHitData::datum_count(self : DiscreteLineHitData) -> Int32 {
  self.datums.length()
}

///|
pub fn DiscreteLineHitData::owner(
  self : DiscreteLineHitData,
  edge : Int32,
) -> Int32? {
  self.owners.get(edge)
}

///|
// Corresponding NaNs are the same missing slot; they are never a wildcard.
// Preserve infinity and signed-zero distinctions without converting units.
fn discrete_number_equal(a : Double, b : Double) -> Bool {
  if a.is_nan() || b.is_nan() {
    a.is_nan() && b.is_nan()
  } else if a != b {
    false
  } else if a == 0.0 {
    1.0 / a == 1.0 / b
  } else {
    true
  }
}

///|
pub fn DiscreteLineHitData::matches_path(
  self : DiscreteLineHitData,
  points : Array[@core.Point],
) -> Bool {
  if points.length() != self.points.length() {
    return false
  }
  for i, p in points {
    let expected = self.points[i]
    if !discrete_number_equal(p.x(), expected.x()) ||
      !discrete_number_equal(p.y(), expected.y()) {
      return false
    }
  }
  true
}

///|
pub fn DiscreteLineHitData::matches_xy(
  self : DiscreteLineHitData,
  xs : Array[Double],
  ys : Array[Double],
) -> Bool {
  if xs.length() != self.points.length() || ys.length() != self.points.length() {
    return false
  }
  for i, p in self.points {
    if !discrete_number_equal(xs[i], p.x()) ||
      !discrete_number_equal(ys[i], p.y()) {
      return false
    }
  }
  true
}
