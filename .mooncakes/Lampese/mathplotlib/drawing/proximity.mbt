///|
fn target_distance(
  target : HitTarget,
  x : Double,
  y : Double,
  scale : Double,
) -> Double? {
  match target.shape {
    Point => {
      let point = target.info.point
      if !rect_contains(target.bounds, point.screen_x, point.screen_y) {
        return None
      }
      if discrete_source_roundoff(target, x, y) {
        return Some(0.0)
      }
      let dx = (point.screen_x - x) * scale
      let dy = (point.screen_y - y) * scale
      if finite(dx) && finite(dy) {
        Some(hit_distance(dx, dy))
      } else {
        None
      }
    }
    Segment(x0, y0, x1, y1) =>
      segment_distance(x0, y0, x1, y1, target.bounds, x, y).map(d => d * scale)
    _ => None
  }
}

///|
// An area covers earlier statistics, but it must not swallow later visible
// whiskers or outliers. A physical hit opens that overlay's selection; XNearest
// still chooses a real error-bar center, never a generated arm endpoint.
fn Drawing::statistical_overlay_hit(
  self : Drawing,
  area_index : Int32,
  x : Double,
  y : Double,
  radius : Double,
  scale : Double,
  mode : HitMode,
) -> HitPoint? {
  let polar_area = self.targets[area_index].info.kind == PolarBar
  let mut best : HitPoint? = None
  let mut best_distance = radius
  let mut best_target : HitTarget? = None
  let eligible_errors : Map[(Int32, Int32), Bool] = Map([])
  for index in (area_index + 1)..<self.targets.length() {
    let target = self.targets[index]
    let point = target.info.point
    if (
        target.info.kind != ErrorBar &&
        target.info.kind != BoxPlot &&
        target.info.kind != Violin &&
        !discrete_kind(target.info.kind) &&
        !(polar_area && target.info.kind == Polar && target.shape == Point)
      ) ||
      self.excluded(
        point.panel_index,
        x,
        y,
        polar=target.info.kind.requires_polar_circle(),
      ) ||
      !valid_info(target.info) ||
      !valid_shape(target.shape) ||
      !rect_contains(target.bounds, x, y) {
      continue
    }
    guard target_distance(target, x, y, scale) is Some(distance) else {
      continue
    }
    if distance > radius || !finite(distance) {
      continue
    }
    if mode == XNearest && target.info.kind == ErrorBar {
      let identity = (point.panel_index, point.artist_index)
      eligible_errors[identity] = true
    } else if distance <= best_distance &&
      (
        best is None ||
        distance < best_distance ||
        (distance == best_distance && proximity_tie_later(target, best_target))
      ) {
      best = Some(point)
      best_distance = distance
      best_target = Some(target)
    }
  }
  if best is Some(_) || mode == Nearest || eligible_errors.is_empty() {
    return best
  }
  let mut best_dx = 0.0
  let mut best_dy = 0.0
  for index in (area_index + 1)..<self.targets.length() {
    let target = self.targets[index]
    let point = target.info.point
    if target.info.kind != ErrorBar ||
      target.shape != Point ||
      eligible_errors.get((point.panel_index, point.artist_index)) is None ||
      self.excluded(
        point.panel_index,
        x,
        y,
        polar=target.info.kind.requires_polar_circle(),
      ) ||
      !valid_info(target.info) ||
      !rect_contains(target.bounds, x, y) ||
      !rect_contains(target.bounds, point.screen_x, point.screen_y) {
      continue
    }
    let dx = (point.screen_x - x).abs()
    let dy = (point.screen_y - y).abs()
    if !finite(dx) || !finite(dy) {
      continue
    }
    if best is None || dx < best_dx || (dx == best_dx && dy < best_dy) {
      best = Some(point)
      best_dx = dx
      best_dy = dy
    }
  }
  best
}
