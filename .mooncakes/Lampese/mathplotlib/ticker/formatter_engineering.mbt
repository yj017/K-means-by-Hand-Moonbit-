///|
fn format_engineering(
  value : Double,
  unit : String,
  places : Int32,
  sep : String,
) -> String {
  if numeric_special(value) is Some(text) {
    return if unit == "" { text } else { text + sep + unit }
  }
  let magnitude = Double::abs(value)
  let mut exponent = if magnitude == 0.0 {
    0
  } else {
    // MoonBit integer division truncates toward zero.  Engineering notation
    // needs mathematical floor so values between 0 and 1 use milli/micro
    // prefixes instead of the empty prefix.
    let decade = decimal_exponent(magnitude)
    (decade.to_double() / 3.0).floor().to_int() * 3
  }
  if exponent < -30 {
    exponent = -30
  }
  if exponent > 30 {
    exponent = 30
  }
  let mut mantissa = if magnitude == 0.0 {
    0.0
  } else {
    let scaled = magnitude / @math.pow(10.0, Double::from_int(exponent))
    if value < 0.0 {
      -scaled
    } else {
      scaled
    }
  }
  let precision = if places < 0 { None } else { Some(places) }
  let mut rendered = match precision {
    Some(digits) => format_fixed(mantissa, digits)
    None => format_general(mantissa, None, false)
  }
  // Promote only when the selected precision actually rounds the mantissa to
  // 1000.  A fixed two-place formatter must keep 999.90 k, while a default
  // six-significant-digit formatter promotes 999.9999 to 1 k.
  let rounded_magnitude = Double::abs(try! @string.parse_double(rendered[:]))
  if rounded_magnitude >= 1000.0 && exponent < 30 {
    exponent += 3
    mantissa /= 1000.0
    rendered = match precision {
      Some(digits) => format_fixed(mantissa, digits)
      None => format_general(mantissa, None, false)
    }
  }
  let prefix = engineering_prefix(exponent)
  if prefix == "" && unit == "" {
    rendered
  } else {
    rendered + sep + prefix + unit
  }
}

///|
fn engineering_prefix(exponent : Int32) -> String {
  match exponent {
    -30 => "q"
    -27 => "r"
    -24 => "y"
    -21 => "z"
    -18 => "a"
    -15 => "f"
    -12 => "p"
    -9 => "n"
    -6 => "µ"
    -3 => "m"
    0 => ""
    3 => "k"
    6 => "M"
    9 => "G"
    12 => "T"
    15 => "P"
    18 => "E"
    21 => "Z"
    24 => "Y"
    27 => "R"
    30 => "Q"
    _ => ""
  }
}
