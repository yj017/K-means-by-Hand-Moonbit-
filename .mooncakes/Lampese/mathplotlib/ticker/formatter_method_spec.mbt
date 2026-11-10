///|
priv struct MethodFormatSpec {
  fill : Char
  align : Char
  sign : Char?
  negative_zero : Bool
  alternate : Bool
  width : Int64
  grouping : Char?
  precision : Int64?
  code : Char
  explicit_code : Bool
}

///|
// CPython's internal format errors use an unpadded hexadecimal escape outside
// ASCII 32..127; this is distinct from both repr() and Unicode printability.
fn method_code_description(code : Char) -> String {
  let scalar = code.to_int()
  if scalar >= 32 && scalar <= 127 {
    String::from_array([code])
  } else {
    "\\x" + scalar.reinterpret_as_uint().to_string(radix=16)
  }
}

///|
fn method_is_alignment(character : Char) -> Bool {
  character == '<' || character == '>' || character == '^' || character == '='
}

///|
fn method_spec_error(
  spec : String,
  name : String,
) -> String raise @core.DataError {
  named_format_error(
    "ValueError",
    "Invalid format specifier '" +
    spec +
    "'" +
    " for object of type '" +
    name +
    "'",
  )
}

///|
fn method_parse_spec(
  spec : String,
  name : String,
  text~ : Bool = false,
) -> MethodFormatSpec raise @core.DataError {
  let chars = spec.to_array()
  let mut index = 0
  let mut fill = ' '
  let mut align = if text { '<' } else { '>' }
  let mut explicit_fill = false
  let mut explicit_align = false
  if chars.length() >= 2 && method_is_alignment(chars[1]) {
    fill = chars[0]
    align = chars[1]
    explicit_fill = true
    explicit_align = true
    index = 2
  } else if chars.length() > 0 && method_is_alignment(chars[0]) {
    align = chars[0]
    explicit_align = true
    index = 1
  }
  let sign = if index < chars.length() &&
    (chars[index] == '+' || chars[index] == '-' || chars[index] == ' ') {
    let sign = chars[index]
    index += 1
    Some(sign)
  } else {
    None
  }
  let negative_zero = index < chars.length() && chars[index] == 'z'
  if negative_zero {
    index += 1
  }
  let alternate = index < chars.length() && chars[index] == '#'
  if alternate {
    index += 1
  }
  if index < chars.length() && chars[index] == '0' {
    if !explicit_fill {
      fill = '0'
    }
    if !explicit_align && !text {
      align = '='
    }
    index += 1
  }
  let start = index
  while index < chars.length() && method_decimal_digit(chars[index]) is Some(_) {
    index += 1
  }
  let width = method_decimal_token(chars[start:index].to_owned()).unwrap_or(0L)
  let grouping = if index < chars.length() &&
    (chars[index] == ',' || chars[index] == '_') {
    let grouping = chars[index]
    index += 1
    if index < chars.length() &&
      (
        (chars[index] == ',' && grouping == '_') ||
        (chars[index] == '_' && grouping == ',')
      ) {
      ignore(
        named_format_error("ValueError", "Cannot specify both ',' and '_'."),
      )
    }
    Some(grouping)
  } else {
    None
  }
  let precision = if index < chars.length() && chars[index] == '.' {
    index += 1
    let start = index
    while index < chars.length() &&
          method_decimal_digit(chars[index]) is Some(_) {
      index += 1
    }
    if start == index {
      ignore(
        named_format_error("ValueError", "Format specifier missing precision"),
      )
    }
    method_decimal_token(chars[start:index].to_owned())
  } else {
    None
  }
  let explicit_code = index < chars.length()
  let code = if explicit_code {
    let code = chars[index]
    index += 1
    code
  } else {
    '\u0000'
  }
  if index != chars.length() {
    ignore(method_spec_error(spec, name))
  }
  if grouping is Some(separator) {
    let decimal_code = code == '\u0000' ||
      code == 'd' ||
      code == 'e' ||
      code == 'E' ||
      code == 'f' ||
      code == 'F' ||
      code == 'g' ||
      code == 'G' ||
      code == '%'
    let radix_code = code == 'b' || code == 'o' || code == 'x' || code == 'X'
    if !decimal_code && !(separator == '_' && radix_code) {
      ignore(
        named_format_error(
          "ValueError",
          "Cannot specify '" +
          String::from_array([separator]) +
          "' with '" +
          method_code_description(code) +
          "'.",
        ),
      )
    }
  }
  {
    fill,
    align,
    sign,
    negative_zero,
    alternate,
    width,
    grouping,
    precision,
    code,
    explicit_code,
  }
}

///|
fn method_repeat(fill : Char, count : Int64) -> String raise @core.DataError {
  let units = if fill.to_int() > 65535 { 2L } else { 1L }
  if count > 2147483647L / units {
    return named_format_error(
      "ResourceError", "formatted text exceeds String addressability",
    )
  }
  String::make(count.to_int(), fill)
}

///|
fn method_pad(
  body : String,
  prefix : String,
  spec : MethodFormatSpec,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  let body_units = Int64::from_int(body.length()) +
    Int64::from_int(prefix.length())
  if body_units > available {
    return named_format_error(
      "ResourceError", "formatted text exceeds String addressability",
    )
  }
  let length = Int64::from_int(body.to_array().length()) +
    Int64::from_int(prefix.to_array().length())
  let padding = spec.width - length
  if padding <= 0 {
    return prefix + body
  }
  let units = if spec.fill.to_int() > 65535 { 2L } else { 1L }
  if padding >
    (
      available -
      Int64::from_int(body.length()) -
      Int64::from_int(prefix.length())
    ) /
    units {
    return named_format_error(
      "ResourceError", "formatted text exceeds String addressability",
    )
  }
  match spec.align {
    '<' => prefix + body + method_repeat(spec.fill, padding)
    '^' =>
      method_repeat(spec.fill, padding / 2L) +
      prefix +
      body +
      method_repeat(spec.fill, padding - padding / 2L)
    '=' => prefix + method_repeat(spec.fill, padding) + body
    _ => method_repeat(spec.fill, padding) + prefix + body
  }
}

///|
fn method_group_digits(
  digits : String,
  separator : Char,
  size : Int32,
) -> String {
  let chars = digits.to_array()
  let result = StringBuilder()
  for index in 0..<chars.length() {
    if index > 0 && (chars.length() - index) % size == 0 {
      result.write_char(separator)
    }
    result.write_char(chars[index])
  }
  result.to_string()
}

///|
fn method_group_number(
  body : String,
  prefix : String,
  spec : MethodFormatSpec,
  size : Int32,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  if spec.width > available {
    return named_format_error(
      "ResourceError", "formatted text exceeds String addressability",
    )
  }
  guard spec.grouping is Some(separator) else {
    return method_pad(body, prefix, spec, available~)
  }
  let chars = body.to_array()
  let mut integer_length = 0
  while integer_length < chars.length() &&
        (
          (chars[integer_length] >= '0' && chars[integer_length] <= '9') ||
          (
            size == 4 &&
            (
              (chars[integer_length] >= 'a' && chars[integer_length] <= 'f') ||
              (chars[integer_length] >= 'A' && chars[integer_length] <= 'F')
            )
          )
        ) {
    integer_length += 1
  }
  if integer_length == 0 {
    return method_pad(body, prefix, spec, available~)
  }
  let digits = String::from_array(chars[:integer_length])
  let suffix = String::from_array(chars[integer_length:])
  let digits = if spec.align == '=' && spec.fill == '0' {
    let other = Int64::from_int(prefix.length()) +
      Int64::from_int(suffix.length())
    let mut lower = Int64::from_int(integer_length)
    let mut upper = Int64::max(lower, spec.width)
    while lower < upper {
      let middle = lower + (upper - lower) / 2L
      let length = other + middle + (middle - 1L) / Int64::from_int(size)
      if length < spec.width {
        lower = middle + 1L
      } else {
        upper = middle
      }
    }
    let required = other + lower + (lower - 1L) / Int64::from_int(size)
    if required > available {
      return named_format_error(
        "ResourceError", "formatted text exceeds String addressability",
      )
    }
    method_repeat('0', lower - Int64::from_int(integer_length)) + digits
  } else {
    let required = Int64::from_int(prefix.length()) +
      Int64::from_int(suffix.length()) +
      Int64::from_int(integer_length) +
      Int64::from_int((integer_length - 1) / size)
    if required > available {
      return named_format_error(
        "ResourceError", "formatted text exceeds String addressability",
      )
    }
    digits
  }
  method_pad(
    method_group_digits(digits, separator, size) + suffix,
    prefix,
    spec,
    available~,
  )
}

///|
fn method_numeric_prefix(negative : Bool, sign : Char?) -> String {
  if negative {
    "-"
  } else if sign is Some('+') {
    "+"
  } else if sign is Some(' ') {
    " "
  } else {
    ""
  }
}

///|
fn method_format_float(
  value : Double,
  spec : MethodFormatSpec,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  let code = spec.code
  if code != '\u0000' &&
    code != 'e' &&
    code != 'E' &&
    code != 'f' &&
    code != 'F' &&
    code != 'g' &&
    code != 'G' &&
    code != 'n' &&
    code != '%' {
    return named_format_error(
      "ValueError",
      "Unknown format code '" +
      method_code_description(code) +
      "' for object of type 'float'",
    )
  }
  if code == 'n' && spec.grouping is Some(separator) {
    return named_format_error(
      "ValueError",
      "Cannot specify '" + String::from_array([separator]) + "' with 'n'.",
    )
  }
  let precision = match spec.precision {
    Some(precision) => {
      if precision > 2147483647L {
        return named_format_error("ValueError", "precision too big")
      }
      Some(precision.to_int())
    }
    None => None
  }
  let magnitude = Double::abs(value)
  let scaled = if code == '%' { magnitude * 100.0 } else { magnitude }
  let mut negative = !value.is_nan() && numeric_sign(value) == "-"
  if spec.negative_zero && negative {
    let fixed = code == 'f' || code == 'F' || code == '%'
    let places = precision.unwrap_or(6)
    let rounds_zero = scaled == 0.0 ||
      (
        fixed &&
        !scaled.is_inf() &&
        places < 1075 &&
        decimal_round(scaled, places).is_zero()
      )
    if rounds_zero {
      negative = false
    }
  }
  let prefix = method_numeric_prefix(negative, spec.sign)
  if spec.width > available {
    return named_format_error(
      "ResourceError", "formatted text exceeds String addressability",
    )
  }
  // Large fixed/alternate precision has an exact exponent. Reserve separators
  // before asking the numeric kernel to allocate its ungrouped decimal body.
  let grouping_units = if spec.grouping is Some(_) &&
    precision.unwrap_or(0) >= 1075 &&
    !scaled.is_inf() &&
    !scaled.is_nan() {
    let exponent = decimal_exponent(scaled)
    let fixed = code == 'f' || code == 'F' || code == '%'
    let integer_digits = if fixed ||
      (code != 'e' && code != 'E' && exponent >= -4) {
      Int32::max(1, exponent + 1)
    } else {
      1
    }
    Int64::from_int((integer_digits - 1) / 3)
  } else {
    0L
  }
  let body = named_format_float_digits(
    magnitude,
    code,
    precision,
    spec.alternate,
    available=available - Int64::from_int(prefix.length()) - grouping_units,
  )
  method_group_number(body, prefix, spec, 3, available~)
}

///|
fn method_format_integer(
  value : @bigint.BigInt,
  spec : MethodFormatSpec,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  let code = spec.code
  if code == 'e' ||
    code == 'E' ||
    code == 'f' ||
    code == 'F' ||
    code == 'g' ||
    code == 'G' ||
    code == '%' {
    return method_format_float(
      percent_python_integer_double(value),
      spec,
      available~,
    )
  }
  if (code != '\u0000' || spec.explicit_code) &&
    code != 'b' &&
    code != 'c' &&
    code != 'd' &&
    code != 'o' &&
    code != 'x' &&
    code != 'X' &&
    code != 'n' {
    return named_format_error(
      "ValueError",
      "Unknown format code '" +
      method_code_description(code) +
      "' for object of type 'int'",
    )
  }
  if spec.precision is Some(_) {
    return named_format_error(
      "ValueError", "Precision not allowed in integer format specifier",
    )
  }
  if spec.negative_zero {
    return named_format_error(
      "ValueError", "Negative zero coercion (z) not allowed in integer format specifier",
    )
  }
  if spec.grouping is Some(separator) &&
    (
      code == 'c' ||
      code == 'n' ||
      (separator == ',' && code != '\u0000' && code != 'd')
    ) {
    return named_format_error(
      "ValueError",
      "Cannot specify '" +
      String::from_array([separator]) +
      "' with '" +
      method_code_description(code) +
      "'.",
    )
  }
  if code == 'c' {
    if spec.sign is Some(_) {
      return named_format_error(
        "ValueError", "Sign not allowed with integer format specifier 'c'",
      )
    }
    if spec.alternate {
      return named_format_error(
        "ValueError", "Alternate form (#) not allowed with integer format specifier 'c'",
      )
    }
    if value < @bigint.BigInt::from_int(0) ||
      value > @bigint.BigInt::from_int(1114111) {
      return named_format_error(
        "OverflowError", "%c arg not in range(0x110000)",
      )
    }
    if value >= @bigint.BigInt::from_int(55296) &&
      value <= @bigint.BigInt::from_int(57343) {
      return named_format_error(
        "Unsupported", "unpaired surrogate output cannot be represented portably",
      )
    }
    return method_pad(
      String::from_array([value.to_int().unsafe_to_char()]),
      "",
      spec,
      available~,
    )
  }
  let negative = value < @bigint.BigInt::from_int(0)
  let magnitude = if negative { value.neg() } else { value }
  let radix = if code == 'b' {
    2
  } else if code == 'o' {
    8
  } else if code == 'x' || code == 'X' {
    16
  } else {
    10
  }
  if radix == 10 {
    // Apply the pinned Python decimal conversion limit at the selected field,
    // after parsing and all earlier format-field errors, rather than at input.
    ignore(scalar_percent_integer_str(value))
  }
  let digits = magnitude.to_string(radix~)
  let digits = if code == 'X' { digits.to_upper() } else { digits }
  let base_prefix = if spec.alternate && radix != 10 {
    if code == 'b' {
      "0b"
    } else if code == 'o' {
      "0o"
    } else if code == 'X' {
      "0X"
    } else {
      "0x"
    }
  } else {
    ""
  }
  method_group_number(
    digits,
    method_numeric_prefix(negative, spec.sign) + base_prefix,
    spec,
    if radix == 10 {
      3
    } else {
      4
    },
    available~,
  )
}

///|
fn method_format_text(
  value : String,
  spec : MethodFormatSpec,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  if (spec.code != '\u0000' || spec.explicit_code) && spec.code != 's' {
    return named_format_error(
      "ValueError",
      "Unknown format code '" +
      method_code_description(spec.code) +
      "' for object of type 'str'",
    )
  }
  if spec.sign is Some(_) {
    return named_format_error(
      "ValueError", "Sign not allowed in string format specifier",
    )
  }
  if spec.negative_zero {
    return named_format_error(
      "ValueError", "Negative zero coercion (z) not allowed in string format specifier",
    )
  }
  if spec.alternate {
    return named_format_error(
      "ValueError", "Alternate form (#) not allowed in string format specifier",
    )
  }
  if spec.align == '=' {
    return named_format_error(
      "ValueError", "'=' alignment not allowed in string format specifier",
    )
  }
  if spec.grouping is Some(separator) {
    return named_format_error(
      "ValueError",
      "Cannot specify '" + String::from_array([separator]) + "' with 's'.",
    )
  }
  let chars = value.to_array()
  let value = match spec.precision {
    Some(precision) if precision < Int64::from_int(chars.length()) =>
      String::from_array(chars[:precision.to_int()])
    _ => value
  }
  method_pad(value, "", spec, available~)
}

///|
fn method_format_field(
  value : MethodFormatValue,
  format : String,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  match value {
    NoneValue | TypeValue(_) => {
      if format != "" {
        return named_format_error(
          "TypeError",
          "unsupported format string passed to " +
          method_type_name(value) +
          ".__format__",
        )
      }
      let text = method_str(value)
      if Int64::from_int(text.length()) > available {
        return named_format_error(
          "ResourceError", "formatted text exceeds String addressability",
        )
      }
      text
    }
    Text(text) =>
      method_format_text(
        text,
        method_parse_spec(format, "str", text=true),
        available~,
      )
    Integer(integer) =>
      method_format_integer(
        @bigint.BigInt::from_int64(integer),
        method_parse_spec(format, "int"),
        available~,
      )
    Scalar(PythonInteger(integer)) =>
      method_format_integer(
        integer,
        method_parse_spec(format, "int"),
        available~,
      )
    Scalar(NumpyInt64(integer)) =>
      method_format_integer(
        @bigint.BigInt::from_int64(integer),
        method_parse_spec(format, "int"),
        available~,
      )
    Scalar(PythonFloat(number)) | Scalar(NumpyFloat64(number)) =>
      method_format_float(
        number,
        method_parse_spec(format, "float"),
        available~,
      )
  }
}
