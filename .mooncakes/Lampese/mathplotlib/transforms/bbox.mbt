///|
/// An axis-aligned rectangle in data or display coordinates.
pub struct BBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// Construct a bounding box from its two corners.
pub fn bbox(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> BBox {
  { x0, y0, x1, y1, }
}

///|
/// Construct a box from an origin and its width and height.
pub fn bbox_from_bounds(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> BBox {
  { x0: x, y0: y, x1: x + width, y1: y + height, }
}

///|
/// Construct the unit box from `(0, 0)` to `(1, 1)`.
pub fn unit_bbox() -> BBox {
  bbox(0.0, 0.0, 1.0, 1.0)
}

///|
/// Construct an empty box whose extents can be expanded by union operations.
pub fn null_bbox() -> BBox {
  bbox(
    @double.infinity, @double.infinity, @double.neg_infinity, @double.neg_infinity,
  )
}

///|
pub fn BBox::x0(self : BBox) -> Double {
  self.x0
}

///|
pub fn BBox::y0(self : BBox) -> Double {
  self.y0
}

///|
pub fn BBox::x1(self : BBox) -> Double {
  self.x1
}

///|
pub fn BBox::y1(self : BBox) -> Double {
  self.y1
}

///|
pub fn BBox::xmin(self : BBox) -> Double {
  Double::min(self.x0, self.x1)
}

///|
pub fn BBox::xmax(self : BBox) -> Double {
  Double::max(self.x0, self.x1)
}

///|
pub fn BBox::ymin(self : BBox) -> Double {
  Double::min(self.y0, self.y1)
}

///|
pub fn BBox::ymax(self : BBox) -> Double {
  Double::max(self.y0, self.y1)
}

///|
pub fn BBox::width(self : BBox) -> Double {
  self.x1 - self.x0
}

///|
pub fn BBox::height(self : BBox) -> Double {
  self.y1 - self.y0
}

///|
/// Return `(x0, y0, width, height)` using the box's original orientation.
pub fn BBox::bounds(self : BBox) -> (Double, Double, Double, Double) {
  (self.x0, self.y0, self.width(), self.height())
}

///|
/// Return the signed `(width, height)` pair.
pub fn BBox::size(self : BBox) -> (Double, Double) {
  (self.width(), self.height())
}

///|
/// Return the lower-left coordinate after normalizing each axis.
pub fn BBox::min_point(self : BBox) -> @core.Point {
  @core.point(self.xmin(), self.ymin())
}

///|
/// Return the upper-right coordinate after normalizing each axis.
pub fn BBox::max_point(self : BBox) -> @core.Point {
  @core.point(self.xmax(), self.ymax())
}

///|
/// Return the original x interval, preserving its orientation.
pub fn BBox::interval_x(self : BBox) -> (Double, Double) {
  (self.x0, self.x1)
}

///|
/// Return the original y interval, preserving its orientation.
pub fn BBox::interval_y(self : BBox) -> (Double, Double) {
  (self.y0, self.y1)
}

///|
pub fn BBox::is_finite(self : BBox) -> Bool {
  !self.x0.is_nan() &&
  !self.x0.is_inf() &&
  !self.y0.is_nan() &&
  !self.y0.is_inf() &&
  !self.x1.is_nan() &&
  !self.x1.is_inf() &&
  !self.y1.is_nan() &&
  !self.y1.is_inf()
}

///|
pub fn BBox::corners(self : BBox) -> Array[@core.Point] {
  [
    @core.point(self.x0, self.y0),
    @core.point(self.x0, self.y1),
    @core.point(self.x1, self.y1),
    @core.point(self.x1, self.y0),
  ]
}

///|
pub fn BBox::contains(self : BBox, x : Double, y : Double) -> Bool {
  self.contains_x(x) && self.contains_y(y)
}

///|
/// Return whether x lies in the closed interval, including reversed bounds.
pub fn BBox::contains_x(self : BBox, x : Double) -> Bool {
  (self.x0 <= x && x <= self.x1) || (self.x1 <= x && x <= self.x0)
}

///|
/// Return whether y lies in the closed interval, including reversed bounds.
pub fn BBox::contains_y(self : BBox, y : Double) -> Bool {
  (self.y0 <= y && y <= self.y1) || (self.y1 <= y && y <= self.y0)
}

///|
/// Return whether x lies strictly inside the interval.
pub fn BBox::fully_contains_x(self : BBox, x : Double) -> Bool {
  (self.x0 < x && x < self.x1) || (self.x1 < x && x < self.x0)
}

///|
/// Return whether y lies strictly inside the interval.
pub fn BBox::fully_contains_y(self : BBox, y : Double) -> Bool {
  (self.y0 < y && y < self.y1) || (self.y1 < y && y < self.y0)
}

///|
/// Return whether a point lies strictly inside the box.
pub fn BBox::fully_contains(self : BBox, x : Double, y : Double) -> Bool {
  self.fully_contains_x(x) && self.fully_contains_y(y)
}

///|
pub fn BBox::contains_point(self : BBox, point : @core.Point) -> Bool {
  self.contains(point.x(), point.y())
}

///|
pub fn BBox::overlaps(self : BBox, other : BBox) -> Bool {
  self.xmin() <= other.xmax() &&
  self.xmax() >= other.xmin() &&
  self.ymin() <= other.ymax() &&
  self.ymax() >= other.ymin()
}

///|
/// Return whether the interiors of two boxes overlap.
pub fn BBox::fully_overlaps(self : BBox, other : BBox) -> Bool {
  self.xmin() < other.xmax() &&
  self.xmax() > other.xmin() &&
  self.ymin() < other.ymax() &&
  self.ymax() > other.ymin()
}

///|
pub fn BBox::intersection(self : BBox, other : BBox) -> BBox? {
  let x0 = Double::max(self.xmin(), other.xmin())
  let y0 = Double::max(self.ymin(), other.ymin())
  let x1 = Double::min(self.xmax(), other.xmax())
  let y1 = Double::min(self.ymax(), other.ymax())
  if x0 <= x1 && y0 <= y1 {
    Some(bbox(x0, y0, x1, y1))
  } else {
    None
  }
}

///|
pub fn BBox::union(self : BBox, other : BBox) -> BBox {
  bbox(
    Double::min(self.xmin(), other.xmin()),
    Double::min(self.ymin(), other.ymin()),
    Double::max(self.xmax(), other.xmax()),
    Double::max(self.ymax(), other.ymax()),
  )
}

///|
pub fn BBox::translated(self : BBox, x : Double, y : Double) -> BBox {
  bbox(self.x0 + x, self.y0 + y, self.x1 + x, self.y1 + y)
}

///|
pub fn BBox::expanded(self : BBox, x_scale : Double, y_scale : Double) -> BBox {
  let center_x = (self.x0 + self.x1) / 2.0
  let center_y = (self.y0 + self.y1) / 2.0
  let half_width = self.width() * x_scale / 2.0
  let half_height = self.height() * y_scale / 2.0
  bbox(
    center_x - half_width,
    center_y - half_height,
    center_x + half_width,
    center_y + half_height,
  )
}

///|
/// Shrink or expand from the lower-left corner by axis factors.
pub fn BBox::shrunk(self : BBox, x_scale : Double, y_scale : Double) -> BBox {
  bbox(
    self.x0,
    self.y0,
    self.x0 + self.width() * x_scale,
    self.y0 + self.height() * y_scale,
  )
}

///|
/// Shrink the box to the largest rectangle with the requested physical
/// aspect ratio. The result keeps the original lower-left corner.
pub fn BBox::shrunk_to_aspect(
  self : BBox,
  box_aspect : Double,
  container? : BBox,
  fig_aspect~ : Double = 1.0,
) -> BBox {
  if box_aspect <= 0.0 || fig_aspect <= 0.0 {
    return self
  }
  let container_box = match container {
    Some(value) => value
    None => self
  }
  let container_width = container_box.width()
  let container_height = container_box.height()
  let desired_height = container_width * box_aspect / fig_aspect
  let (width, height) = if desired_height <= container_height {
    (container_width, desired_height)
  } else {
    (container_height * fig_aspect / box_aspect, container_height)
  }
  bbox(self.x0, self.y0, self.x0 + width, self.y0 + height)
}

///|
pub fn BBox::padded(self : BBox, x : Double, y : Double) -> BBox {
  bbox(self.x0 - x, self.y0 - y, self.x1 + x, self.y1 + y)
}

///|
/// Split the box at fractional x positions in `[0, 1]`.
pub fn BBox::split_x(self : BBox, fractions : Array[Double]) -> Array[BBox] {
  let result : Array[BBox] = []
  let mut previous = 0.0
  for fraction in fractions {
    result.push(
      bbox(
        self.x0 + previous * self.width(),
        self.y0,
        self.x0 + fraction * self.width(),
        self.y1,
      ),
    )
    previous = fraction
  }
  result.push(
    bbox(self.x0 + previous * self.width(), self.y0, self.x1, self.y1),
  )
  result
}

///|
/// Split the box at fractional y positions in `[0, 1]`.
pub fn BBox::split_y(self : BBox, fractions : Array[Double]) -> Array[BBox] {
  let result : Array[BBox] = []
  let mut previous = 0.0
  for fraction in fractions {
    result.push(
      bbox(
        self.x0,
        self.y0 + previous * self.height(),
        self.x1,
        self.y0 + fraction * self.height(),
      ),
    )
    previous = fraction
  }
  result.push(
    bbox(self.x0, self.y0 + previous * self.height(), self.x1, self.y1),
  )
  result
}

///|
/// Return an axis-aligned box containing this box after rotation around the
/// origin.
pub fn BBox::rotated(self : BBox, radians : Double) -> BBox {
  let transform = rotation(radians)
  let points = transform.apply_all(self.corners())
  let first = points[0]
  let mut x0 = first.x()
  let mut x1 = first.x()
  let mut y0 = first.y()
  let mut y1 = first.y()
  for point in points[1:] {
    x0 = Double::min(x0, point.x())
    x1 = Double::max(x1, point.x())
    y0 = Double::min(y0, point.y())
    y1 = Double::max(y1, point.y())
  }
  bbox(x0, y0, x1, y1)
}

///|
/// Transform all four corners and return the enclosing axis-aligned box.
pub fn BBox::transformed(self : BBox, transform : Affine2D) -> BBox {
  let points = transform.apply_all(self.corners())
  let first = points[0]
  let mut x0 = first.x()
  let mut x1 = first.x()
  let mut y0 = first.y()
  let mut y1 = first.y()
  for point in points[1:] {
    x0 = Double::min(x0, point.x())
    x1 = Double::max(x1, point.x())
    y0 = Double::min(y0, point.y())
    y1 = Double::max(y1, point.y())
  }
  bbox(x0, y0, x1, y1)
}
