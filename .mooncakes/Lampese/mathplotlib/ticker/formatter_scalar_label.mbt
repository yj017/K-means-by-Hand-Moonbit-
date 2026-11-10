///|
/// A backend-neutral subset of mathematical notation: multiplication sign and
/// Unicode superscripts. General TeX/mathtext parsing belongs to the text layer.
fn scalar_power_label(exponent : Int32) -> String {
  let result = StringBuilder()
  result.write_string("10")
  for char in exponent.to_string().to_array() {
    result.write_string(
      match char {
        '-' => "⁻"
        '0' => "⁰"
        '1' => "¹"
        '2' => "²"
        '3' => "³"
        '4' => "⁴"
        '5' => "⁵"
        '6' => "⁶"
        '7' => "⁷"
        '8' => "⁸"
        '9' => "⁹"
        _ => ""
      },
    )
  }
  result.to_string()
}

///|
fn scalar_data_label(value : Double, use_math_text : Bool) -> String {
  if numeric_special(value) is Some(text) {
    return text
  }
  if value == 0.0 {
    return "0"
  }
  let (digits, exponent) = decimal_significant(value, 10)
  let significand = numeric_sign(value) + trim_decimal(decimal_point(digits, 1))
  if exponent == 0 {
    significand
  } else if use_math_text {
    (if significand == "1" { "" } else { significand + "×" }) +
    scalar_power_label(exponent)
  } else {
    significand + "e" + exponent.to_string()
  }
}

///|
fn ScalarLayout::offset_label(
  self : ScalarLayout,
  use_math_text : Bool,
) -> String {
  let multiplier = if self.exponent == 0 {
    ""
  } else if use_math_text {
    "×" + scalar_power_label(self.exponent)
  } else {
    "1e" + self.exponent.to_string()
  }
  let additive = if self.offset == 0.0 {
    ""
  } else {
    (if self.offset > 0.0 { "+" } else { "" }) +
    scalar_data_label(self.offset, use_math_text)
  }
  multiplier + additive
}
