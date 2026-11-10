///|

///|
fn format_log(value : Double, base : Double, label_only_base : Bool) -> String {
  if value.is_nan() {
    return "nan"
  }
  if value.is_inf() {
    return numeric_sign(value) + "inf"
  }
  if value == 0.0 {
    return "0"
  }
  let magnitude = Double::abs(value)
  let exponent = (@math.log10(magnitude) / @math.log10(base)).round().to_int()
  let expected = @math.pow(base, Double::from_int(exponent))
  let is_decade = Double::abs(expected - magnitude) <= magnitude * 1.0e-10
  if label_only_base && !is_decade {
    ""
  } else {
    // LogFormatter keeps the numeric value for decade labels.  Exponent and
    // mathtext representations belong to the specialized formatter variants;
    // label_only_base only suppresses non-decade locations.
    format_general(magnitude, None, false)
  }
}
