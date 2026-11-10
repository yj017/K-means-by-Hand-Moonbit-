///|
priv enum MethodFormatValue {
  Scalar(NamedFormatValue)
  Integer(Int64)
  Text(String)
  NoneValue
  TypeValue(String)
}

///|
fn method_decimal_digit(character : Char) -> Int32? {
  let code = character.to_int()
  for
    zero in [
      0x30, 0x660, 0x6f0, 0x7c0, 0x966, 0x9e6, 0xa66, 0xae6, 0xb66, 0xbe6, 0xc66,
      0xce6, 0xd66, 0xde6, 0xe50, 0xed0, 0xf20, 0x1040, 0x1090, 0x17e0, 0x1810, 0x1946,
      0x19d0, 0x1a80, 0x1a90, 0x1b50, 0x1bb0, 0x1c40, 0x1c50, 0xa620, 0xa8d0, 0xa900,
      0xa9d0, 0xa9f0, 0xaa50, 0xabf0, 0xff10, 0x104a0, 0x10d30, 0x11066, 0x110f0,
      0x11136, 0x111d0, 0x112f0, 0x11450, 0x114d0, 0x11650, 0x116c0, 0x11730, 0x118e0,
      0x11950, 0x11c50, 0x11d50, 0x11da0, 0x11f50, 0x16a60, 0x16ac0, 0x16b50, 0x1d7ce,
      0x1d7d8, 0x1d7e2, 0x1d7ec, 0x1d7f6, 0x1e140, 0x1e2f0, 0x1e4f0, 0x1e950, 0x1fbf0,
    ] {
    if code >= zero && code < zero + 10 {
      return Some(code - zero)
    }
  }
  None
}

///|
fn method_quote(value : String, ascii~ : Bool = false) -> String {
  let quote = if value.contains("'") && !value.contains("\"") {
    '"'
  } else {
    '\''
  }
  let result = StringBuilder()
  result.write_char(quote)
  for character in value.to_array() {
    let code = character.to_int()
    if character == quote || character == '\\' {
      result.write_char('\\')
      result.write_char(character)
    } else if character == '\n' {
      result.write_string("\\n")
    } else if character == '\r' {
      result.write_string("\\r")
    } else if character == '\t' {
      result.write_string("\\t")
    } else if !named_format_python_printable(character) ||
      (ascii && code >= 128) {
      let (prefix, width) = if code <= 255 {
        ("\\x", 2)
      } else if code <= 65535 {
        ("\\u", 4)
      } else {
        ("\\U", 8)
      }
      result.write_string(
        prefix +
        code.reinterpret_as_uint().to_string(radix=16).pad_start(width, '0'),
      )
    } else {
      result.write_char(character)
    }
  }
  result.write_char(quote)
  result.to_string()
}

///|
/// Represent a String using the existing Python quoting and Unicode profile.
pub fn python_string_repr(value : String) -> String {
  method_quote(value)
}

///|
fn method_type_name(value : MethodFormatValue) -> String {
  match value {
    Scalar(PythonFloat(_)) => "float"
    Scalar(PythonInteger(_)) => "int"
    Scalar(NumpyFloat64(_)) => "float64"
    Scalar(NumpyInt64(_)) => "int64"
    Integer(_) => "int"
    Text(_) => "str"
    NoneValue => "NoneType"
    TypeValue(_) => "type"
  }
}

///|
fn method_str(value : MethodFormatValue) -> String raise @core.DataError {
  match value {
    Scalar(value) => named_format_value_str(value)
    Integer(value) => value.to_string()
    Text(value) => value
    NoneValue => "None"
    TypeValue(name) => {
      let name = if name == "float64" || name == "int64" {
        "numpy." + name
      } else {
        name
      }
      "<class '" + name + "'>"
    }
  }
}

///|
fn method_repr(
  value : MethodFormatValue,
  ascii~ : Bool = false,
) -> String raise @core.DataError {
  match value {
    Scalar(value) => named_format_value_repr(value)
    Text(value) => method_quote(value, ascii~)
    _ => method_str(value)
  }
}

///|
fn method_attribute(
  value : MethodFormatValue,
  name : String,
) -> MethodFormatValue raise @core.DataError {
  if name == "__class__" {
    return TypeValue(method_type_name(value))
  }
  match (value, name) {
    (TypeValue(name), "__name__") => Text(name)
    (Scalar(PythonFloat(number)), "real") => Scalar(PythonFloat(number))
    (Scalar(NumpyFloat64(number)), "real") => Scalar(NumpyFloat64(number))
    (Scalar(PythonFloat(_)), "imag") => Scalar(PythonFloat(0.0))
    (Scalar(NumpyFloat64(_)), "imag") => Scalar(NumpyFloat64(0.0))
    (Scalar(PythonInteger(number)), "real" | "numerator") =>
      Scalar(PythonInteger(number))
    (Scalar(PythonInteger(_)), "imag") =>
      Scalar(PythonInteger(@bigint.BigInt::from_int(0)))
    (Scalar(PythonInteger(_)), "denominator") => Integer(1L)
    (Scalar(NumpyInt64(number)), "real" | "numerator") =>
      Scalar(NumpyInt64(number))
    (Scalar(NumpyInt64(_)), "imag") => Scalar(NumpyInt64(0L))
    (Scalar(NumpyInt64(_)), "denominator") => Integer(1L)
    (Integer(number), "real" | "numerator") => Integer(number)
    (Integer(_), "imag") => Integer(0L)
    (Integer(_), "denominator") => Integer(1L)
    _ => {
      ignore(
        named_format_error(
          "Unsupported",
          "dynamic attribute " +
          method_quote(name) +
          " on " +
          method_type_name(value),
        ),
      )
      value
    }
  }
}

///|
// Parse Python's decimal Nd integer tokens, retaining Py_ssize_t overflow order.
fn method_decimal_token(chars : Array[Char]) -> Int64? raise @core.DataError {
  if chars.length() == 0 {
    return None
  }
  let mut result = 0L
  for character in chars {
    let digit = match method_decimal_digit(character) {
      Some(digit) => digit
      None => return None
    }
    if result > (9223372036854775807L - Int64::from_int(digit)) / 10L {
      ignore(
        named_format_error(
          "ValueError", "Too many decimal digits in format string",
        ),
      )
    }
    result = result * 10L + Int64::from_int(digit)
  }
  Some(result)
}

///|
fn method_subscript(
  value : MethodFormatValue,
  token : String,
) -> MethodFormatValue raise @core.DataError {
  let index = method_decimal_token(token.to_array())
  match value {
    Text(text) =>
      match index {
        None => {
          ignore(
            named_format_error(
              "TypeError", "string indices must be integers, not 'str'",
            ),
          )
          value
        }
        Some(index) => {
          let chars = text.to_array()
          if index >= Int64::from_int(chars.length()) {
            ignore(
              named_format_error("IndexError", "string index out of range"),
            )
            return value
          }
          Text(String::from_array([chars[index.to_int()]]))
        }
      }
    _ => {
      let name = match value {
        Scalar(NumpyFloat64(_)) => "numpy.float64"
        Scalar(NumpyInt64(_)) => "numpy.int64"
        _ => method_type_name(value)
      }
      if name == "numpy.float64" || name == "numpy.int64" {
        ignore(
          named_format_error("IndexError", "invalid index to scalar variable."),
        )
      } else {
        ignore(
          named_format_error(
            "TypeError",
            "'" + name + "' object is not subscriptable",
          ),
        )
      }
      value
    }
  }
}

///|
fn method_resolve_field(
  name : String,
  value : NamedFormatValue,
  position : Int32?,
) -> MethodFormatValue raise @core.DataError {
  let chars = name.to_array()
  let mut index = 0
  while index < chars.length() && chars[index] != '.' && chars[index] != '[' {
    index += 1
  }
  let first = String::from_array(chars[:index])
  let numeric = method_decimal_token(chars[:index].to_owned())
  if first == "" || numeric is Some(_) {
    ignore(named_format_error("IndexError", "tuple index out of range"))
  }
  let mut result : MethodFormatValue = if first == "x" {
    MethodFormatValue::Scalar(value)
  } else if first == "pos" {
    match position {
      Some(position) => Integer(Int64::from_int(position))
      None => NoneValue
    }
  } else {
    ignore(named_format_error("KeyError", method_quote(first)))
    NoneValue
  }
  while index < chars.length() {
    let is_attribute = chars[index] == '.'
    if !is_attribute && chars[index] != '[' {
      ignore(
        named_format_error(
          "ValueError", "Only '.' or '[' may follow ']' in format field specifier",
        ),
      )
    }
    index += 1
    let start = index
    if is_attribute {
      while index < chars.length() && chars[index] != '.' && chars[index] != '[' {
        index += 1
      }
      if start == index {
        ignore(
          named_format_error("ValueError", "Empty attribute in format string"),
        )
      }
      result = method_attribute(result, String::from_array(chars[start:index]))
    } else {
      while index < chars.length() && chars[index] != ']' {
        index += 1
      }
      if index == chars.length() {
        ignore(named_format_error("ValueError", "Missing ']' in format string"))
      }
      if start == index {
        ignore(
          named_format_error("ValueError", "Empty attribute in format string"),
        )
      }
      result = method_subscript(result, String::from_array(chars[start:index]))
      index += 1
    }
  }
  result
}
