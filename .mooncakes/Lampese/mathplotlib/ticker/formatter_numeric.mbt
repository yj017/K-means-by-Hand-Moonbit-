///|
/// Extract the exact non-negative rational value of a finite binary64.
/// Decimal rounding uses integers so it is identical on Wasm, JS, and native,
/// including halfway cases, subnormal values, and numbers above Int64's range.
fn decimal_ratio(value : Double) -> (@bigint.BigInt, @bigint.BigInt) {
  // The ratio is only used with an absolute value.  Clear the sign bit here
  // as well as at the call sites so negative values follow the same exact
  // rounding path as positive values.
  let bits = value.reinterpret_as_uint64() & 0x7fffffffffffffffUL
  let biased = ((bits >> 52) & 0x7ffUL).to_int()
  let fraction = bits & 0xfffffffffffffUL
  let significand = if biased == 0 {
    fraction
  } else {
    fraction | 0x10000000000000UL
  }
  let exponent = if biased == 0 { -1074 } else { biased - 1075 }
  let numerator = @bigint.BigInt::from_uint64(significand)
  let one = @bigint.BigInt::from_int(1)
  if exponent >= 0 {
    (numerator << exponent, one)
  } else {
    (numerator, one << -exponent)
  }
}

///|
fn decimal_power(exponent : Int32) -> @bigint.BigInt {
  @bigint.BigInt::from_int(10).pow(@bigint.BigInt::from_int(exponent))
}

///|
/// Round abs(value) * 10^places to nearest, with halfway cases going to even.
fn decimal_round(value : Double, places : Int32) -> @bigint.BigInt {
  let (n, d) = decimal_ratio(value)
  let numerator = if places >= 0 { n * decimal_power(places) } else { n }
  let denominator = if places < 0 { d * decimal_power(-places) } else { d }
  let quotient = numerator / denominator
  let two = @bigint.BigInt::from_int(2)
  let remainder = numerator % denominator * two
  if remainder > denominator ||
    (remainder == denominator && !(quotient % two).is_zero()) {
    quotient + @bigint.BigInt::from_int(1)
  } else {
    quotient
  }
}

///|
fn numeric_sign(value : Double) -> String {
  if value.reinterpret_as_uint64() >> 63 != 0UL {
    "-"
  } else {
    ""
  }
}

///|
fn numeric_special(value : Double) -> String? {
  if value.is_nan() {
    Some("nan")
  } else if value.is_inf() {
    Some(numeric_sign(value) + "inf")
  } else {
    None
  }
}

///|
/// Locate the exact decimal order; log10 is only an initial approximation.
fn decimal_exponent(value : Double) -> Int32 {
  if value == 0.0 {
    return 0
  }
  let (n, d) = decimal_ratio(value)
  let mut exponent = @math.log10(Double::abs(value)).floor().to_int()
  while decimal_compare_power(n, d, exponent) < 0 {
    exponent -= 1
  }
  while decimal_compare_power(n, d, exponent + 1) >= 0 {
    exponent += 1
  }
  exponent
}

///|
fn decimal_compare_power(
  numerator : @bigint.BigInt,
  denominator : @bigint.BigInt,
  exponent : Int32,
) -> Int32 {
  if exponent >= 0 {
    numerator.compare(denominator * decimal_power(exponent))
  } else {
    (numerator * decimal_power(-exponent)).compare(denominator)
  }
}

///|
/// Rounded significant digits and the resulting decimal exponent.
fn decimal_significant(value : Double, digits : Int32) -> (String, Int32) {
  if value == 0.0 {
    return (String::make(digits, '0'), 0)
  }
  let mut exponent = decimal_exponent(value)
  let rounded = decimal_round(value, digits - 1 - exponent).to_string()
  if rounded.length() > digits {
    exponent += 1
    (rounded[:digits].to_owned(), exponent)
  } else {
    (rounded.pad_start(digits, '0'), exponent)
  }
}

///|
fn decimal_point(digits : String, position : Int32) -> String {
  if position <= 0 {
    "0." + String::make(-position, '0') + digits
  } else if position >= digits.length() {
    digits + String::make(position - digits.length(), '0')
  } else {
    digits[:position].to_owned() + "." + digits[position:].to_owned()
  }
}

///|
fn decimal_exponent_suffix(exponent : Int32) -> String {
  "e" +
  (if exponent >= 0 { "+" } else { "-" }) +
  Int32::abs(exponent).to_string().pad_start(2, '0')
}

///|
fn format_fixed(value : Double, precision : Int32) -> String {
  if numeric_special(value) is Some(text) {
    return text
  }
  let places = Int32::max(0, Int32::min(100, precision))
  let digits = decimal_round(value, places)
    .to_string()
    .pad_start(places + 1, '0')
  numeric_sign(value) + decimal_point(digits, digits.length() - places)
}

///|
fn format_integer(value : Double) -> String {
  if numeric_special(value) is Some(text) {
    return text
  }
  let (numerator, denominator) = decimal_ratio(value)
  let truncated = numerator / denominator
  (if truncated.is_zero() { "" } else { numeric_sign(value) }) +
  truncated.to_string()
}

///|
fn format_scientific(value : Double, precision : Int32) -> String {
  if numeric_special(value) is Some(text) {
    return text
  }
  let places = Int32::max(0, Int32::min(100, precision))
  let (digits, exponent) = decimal_significant(value, places + 1)
  numeric_sign(value) +
  decimal_point(digits, 1) +
  decimal_exponent_suffix(exponent)
}

///|
fn format_general(
  value : Double,
  precision : Int32?,
  alternate : Bool,
) -> String {
  if numeric_special(value) is Some(text) {
    return text
  }
  let count = Int32::max(1, Int32::min(100, precision.unwrap_or(6)))
  let (digits, exponent) = decimal_significant(value, count)
  let scientific = exponent < -4 || exponent >= count
  let mantissa = decimal_point(
    digits,
    if scientific {
      1
    } else {
      exponent + 1
    },
  )
  let rendered = if alternate {
    if mantissa.contains(".") {
      mantissa
    } else {
      mantissa + "."
    }
  } else {
    trim_decimal(mantissa)
  }
  numeric_sign(value) +
  rendered +
  (if scientific { decimal_exponent_suffix(exponent) } else { "" })
}

///|
/// Remove fractional trailing zeros, preserving the integer part and exponent.
fn trim_decimal(value : String) -> String {
  let exponent_start = value.find("e").unwrap_or(value.length())
  match value.find(".") {
    Some(dot) if dot < exponent_start => {
      let mut end = exponent_start
      while end > dot + 1 && value[end - 1] == 48 {
        end -= 1
      }
      if end == dot + 1 {
        end = dot
      }
      value[:end].to_owned() + value[exponent_start:].to_owned()
    }
    _ => value
  }
}
