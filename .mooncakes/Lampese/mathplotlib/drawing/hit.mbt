///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn hit_distance(x : Double, y : Double) -> Double {
  let x = x.abs()
  let y = y.abs()
  let high = x.max(y)
  let low = x.min(y)
  if high == 0.0 {
    0.0
  } else {
    let ratio = low / high
    high * (1.0 + ratio * ratio).sqrt()
  }
}

///|
fn Drawing::nearest(
  self : Drawing,
  x : Double,
  y : Double,
  radius : Double,
  scale : Double,
) -> HitPoint? {
  if self.width <= 0 ||
    self.height <= 0 ||
    !finite(x) ||
    !finite(y) ||
    !finite(radius) ||
    radius < 0.0 {
    return None
  }
  let mut best : HitPoint? = None
  let mut best_distance = radius
  for point in self.points {
    if self.excluded(point.panel_index, x, y) ||
      !finite(point.screen_x) ||
      !finite(point.screen_y) ||
      !finite(point.data_x) ||
      !finite(point.data_y) {
      continue
    }
    let dx = (point.screen_x - x) * scale
    let dy = (point.screen_y - y) * scale
    if !finite(dx) || !finite(dy) {
      continue
    }
    let distance = hit_distance(dx, dy)
    if distance <= best_distance && (best is None || distance < best_distance) {
      best = Some(point)
      best_distance = distance
    }
  }
  best
}

///|
/// Hit-test intrinsic drawing coordinates. Areas win in reverse paint order,
/// with visible error-bar/box-plot strokes and outliers above an area selectable;
/// point anchors and clipped segments use radius and stable distance ties.
/// XNearest prioritizes nearby non-line/error points, then selects real line
/// or error-bar samples by screen X inside the panel.
/// Legacy drawings without semantic targets retain nearest-point behavior.
pub fn Drawing::hit_test(
  self : Drawing,
  x : Double,
  y : Double,
  radius~ : Double = 10.0,
  mode~ : HitMode = Nearest,
) -> HitPoint? {
  self.target_hit(x, y, radius, 1.0, mode)
}

///|
fn Drawing::viewport_mapping(
  self : Drawing,
  client_x : Double,
  client_y : Double,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
) -> (Double, Double, Double)? {
  if self.width <= 0 ||
    self.height <= 0 ||
    !finite(client_x) ||
    !finite(client_y) ||
    !finite(left) ||
    !finite(top) ||
    !finite(width) ||
    !finite(height) ||
    width <= 0.0 ||
    height <= 0.0 {
    return None
  }
  let intrinsic_width = self.width.to_double()
  let intrinsic_height = self.height.to_double()
  let scale = (width / intrinsic_width).min(height / intrinsic_height)
  if !finite(scale) || scale <= 0.0 {
    return None
  }
  let x = client_x - left
  let y = client_y - top
  if !finite(x) || !finite(y) || x < 0.0 || y < 0.0 || x > width || y > height {
    return None
  }
  let horizontal_padding = (width - intrinsic_width * scale) / 2.0
  let vertical_padding = (height - intrinsic_height * scale) / 2.0
  let x = (x - horizontal_padding) / scale
  let y = (y - vertical_padding) / scale
  if !finite(x) ||
    !finite(y) ||
    x < 0.0 ||
    y < 0.0 ||
    x > intrinsic_width ||
    y > intrinsic_height {
    None
  } else {
    Some((x, y, scale))
  }
}

///|
/// Convert client coordinates for an SVG viewBox="0 0 width height" with
/// preserveAspectRatio="xMidYMid meet". Outside and letterbox hits are absent.
/// The rectangle must be the actual SVG viewport's client rectangle.
pub fn Drawing::viewport_point(
  self : Drawing,
  client_x : Double,
  client_y : Double,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
) -> (Double, Double)? {
  self
  .viewport_mapping(client_x, client_y, left, top, width, height)
  .map(mapping => (mapping.0, mapping.1))
}

///|
/// Hit-test client coordinates with a radius measured in CSS pixels.
pub fn Drawing::hit_test_client(
  self : Drawing,
  client_x : Double,
  client_y : Double,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
  radius~ : Double = 10.0,
  mode~ : HitMode = Nearest,
) -> HitPoint? {
  match self.viewport_mapping(client_x, client_y, left, top, width, height) {
    Some((x, y, scale)) => self.target_hit(x, y, radius, scale, mode)
    None => None
  }
}
