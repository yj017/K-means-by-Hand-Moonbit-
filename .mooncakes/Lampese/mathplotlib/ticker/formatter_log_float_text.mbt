///|
/// Parse a numeric string with the shared Python float-text semantics.
pub fn parse_float_text(value : String) -> Double raise @core.DataError {
  log_text_float(value)
}

///|
// Python float(str) shares decimal digits and outer whitespace with the
// existing int-text consumer, but has no integer digit limit or repr truncation.
fn log_text_float(value : String) -> Double raise @core.DataError {
  let characters = value.to_array()
  let mut first = 0
  let mut last = characters.length()
  while first < last && percent_precision_space(characters[first]) {
    first += 1
  }
  while last > first && percent_precision_space(characters[last - 1]) {
    last -= 1
  }
  let negative = first < last && characters[first] == '-'
  let normalized = StringBuilder()
  for index in first..<last {
    match method_decimal_digit(characters[index]) {
      Some(digit) => normalized.write_string(digit.to_string())
      None => normalized.write_char(characters[index])
    }
  }
  let text = normalized.to_string()
  let number = @string.parse_double(text[:]) catch {
    Failure::Failure("value out of range") =>
      if negative {
        -1.0 / 0.0
      } else {
        1.0 / 0.0
      }
    _ =>
      raise @core.DataError::InvalidTicks(
        message="ValueError: could not convert string to float: " +
          method_quote(value),
      )
  }
  // The core parser intentionally canonicalizes NaN without its textual sign.
  // The original float constructor preserves that sign, as well as signed zero.
  if number.is_nan() {
    if negative {
      0xfff8000000000000UL.reinterpret_as_double()
    } else {
      0x7ff8000000000000UL.reinterpret_as_double()
    }
  } else if number == 0.0 && negative {
    -0.0
  } else {
    number
  }
}
