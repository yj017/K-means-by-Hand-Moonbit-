///|
/// Errors raised while parsing a color specification.
pub(all) suberror ColorError {
  InvalidColor(String)
  ComponentOutOfRange(String)
  InvalidColorMap(String)
}

///|
/// An RGBA color with components normalized to the interval [0, 1].
pub struct Rgba {
  red : Double
  green : Double
  blue : Double
  alpha : Double
}

///|
/// An opaque RGB color with components normalized to the interval [0, 1].
///
/// RGB image inputs are converted to RGBA at the scene boundary with an
/// implicit alpha value of one. Keeping the opaque form separate makes the
/// channel count explicit in typed APIs while retaining one backend color
/// representation.
pub struct Rgb {
  red : Double
  green : Double
  blue : Double
}

///|
/// A piecewise-linear scalar colormap.
pub struct ColorMap {
  name : String
  stops : Array[Rgba]
  discrete : Bool
  mut under : Rgba?
  mut over : Rgba?
  mut bad : Rgba?
}

///|
/// Construct an RGBA value after validating all components.
pub fn rgba(
  red : Double,
  green : Double,
  blue : Double,
  alpha~ : Double = 1.0,
) -> Rgba raise ColorError {
  if !valid_component(red) {
    raise ColorError::ComponentOutOfRange("red")
  }
  if !valid_component(green) {
    raise ColorError::ComponentOutOfRange("green")
  }
  if !valid_component(blue) {
    raise ColorError::ComponentOutOfRange("blue")
  }
  if !valid_component(alpha) {
    raise ColorError::ComponentOutOfRange("alpha")
  }
  { red, green, blue, alpha, }
}

///|
/// Construct an opaque RGB value after validating all components.
pub fn rgb(red : Double, green : Double, blue : Double) -> Rgb raise ColorError {
  if !valid_component(red) {
    raise ColorError::ComponentOutOfRange("red")
  }
  if !valid_component(green) {
    raise ColorError::ComponentOutOfRange("green")
  }
  if !valid_component(blue) {
    raise ColorError::ComponentOutOfRange("blue")
  }
  { red, green, blue, }
}

///|
fn valid_component(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf() && value >= 0.0 && value <= 1.0
}

///|
pub fn Rgba::red(self : Rgba) -> Double {
  self.red
}

///|
pub fn Rgba::green(self : Rgba) -> Double {
  self.green
}

///|
pub fn Rgba::blue(self : Rgba) -> Double {
  self.blue
}

///|
pub fn Rgba::alpha(self : Rgba) -> Double {
  self.alpha
}

///|
/// Scale the opacity of a color by a validated global image alpha.
///
/// The RGB components and the existing per-pixel alpha are preserved while
/// the resulting opacity is multiplied by `factor`.
pub fn Rgba::scale_alpha(self : Rgba, factor : Double) -> Rgba raise ColorError {
  if !valid_component(factor) {
    raise ColorError::ComponentOutOfRange("alpha")
  }
  {
    red: self.red,
    green: self.green,
    blue: self.blue,
    alpha: self.alpha * factor,
  }
}

///|
pub fn Rgb::red(self : Rgb) -> Double {
  self.red
}

///|
pub fn Rgb::green(self : Rgb) -> Double {
  self.green
}

///|
pub fn Rgb::blue(self : Rgb) -> Double {
  self.blue
}

///|
/// Convert an opaque RGB value to the common RGBA backend representation.
pub fn Rgb::to_rgba(self : Rgb) -> Rgba {
  { red: self.red, green: self.green, blue: self.blue, alpha: 1.0, }
}

///|
fn hex_digit(value : Char) -> Int32? {
  match value {
    '0' => Some(0)
    '1' => Some(1)
    '2' => Some(2)
    '3' => Some(3)
    '4' => Some(4)
    '5' => Some(5)
    '6' => Some(6)
    '7' => Some(7)
    '8' => Some(8)
    '9' => Some(9)
    'a' | 'A' => Some(10)
    'b' | 'B' => Some(11)
    'c' | 'C' => Some(12)
    'd' | 'D' => Some(13)
    'e' | 'E' => Some(14)
    'f' | 'F' => Some(15)
    _ => None
  }
}

///|
fn parse_hex_byte(chars : Array[Char], index : Int32) -> Int32? {
  match (hex_digit(chars[index]), hex_digit(chars[index + 1])) {
    (Some(high), Some(low)) => Some(high * 16 + low)
    _ => None
  }
}

///|
fn byte_component(value : Int32) -> Double {
  Double::from_int(value) / 255.0
}

///|
fn parse_hex(value : String) -> Rgba? {
  let chars = value.to_array()
  match chars.length() {
    4 =>
      match (hex_digit(chars[1]), hex_digit(chars[2]), hex_digit(chars[3])) {
        (Some(red), Some(green), Some(blue)) =>
          Some({
            red: byte_component(red * 17),
            green: byte_component(green * 17),
            blue: byte_component(blue * 17),
            alpha: 1.0,
          })
        _ => None
      }
    7 =>
      match
        (
          parse_hex_byte(chars, 1),
          parse_hex_byte(chars, 3),
          parse_hex_byte(chars, 5),
        ) {
        (Some(red), Some(green), Some(blue)) =>
          Some({
            red: byte_component(red),
            green: byte_component(green),
            blue: byte_component(blue),
            alpha: 1.0,
          })
        _ => None
      }
    9 =>
      match
        (
          parse_hex_byte(chars, 1),
          parse_hex_byte(chars, 3),
          parse_hex_byte(chars, 5),
          parse_hex_byte(chars, 7),
        ) {
        (Some(red), Some(green), Some(blue), Some(alpha)) =>
          Some({
            red: byte_component(red),
            green: byte_component(green),
            blue: byte_component(blue),
            alpha: byte_component(alpha),
          })
        _ => None
      }
    _ => None
  }
}

///|
/// Parse a small CSS-compatible color vocabulary and hexadecimal colors.
pub fn parse_color(value : String) -> Rgba raise ColorError {
  let normalized = value.to_lower()
  match normalized {
    "transparent" => rgba(0.0, 0.0, 0.0, alpha=0.0)
    "black" => rgba(0.0, 0.0, 0.0)
    "white" => rgba(1.0, 1.0, 1.0)
    "red" => rgba(1.0, 0.0, 0.0)
    "green" => rgba(0.0, 0.5019607843137255, 0.0)
    "blue" => rgba(0.0, 0.0, 1.0)
    "yellow" => rgba(1.0, 1.0, 0.0)
    "cyan" => rgba(0.0, 1.0, 1.0)
    "magenta" => rgba(1.0, 0.0, 1.0)
    "gray" | "grey" =>
      rgba(0.5019607843137255, 0.5019607843137255, 0.5019607843137255)
    _ =>
      match parse_hex(value) {
        Some(color) => color
        None => raise ColorError::InvalidColor(value)
      }
  }
}

///|
fn hex_chars() -> Array[String] {
  [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
}

///|
fn byte_hex(value : Double) -> String {
  let byte = (value * 255.0) |> Double::round |> Double::to_int
  let digits = hex_chars()
  digits[byte / 16] + digits[byte % 16]
}

///|
/// Return an opaque color as #rrggbb, or an rgba() string when translucent.
pub fn Rgba::to_css(self : Rgba) -> String {
  if self.alpha == 1.0 {
    "#" + byte_hex(self.red) + byte_hex(self.green) + byte_hex(self.blue)
  } else {
    "rgba(\{Double::to_int(self.red * 255.0)},\{Double::to_int(self.green * 255.0)},\{Double::to_int(self.blue * 255.0)},\{Double::to_string(self.alpha)})"
  }
}

///|
fn make_colormap(name : String, stops : Array[Rgba]) -> ColorMap {
  { name, stops, discrete: false, under: None, over: None, bad: None, }
}

///|
fn make_listed_colormap(name : String, colors : Array[Rgba]) -> ColorMap {
  { name, stops: colors, discrete: true, under: None, over: None, bad: None, }
}

///|
fn stop(hex : String) -> Rgba {
  try! parse_color(hex)
}

///|
fn builtin_colormap(name : String) -> ColorMap? {
  match name {
    "gray" | "grey" =>
      Some(make_colormap("gray", [stop("#000000"), stop("#ffffff")]))
    "viridis" =>
      Some(
        make_colormap("viridis", [
          stop("#440154"),
          stop("#31688e"),
          stop("#35b779"),
          stop("#fde725"),
        ]),
      )
    "plasma" =>
      Some(
        make_colormap("plasma", [
          stop("#0d0887"),
          stop("#7e03a8"),
          stop("#cc4778"),
          stop("#f0f921"),
        ]),
      )
    "inferno" =>
      Some(
        make_colormap("inferno", [
          stop("#000004"),
          stop("#781c6d"),
          stop("#ed6925"),
          stop("#fcffa4"),
        ]),
      )
    "magma" =>
      Some(
        make_colormap("magma", [
          stop("#000004"),
          stop("#721f81"),
          stop("#b73779"),
          stop("#fcfdbf"),
        ]),
      )
    "cividis" =>
      Some(
        make_colormap("cividis", [
          stop("#00204c"),
          stop("#5c7d9a"),
          stop("#b9a66c"),
          stop("#fee838"),
        ]),
      )
    _ => None
  }
}

///|
/// Return a named builtin colormap, if it exists.
pub fn find_colormap(name : String) -> ColorMap? {
  builtin_colormap(name.to_lower())
}

///|
/// Return a named builtin colormap.
pub fn colormap(name : String) -> ColorMap raise ColorError {
  match find_colormap(name) {
    Some(value) => value
    None => raise ColorError::InvalidColorMap(name)
  }
}

///|
/// Construct a named colormap from at least one color stop.
pub fn custom_colormap(
  name : String,
  stops : Array[Rgba],
) -> ColorMap raise ColorError {
  if name == "" || stops.length() == 0 {
    raise ColorError::InvalidColorMap(name)
  }
  make_colormap(name, stops.copy())
}

///|
/// Construct a colormap whose entries are selected without interpolation.
pub fn listed_colormap(
  name : String,
  colors : Array[Rgba],
) -> ColorMap raise ColorError {
  if name == "" || colors.length() == 0 {
    raise ColorError::InvalidColorMap(name)
  }
  make_listed_colormap(name, colors.copy())
}

///|
/// Return the colormap name.
pub fn ColorMap::name(self : ColorMap) -> String {
  self.name
}

///|
/// Return a copy of the interpolation stops.
pub fn ColorMap::stops(self : ColorMap) -> Array[Rgba] {
  self.stops.copy()
}

///|
/// Return whether this colormap selects a discrete entry for each sample.
pub fn ColorMap::is_discrete(self : ColorMap) -> Bool {
  self.discrete
}

///|
/// Set the color used for normalized values below zero.
pub fn ColorMap::set_under(self : ColorMap, color : Rgba) -> Unit {
  self.under = Some(color)
}

///|
/// Set the color used for normalized values above one.
pub fn ColorMap::set_over(self : ColorMap, color : Rgba) -> Unit {
  self.over = Some(color)
}

///|
/// Set the color used for non-finite (masked) values.
pub fn ColorMap::set_bad(self : ColorMap, color : Rgba) -> Unit {
  self.bad = Some(color)
}

///|
/// Return the optional under-range color.
pub fn ColorMap::under(self : ColorMap) -> Rgba? {
  self.under
}

///|
/// Return the optional over-range color.
pub fn ColorMap::over(self : ColorMap) -> Rgba? {
  self.over
}

///|
/// Return the optional color for non-finite values.
pub fn ColorMap::bad(self : ColorMap) -> Rgba? {
  self.bad
}

///|
/// Sample a colormap at a normalized scalar in [0, 1].
pub fn ColorMap::sample(self : ColorMap, value : Double) -> Rgba {
  let normalized = if value.is_nan() || value.is_inf() {
    0.0
  } else {
    Double::clamp(value, min=0.0, max=1.0)
  }
  if self.stops.length() == 1 {
    return self.stops[0]
  }
  if self.discrete {
    let index = Int32::min(
      self.stops.length() - 1,
      (normalized * Double::from_int(self.stops.length())).to_int(),
    )
    return self.stops[index]
  }
  let last = self.stops.length() - 1
  let position = normalized * Double::from_int(last)
  let lower = position.to_int()
  let upper = Int32::min(lower + 1, last)
  let fraction = position - Double::from_int(lower)
  let first_color = self.stops[lower]
  let second_color = self.stops[upper]
  try! rgba(
    first_color.red() + (second_color.red() - first_color.red()) * fraction,
    first_color.green() +
    (second_color.green() - first_color.green()) * fraction,
    first_color.blue() + (second_color.blue() - first_color.blue()) * fraction,
    alpha=first_color.alpha() +
      (second_color.alpha() - first_color.alpha()) * fraction,
  )
}

///|
/// Sample a colormap while honoring configured under, over, and bad colors.
pub fn ColorMap::sample_extended(self : ColorMap, value : Double) -> Rgba {
  if value.is_nan() || value.is_inf() {
    match self.bad {
      Some(color) => color
      None => self.sample(value)
    }
  } else if value < 0.0 {
    match self.under {
      Some(color) => color
      None => self.sample(value)
    }
  } else if value > 1.0 {
    match self.over {
      Some(color) => color
      None => self.sample(value)
    }
  } else {
    self.sample(value)
  }
}
