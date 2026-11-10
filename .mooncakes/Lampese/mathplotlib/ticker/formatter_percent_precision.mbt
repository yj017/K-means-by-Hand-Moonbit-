///|
// CPython int(str, 10) does NOT accept ASCII U+001C..001F, despite isspace.
fn percent_precision_space(character : Char) -> Bool {
  let code = character.to_int()
  (code >= 9 && code <= 13) ||
  code == 32 ||
  code == 0x85 ||
  code == 0xa0 ||
  code == 0x1680 ||
  (code >= 0x2000 && code <= 0x200a) ||
  code == 0x2028 ||
  code == 0x2029 ||
  code == 0x202f ||
  code == 0x205f ||
  code == 0x3000
}

///|
// PyErr_Format uses %.200R. Bound the repr itself, preserving possible partial
// escape/quote truncation while avoiding a full escaped copy of a large input.
fn percent_precision_repr(value : String) -> String {
  let quote = if value.contains("'") && !value.contains("\"") {
    '"'
  } else {
    '\''
  }
  let result = StringBuilder()
  result.write_char(quote)
  let mut length = 1
  for character in value {
    if length == 200 {
      break
    }
    let code = character.to_int()
    let piece = if character == quote || character == '\\' {
      "\\" + character.to_string()
    } else if character == '\n' {
      "\\n"
    } else if character == '\r' {
      "\\r"
    } else if character == '\t' {
      "\\t"
    } else if !named_format_python_printable(character) {
      let (prefix, width) = if code <= 255 {
        ("\\x", 2)
      } else if code <= 65535 {
        ("\\u", 4)
      } else {
        ("\\U", 8)
      }
      prefix +
      code.reinterpret_as_uint().to_string(radix=16).pad_start(width, '0')
    } else {
      character.to_string()
    }
    for output in piece {
      if length == 200 {
        break
      }
      result.write_char(output)
      length += 1
    }
  }
  if length < 200 {
    result.write_char(quote)
  }
  result.to_string()
}

///|
fn percent_invalid_precision_text(
  value : String,
) -> @bigint.BigInt raise @core.DataError {
  raise @core.DataError::InvalidTicks(
    message="ValueError: invalid literal for int() with base 10: " +
      percent_precision_repr(value),
  )
}

///|
fn percent_precision_text_integer(
  value : String,
) -> @bigint.BigInt raise @core.DataError {
  let chars = value.to_array()
  let mut first = 0
  let mut last = chars.length()
  while first < last && percent_precision_space(chars[first]) {
    first += 1
  }
  while last > first && percent_precision_space(chars[last - 1]) {
    last -= 1
  }
  let negative = first < last && chars[first] == '-'
  if first < last && (chars[first] == '+' || chars[first] == '-') {
    first += 1
  }
  let start = first
  let mut count = 0
  let mut previous_digit = false
  while first < last {
    if method_decimal_digit(chars[first]) is Some(_) {
      count += 1
      previous_digit = true
    } else if chars[first] == '_' && previous_digit {
      previous_digit = false
    } else {
      return percent_invalid_precision_text(value)
    }
    first += 1
  }
  if !previous_digit {
    return percent_invalid_precision_text(value)
  }
  // Syntax errors win over the decimal digit limit, including a trailing '_'.
  if count > 4300 {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Exceeds the limit (4300 digits) for integer string conversion: value has " +
        count.to_string() +
        " digits; use sys.set_int_max_str_digits() to increase the limit",
    )
  }
  let mut integer = @bigint.BigInt::from_int(0)
  let ten = @bigint.BigInt::from_int(10)
  for index in start..<last {
    if method_decimal_digit(chars[index]) is Some(digit) {
      integer = integer * ten + @bigint.BigInt::from_int(digit)
    }
  }
  if negative {
    integer.neg()
  } else {
    integer
  }
}

///|
fn percent_precision_integer(
  value : PercentDecimals,
) -> @bigint.BigInt raise @core.DataError {
  match value {
    Automatic => @bigint.BigInt::from_int(0)
    Integer(integer) => integer
    Boolean(boolean) => @bigint.BigInt::from_int(if boolean { 1 } else { 0 })
    Text(text) => percent_precision_text_integer(text)
    Number(number) => {
      if number.is_nan() {
        raise @core.DataError::InvalidTicks(
          message="ValueError: cannot convert float NaN to integer",
        )
      }
      if number.is_inf() {
        raise @core.DataError::InvalidTicks(
          message="OverflowError: cannot convert float infinity to integer",
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
}

///|
fn percent_explicit_decimals(
  value : PercentDecimals,
) -> Int32 raise @core.DataError {
  let integer = percent_precision_integer(value)
  let magnitude = if integer < @bigint.BigInt::from_int(0) {
    integer.neg()
  } else {
    integer
  }
  // The dynamic f-string stringifies int(decimals) before parsing precision.
  // Only unusually large integers need the exact decimal-string limit check.
  if magnitude.bit_length() >= 14285 && magnitude >= decimal_power(4300) {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Exceeds the limit (4300 digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit",
    )
  }
  if integer < @bigint.BigInt::from_int(0) {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Format specifier missing precision",
    )
  }
  if integer > @bigint.BigInt::from_int64(9223372036854775807L) {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Too many decimal digits in format string",
    )
  }
  if integer > @bigint.BigInt::from_int(2147483647) {
    raise @core.DataError::InvalidTicks(message="ValueError: precision too big")
  }
  integer.to_int()
}
