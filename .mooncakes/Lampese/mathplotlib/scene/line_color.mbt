///|
// The pinned map is entirely ASCII. Python Unicode lower() can produce an
// ASCII name only from ASCII letters and U+212A KELVIN SIGN; all other Unicode
// lowercase results still contain non-ASCII and cannot match that fixed map.
// Keep this projection local: core String.to_lower only changes ASCII letters.
fn line_color_name_lower(value : String) -> String {
  let result = StringBuilder()
  for character in value.to_array() {
    if character >= 'A' && character <= 'Z' {
      result.write_char((character.to_int() + 32).unsafe_to_char())
    } else if character == '\u{212a}' {
      result.write_char('k')
    } else {
      result.write_char(character)
    }
  }
  result.to_string()
}

///|
fn line_color_is_cycle(value : String) -> Bool {
  let characters = value.to_array()
  if characters.length() < 2 || characters[0] != 'C' {
    return false
  }
  for index in 1..<characters.length() {
    if characters[index] < '0' || characters[index] > '9' {
      return false
    }
  }
  true
}

///|
fn line_color_hex_digit(character : Char) -> Int32? {
  if character >= '0' && character <= '9' {
    Some(character.to_int() - 48)
  } else if character >= 'a' && character <= 'f' {
    Some(character.to_int() - 87)
  } else if character >= 'A' && character <= 'F' {
    Some(character.to_int() - 55)
  } else {
    None
  }
}

///|
// Native color cache history is deliberately not copied. Equal signed-zero
// cache keys can retain an older alpha sign; this portable helper uses the
// current override sign and keeps the raw Artist setter's separate no-op rule.
fn line_color_override_alpha(
  color : @colors.Rgba,
  alpha : Double?,
) -> @colors.Rgba {
  match alpha {
    None => color
    Some(alpha) =>
      try! @colors.rgba(color.red(), color.green(), color.blue(), alpha~)
  }
}

///|
// This is the source no-colorcycle path. A selected cycle entry must not be
// interpreted as another cycle token. Error text belongs to this primitive,
// whereas validation wraps these ValueErrors with _check_color_like's message.
fn line_color_rgba_no_cycle(
  value : String,
  alpha~ : Double? = None,
) -> @colors.Rgba raise @core.DataError {
  if alpha is Some(value) && !(value >= 0.0 && value <= 1.0) {
    raise @core.DataError::InvalidTicks(
      message="ValueError: 'alpha' must be between 0 and 1, inclusive",
    )
  }
  let lower = line_color_name_lower(value)
  if lower == "none" {
    return try! @colors.rgba(0.0, 0.0, 0.0, alpha=0.0)
  }
  match line_color_named(value) {
    Some(color) => return line_color_override_alpha(color, alpha)
    None => ()
  }
  let characters = value.to_array()
  if characters.length() != 1 {
    match line_color_named(lower) {
      Some(color) => return line_color_override_alpha(color, alpha)
      None => ()
    }
  }
  if characters.length() > 1 && characters[0] == '#' {
    let digits : Array[Int32] = []
    let mut all_hex = true
    for index in 1..<characters.length() {
      match line_color_hex_digit(characters[index]) {
        Some(digit) => digits.push(digit)
        None => {
          all_hex = false
          break
        }
      }
    }
    if all_hex {
      let (red, green, blue, embedded_alpha) = match digits.length() {
        3 =>
          (
            digits[0].to_double() / 15.0,
            digits[1].to_double() / 15.0,
            digits[2].to_double() / 15.0,
            1.0,
          )
        4 =>
          (
            digits[0].to_double() / 15.0,
            digits[1].to_double() / 15.0,
            digits[2].to_double() / 15.0,
            digits[3].to_double() / 15.0,
          )
        6 =>
          (
            (digits[0] * 16 + digits[1]).to_double() / 255.0,
            (digits[2] * 16 + digits[3]).to_double() / 255.0,
            (digits[4] * 16 + digits[5]).to_double() / 255.0,
            1.0,
          )
        8 =>
          (
            (digits[0] * 16 + digits[1]).to_double() / 255.0,
            (digits[2] * 16 + digits[3]).to_double() / 255.0,
            (digits[4] * 16 + digits[5]).to_double() / 255.0,
            (digits[6] * 16 + digits[7]).to_double() / 255.0,
          )
        _ =>
          raise @core.DataError::InvalidTicks(
            message="ValueError: Invalid hex color specifier: " +
              @ticker.python_string_repr(value),
          )
      }
      return try! @colors.rgba(
        red,
        green,
        blue,
        alpha=alpha.unwrap_or(embedded_alpha),
      )
    }
  }
  let gray = @ticker.parse_float_text(value) catch {
    @core.DataError::InvalidTicks(..) =>
      raise @core.DataError::InvalidTicks(
        message="ValueError: Invalid RGBA argument: " +
          @ticker.python_string_repr(value),
      )
    error => raise error
  }
  if !(gray >= 0.0 && gray <= 1.0) {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Invalid string grayscale value " +
        @ticker.python_string_repr(value) +
        ". Value must be within 0-1 range",
    )
  }
  try! @colors.rgba(gray, gray, gray, alpha=alpha.unwrap_or(1.0))
}

///|
fn line_color_validate(value : String) -> Unit raise @core.DataError {
  // is_color_like accepts the complete ASCII cycle syntax before rc lookup or
  // Python int conversion. The 4300-digit bound is therefore deliberately late.
  if line_color_is_cycle(value) {
    return
  }
  ignore(line_color_rgba_no_cycle(value)) catch {
    @core.DataError::InvalidTicks(..) =>
      raise @core.DataError::InvalidTicks(
        message="ValueError: " +
          @ticker.python_string_repr(value) +
          " is not a valid value for color: supported inputs are " +
          "(r, g, b) and (r, g, b, a) 0-1 float tuples; " +
          "'#rrggbb', '#rrggbbaa', '#rgb', '#rgba' strings; " +
          "named color strings; string reprs of 0-1 floats for grayscale values; " +
          "'C0', 'C1', ... strings for colors of the color cycle; " +
          "and pairs combining one of the above with an alpha value",
      )
    error => raise error
  }
}

///|
fn line_color_rgba(
  value : String,
  alpha~ : Double? = None,
) -> @colors.Rgba raise @core.DataError {
  if !line_color_is_cycle(value) {
    return line_color_rgba_no_cycle(value, alpha~)
  }
  let cycle = @config.color_cycle()
  let digits = value.to_array()
  let count = digits.length() - 1
  if count > 4300 {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Exceeds the limit (4300 digits) for integer string conversion: value has " +
        count.to_string() +
        " digits; use sys.set_int_max_str_digits() to increase the limit",
    )
  }
  // Config guarantees a nonempty cycle. Int64 keeps multiply-add safe even
  // when an Array has the largest representable Int32 length.
  let modulus = cycle.length().to_int64()
  let mut index = 0L
  for offset in 1..<digits.length() {
    index = (index * 10L + (digits[offset].to_int() - 48).to_int64()) % modulus
  }
  line_color_rgba_no_cycle(cycle[index.to_int()], alpha~)
}
