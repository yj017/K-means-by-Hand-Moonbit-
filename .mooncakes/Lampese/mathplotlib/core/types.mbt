///|
/// A point in the data coordinate system.
pub struct Point {
  x : Double
  y : Double
}

///|
/// Construct a data point.
pub fn point(x : Double, y : Double) -> Point {
  { x, y, }
}

///|
/// Return the x coordinate of a point.
pub fn Point::x(self : Point) -> Double {
  self.x
}

///|
/// Return the y coordinate of a point.
pub fn Point::y(self : Point) -> Double {
  self.y
}

///|
/// Whether both coordinates are finite numbers.
pub fn Point::is_finite(self : Point) -> Bool {
  !self.x.is_nan() && !self.x.is_inf() && !self.y.is_nan() && !self.y.is_inf()
}

///|
/// Whether the point is a missing sample for plotting purposes.
pub fn Point::is_missing(self : Point) -> Bool {
  !self.is_finite()
}

///|
/// Return the color of a style.
pub fn Style::color(self : Style) -> String {
  self.color
}

///|
/// Return the line width of a style.
pub fn Style::width(self : Style) -> Double {
  self.width
}

///|
/// Return the marker radius of a style.
pub fn Style::radius(self : Style) -> Double {
  self.radius
}

///|
/// Return the fill color of a style.
pub fn Style::fill(self : Style) -> String {
  self.fill
}

///|
/// Return the font size used by text artists.
pub fn Style::font_size(self : Style) -> Double {
  self.font_size
}

///|
/// Return the marker shape used by marker artists.
pub fn Style::marker(self : Style) -> String {
  self.marker
}

///|
/// Optional alpha used by Line strokes; other Artist consumers are unchanged.
pub fn Style::line_alpha(self : Style) -> Double? {
  self.line_alpha
}

///|
/// Effective appearance for Line strokes; other Artist consumers are unchanged.
pub fn Style::line_stroke(self : Style) -> LineStroke {
  self.line_stroke
}

///|
/// Optional raw gap color for native Line handles; other Artists are unchanged.
pub fn Style::line_gapcolor(self : Style) -> String? {
  self.line_gapcolor
}

///|
/// Styling shared by line, scatter, and bar plots.
pub struct Style {
  color : String
  width : Double
  radius : Double
  fill : String
  font_size : Double
  marker : String
  priv line_alpha : Double?
  priv line_stroke : LineStroke
  priv line_gapcolor : String?
}

///|
/// Construct a line or marker style.
pub fn style(
  color : String,
  width~ : Double = 2.0,
  radius~ : Double = 3.0,
  fill~ : String = "",
  font_size~ : Double = 12.0,
  marker~ : String = "o",
  line_alpha~ : Double? = None,
  line_stroke~ : LineStroke = default_line_stroke(),
  line_gapcolor~ : String? = None,
) -> Style {
  {
    color,
    width,
    radius,
    fill,
    font_size,
    marker,
    line_alpha,
    line_stroke,
    line_gapcolor,
  }
}

///|
/// Explicit data limits. When omitted, a figure computes limits from its plots.
pub struct Bounds {
  xmin : Double
  xmax : Double
  ymin : Double
  ymax : Double
}

///|
/// Construct explicit data limits.
pub fn bounds(
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
) -> Bounds {
  { xmin, xmax, ymin, ymax, }
}

///|
/// Return the lower x limit.
pub fn Bounds::xmin(self : Bounds) -> Double {
  self.xmin
}

///|
/// Return the upper x limit.
pub fn Bounds::xmax(self : Bounds) -> Double {
  self.xmax
}

///|
/// Return the lower y limit.
pub fn Bounds::ymin(self : Bounds) -> Double {
  self.ymin
}

///|
/// Return the upper y limit.
pub fn Bounds::ymax(self : Bounds) -> Double {
  self.ymax
}

///|
/// Whether all four limits are finite numbers.
pub fn Bounds::is_finite(self : Bounds) -> Bool {
  !self.xmin.is_nan() &&
  !self.xmin.is_inf() &&
  !self.xmax.is_nan() &&
  !self.xmax.is_inf() &&
  !self.ymin.is_nan() &&
  !self.ymin.is_inf() &&
  !self.ymax.is_nan() &&
  !self.ymax.is_inf()
}
