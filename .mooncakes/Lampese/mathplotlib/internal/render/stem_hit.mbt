///|
/// One copied call-level source table, shared by every stem component.
pub struct StemHitData {
  priv datums : Array[DiscreteDatum]
}

///|
/// A constant-size component view. None identifies the single heads artist.
pub struct StemHitView {
  priv source : StemHitData
  priv rod : Int32?
}

///|
pub fn stem_hit_data(
  heads : Array[Double],
  locations : Array[Double],
  bottom : Double,
  horizontal : Bool,
) -> StemHitData? {
  if heads.length() != locations.length() {
    return None
  }
  let datums = Array(capacity=heads.length())
  for i, head in heads {
    let p = if horizontal {
      @core.point(head, locations[i])
    } else {
      @core.point(locations[i], head)
    }
    datums.push(
      discrete_datum(
        i,
        p,
        head,
        band=Some(@drawing.band_info(bottom, head, horizontal~)),
      ),
    )
  }
  Some({ datums, })
}

///|
pub fn StemHitData::view(
  self : StemHitData,
  rod~ : Int32? = None,
) -> StemHitView {
  { source: self, rod, }
}

///|
pub fn StemHitView::rod(self : StemHitView) -> Int32? {
  self.rod
}

///|
pub fn StemHitView::datum(self : StemHitView, index : Int32) -> DiscreteDatum? {
  self.source.datums.get(index)
}

///|
fn stem_point_equal(a : @core.Point, b : @core.Point) -> Bool {
  discrete_number_equal(a.x(), b.x()) && discrete_number_equal(a.y(), b.y())
}

///|
/// Validate each rod in O(1); validate the complete heads array only once.
pub fn StemHitView::matches_points(
  self : StemHitView,
  points : Array[@core.Point],
) -> Bool {
  match self.rod {
    Some(i) => {
      guard self.datum(i) is Some(datum) else { return false }
      guard datum.band is Some(band) else { return false }
      let bottom = if band.horizontal {
        @core.point(band.lower, datum.point.y())
      } else {
        @core.point(datum.point.x(), band.lower)
      }
      points.length() == 2 &&
      stem_point_equal(points[0], bottom) &&
      stem_point_equal(points[1], datum.point)
    }
    None => {
      if points.length() != self.source.datums.length() {
        return false
      }
      for i, p in points {
        if !stem_point_equal(p, self.source.datums[i].point) {
          return false
        }
      }
      true
    }
  }
}
