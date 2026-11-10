///|
fn percent_integer_text(
  value : ScalarNumber,
  code : Char,
  precision : Int32?,
  alternate : Bool,
  positive_sign : Bool,
  available : Int64,
) -> String raise @core.DataError {
  let integer = match value {
    Integer(number) => number
    Boolean(value) => @bigint.BigInt::from_int(if value { 1 } else { 0 })
    NumpyBool(value) => {
      if code == 'o' || code == 'x' || code == 'X' {
        return named_format_error(
          "TypeError",
          "%" +
          code.to_string() +
          " format: an integer is required, not numpy.bool",
        )
      }
      @bigint.BigInt::from_int(if value { 1 } else { 0 })
    }
    NumpyInt64(number) => @bigint.BigInt::from_int64(number)
    Number(number) | NumpyFloat64(number) => {
      if code == 'o' || code == 'x' || code == 'X' {
        return named_format_error(
          "TypeError",
          "%" +
          code.to_string() +
          " format: an integer is required, not " +
          (match value {
            NumpyFloat64(_) => "numpy.float64"
            _ => "float"
          }),
        )
      }
      if number.is_nan() {
        return named_format_error(
          "ValueError", "cannot convert float NaN to integer",
        )
      }
      if number.is_inf() {
        return named_format_error(
          "OverflowError", "cannot convert float infinity to integer",
        )
      }
      let (numerator, denominator) = decimal_ratio(number)
      let integer = numerator / denominator
      if number < 0.0 {
        integer.neg()
      } else {
        integer
      }
    }
  }
  let negative = integer < @bigint.BigInt::from_int(0)
  let magnitude = if negative { integer.neg() } else { integer }
  let radix = if code == 'o' {
    8
  } else if code == 'x' || code == 'X' {
    16
  } else {
    10
  }
  if radix == 10 &&
    magnitude.bit_length() >= 14285 &&
    magnitude >= decimal_power(4300) {
    return named_format_error(
      "ValueError", "Exceeds the limit (4300 digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit",
    )
  }
  let digits = magnitude.to_string(radix~)
  let digits = if code == 'X' { digits.to_upper() } else { digits }
  let prefix = if alternate && code == 'o' {
    "0o"
  } else if alternate && code == 'x' {
    "0x"
  } else if alternate && code == 'X' {
    "0X"
  } else {
    ""
  }
  let count = Int32::max(1, precision.unwrap_or(1))
  let length = Int64::from_int(Int32::max(count, digits.length())) +
    Int64::from_int(prefix.length()) +
    (if negative || positive_sign { 1L } else { 0L })
  if length > available {
    return named_format_error(
      "ResourceError", "percent integer exceeds String addressability",
    )
  }
  (if negative { "-" } else { "" }) + prefix + digits.pad_start(count, '0')
}

///|
fn percent_character_text(value : ScalarNumber) -> String raise @core.DataError {
  let number = match value {
    Integer(number) => {
      if number < @bigint.BigInt::from_int(0) ||
        number >= @bigint.BigInt::from_int(1114112) {
        return named_format_error(
          "OverflowError", "%c arg not in range(0x110000)",
        )
      }
      number.to_int64()
    }
    Boolean(value) => if value { 1L } else { 0L }
    NumpyInt64(number) => number
    _ => return named_format_error("TypeError", "%c requires int or char")
  }
  if number < 0L || number >= 1114112L {
    return named_format_error("OverflowError", "%c arg not in range(0x110000)")
  }
  if number >= 55296L && number <= 57343L {
    return named_format_error(
      "Unsupported", "percent character is an unpaired Unicode surrogate",
    )
  }
  match number.to_int().to_char() {
    Some(character) => character.to_string()
    None =>
      named_format_error(
        "Unsupported", "percent character cannot be represented",
      )
  }
}

///|
fn percent_field_text(
  value : ScalarNumber,
  code : Char,
  precision : Int32?,
  width : Int64,
  left : Bool,
  zero : Bool,
  plus : Bool,
  space : Bool,
  alternate : Bool,
  position : Int32,
  available : Int64,
) -> String raise @core.DataError {
  let numeric = match code {
    'd' | 'i' | 'u' | 'o' | 'x' | 'X' | 'e' | 'E' | 'f' | 'F' | 'g' | 'G' =>
      true
    _ => false
  }
  let mut rendered = match code {
    'd' | 'i' | 'u' | 'o' | 'x' | 'X' =>
      percent_integer_text(
        value,
        code,
        precision,
        alternate,
        plus || space,
        available,
      )
    'e' | 'E' | 'f' | 'F' | 'g' | 'G' => {
      let number = scalar_percent_double(value)
      let positive_sign = (plus || space) &&
        (number.is_nan() || numeric_sign(number) == "")
      named_format_float_digits(
        number,
        code,
        precision,
        alternate,
        available=available - (if positive_sign { 1L } else { 0L }),
      )
    }
    'c' => percent_character_text(value)
    's' | 'r' | 'a' => {
      let text = if code == 's' {
        scalar_percent_str(value)
      } else {
        // Repr for all three scalar kinds is ASCII, so ascii(value) is the same.
        scalar_percent_repr(value)
      }
      match precision {
        Some(count) if count < text.length() => text[:count].to_owned()
        _ => text
      }
    }
    _ =>
      return named_format_error(
        "ValueError",
        "unsupported format character '" +
        (if code.to_int() >= 32 && code.to_int() < 127 {
          code.to_string()
        } else {
          "?"
        }) +
        "' (0x" +
        code.to_int().to_string(radix=16) +
        ") at index " +
        position.to_string(),
      )
  }
  if numeric && !rendered.has_prefix("-") {
    if plus {
      rendered = "+" + rendered
    } else if space {
      rendered = " " + rendered
    }
  }
  if width > available {
    return named_format_error(
      "ResourceError", "percent field exceeds String addressability",
    )
  }
  let count = Int64::from_int(rendered.to_array().length())
  let padding = Int64::max(0L, width - count)
  if Int64::from_int(rendered.length()) + padding > available {
    return named_format_error(
      "ResourceError", "percent field exceeds String addressability",
    )
  }
  if padding == 0L {
    return rendered
  }
  if left {
    return rendered + String::make(padding.to_int(), ' ')
  }
  if zero && numeric {
    let sign = if rendered.has_prefix("-") ||
      rendered.has_prefix("+") ||
      rendered.has_prefix(" ") {
      1
    } else {
      0
    }
    let prefix = sign +
      (if alternate && (code == 'o' || code == 'x' || code == 'X') {
        2
      } else {
        0
      })
    return rendered[:prefix].to_owned() +
      String::make(padding.to_int(), '0') +
      rendered[prefix:].to_owned()
  }
  String::make(padding.to_int(), ' ') + rendered
}

///|
// A scalar is consumed once. Parsing still precedes fetching its conversion
// argument, so malformed later fields can win over missing-argument errors.
fn scalar_percent_format(
  format : String,
  value : ScalarNumber,
  tuple~ : Bool = false,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  let chars = format.to_array()
  let result = StringBuilder()
  let mut index = 0
  let mut consumed = false
  let mut units = 0L
  while index < chars.length() {
    if chars[index] != '%' {
      units += Int64::from_int(chars[index].utf16_len())
      if units > available {
        return named_format_error(
          "ResourceError", "percent result exceeds String addressability",
        )
      }
      result.write_char(chars[index])
      index += 1
      continue
    }
    index += 1
    if index >= chars.length() {
      return named_format_error("ValueError", "incomplete format")
    }
    if chars[index] == '%' {
      units += 1L
      if units > available {
        return named_format_error(
          "ResourceError", "percent result exceeds String addressability",
        )
      }
      result.write_char('%')
      index += 1
      continue
    }
    if chars[index] == '(' {
      if tuple || value is (Number(_) | Integer(_) | Boolean(_)) {
        return named_format_error("TypeError", "format requires a mapping")
      }
      // NumPy scalars expose the mapping slot. Parse the full nested key first,
      // then retain their actual scalar-subscript failure before field parsing.
      let mut nesting = 1
      index += 1
      while index < chars.length() && nesting > 0 {
        if chars[index] == '(' {
          nesting += 1
        } else if chars[index] == ')' {
          nesting -= 1
        }
        index += 1
      }
      if nesting > 0 {
        return named_format_error("ValueError", "incomplete format key")
      }
      return named_format_error(
        "IndexError", "invalid index to scalar variable.",
      )
    }
    let mut left = false
    let mut zero = false
    let mut plus = false
    let mut space = false
    let mut alternate = false
    while index < chars.length() {
      match chars[index] {
        '-' => left = true
        '0' => zero = true
        '+' => plus = true
        ' ' => space = true
        '#' => alternate = true
        _ => break
      }
      index += 1
    }
    let mut width = 0L
    if index < chars.length() && chars[index] == '*' {
      width = scalar_percent_star(value, consumed, false)
      consumed = true
      if width < 0L {
        left = true
        width = 0L - width
      }
      index += 1
    } else {
      while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
        let digit = Int64::from_int(chars[index].to_int() - 48)
        if width > (9223372036854775807L - digit) / 10L {
          return named_format_error("ValueError", "width too big")
        }
        width = width * 10L + digit
        index += 1
      }
    }
    let mut precision : Int32? = None
    if index < chars.length() && chars[index] == '.' {
      index += 1
      if index < chars.length() && chars[index] == '*' {
        let count = scalar_percent_star(value, consumed, true)
        consumed = true
        precision = Some(if count < 0L { 0 } else { count.to_int() })
        index += 1
      } else {
        let mut count = 0
        while index < chars.length() &&
              chars[index] >= '0' &&
              chars[index] <= '9' {
          let digit = chars[index].to_int() - 48
          if count > (2147483647 - digit) / 10 {
            return named_format_error("ValueError", "precision too big")
          }
          count = count * 10 + digit
          index += 1
        }
        precision = Some(count)
      }
    }
    if index < chars.length() &&
      (chars[index] == 'h' || chars[index] == 'l' || chars[index] == 'L') {
      index += 1
    }
    if index >= chars.length() {
      return named_format_error("ValueError", "incomplete format")
    }
    let position = index
    let code = chars[index]
    index += 1
    if consumed {
      return named_format_error(
        "TypeError", "not enough arguments for format string",
      )
    }
    consumed = true
    let field = percent_field_text(
      value,
      code,
      precision,
      width,
      left,
      zero,
      plus,
      space,
      alternate,
      position,
      available - units,
    )
    units += Int64::from_int(field.length())
    if units > available {
      return named_format_error(
        "ResourceError", "percent result exceeds String addressability",
      )
    }
    result.write_string(field)
  }
  if !consumed && (tuple || value is (Number(_) | Integer(_) | Boolean(_))) {
    return named_format_error(
      "TypeError", "not all arguments converted during string formatting",
    )
  }
  result.to_string()
}

///|
// Preserve the D29 entry and its scalar origin without widening NamedFormatValue.
fn format_percent_checked(
  format : String,
  value : NamedFormatValue,
) -> String raise @core.DataError {
  scalar_percent_format(
    format,
    match value {
      PythonFloat(value) => ScalarNumber::Number(value)
      PythonInteger(value) => ScalarNumber::Integer(value)
      NumpyFloat64(value) => ScalarNumber::NumpyFloat64(value)
      NumpyInt64(value) => ScalarNumber::NumpyInt64(value)
    },
  )
}
