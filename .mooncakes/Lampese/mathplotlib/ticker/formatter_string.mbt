///|

///|
fn format_index(labels : Array[String], value : Double) -> String {
  if labels.length() == 0 || value.is_nan() || value.is_inf() {
    return ""
  }
  let index = value.round().to_int()
  if Double::abs(value - Double::from_int(index)) > 1.0e-10 ||
    index < 0 ||
    index >= labels.length() {
    ""
  } else {
    labels[index]
  }
}

///|
fn format_str_method(format : String, value : Double) -> String {
  format_str_method_at(format, value, 0)
}

///|
fn format_str_method_at(
  format : String,
  value : Double,
  position : Int32,
) -> String {
  let chars = format.to_array()
  let result = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '{' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '{' {
      result.write_char('{')
      index += 2
      continue
    }
    if chars[index] == '}' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '}' {
      result.write_char('}')
      index += 2
      continue
    }
    if chars[index] != '{' {
      result.write_char(chars[index])
      index += 1
      continue
    }
    let start = index + 1
    let mut close : Int32? = None
    let mut cursor = start
    while cursor < chars.length() {
      if chars[cursor] == '}' {
        close = Some(cursor)
        break
      }
      cursor += 1
    }
    match close {
      None => {
        result.write_char('{')
        index += 1
      }
      Some(end) => {
        let token = String::from_array(chars[start:end])
        let rendered = format_method_token(token, value, position)
        if rendered == "" && token != "x" && token != "value" && token != "pos" {
          for original in (start - 1)..<=end {
            result.write_char(chars[original])
          }
        } else {
          result.write_string(rendered)
        }
        index = end + 1
      }
    }
  }
  result.to_string()
}

///|
fn format_method_token(
  token : String,
  value : Double,
  position : Int32,
) -> String {
  if token == "x" || token == "value" {
    return format_general(value, None, false)
  }
  if token == "pos" {
    return position.to_string()
  }
  if token.has_prefix("x:") || token.has_prefix("value:") {
    let spec_start = if token.has_prefix("x:") { 2 } else { 6 }
    let spec = String::unsafe_substring(
      token,
      start=spec_start,
      end=token.length(),
    )
    return format_method_spec(spec, value)
  }
  if token.has_prefix("pos:") {
    let spec = String::unsafe_substring(token, start=4, end=token.length())
    return format_method_spec(spec, Double::from_int(position))
  }
  ""
}

///|
fn format_method_spec(spec : String, value : Double) -> String {
  if spec == "" {
    return format_general(value, None, false)
  }
  if spec.has_prefix("%") {
    format_printf(spec, value)
  } else {
    format_printf("%" + spec, value)
  }
}
