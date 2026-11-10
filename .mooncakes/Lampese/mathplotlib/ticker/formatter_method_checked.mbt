///|
// Execute replacement fields lazily in the same order as string.Formatter.
fn method_expand(
  format : String,
  value : NamedFormatValue,
  position : Int32?,
  depth : Int32,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  if depth < 0 {
    return named_format_error("ValueError", "Max string recursion exceeded")
  }
  let chars = format.to_array()
  let output = StringBuilder()
  let mut used = 0L
  let mut index = 0
  while index < chars.length() {
    let character = chars[index]
    if character != '{' && character != '}' {
      used += if character.to_int() > 65535 { 2L } else { 1L }
      if used > available {
        return named_format_error(
          "ResourceError", "formatted text exceeds String addressability",
        )
      }
      output.write_char(character)
      index += 1
      continue
    }
    if index + 1 < chars.length() && chars[index + 1] == character {
      used += 1L
      if used > available {
        return named_format_error(
          "ResourceError", "formatted text exceeds String addressability",
        )
      }
      output.write_char(character)
      index += 2
      continue
    }
    if character == '}' {
      return named_format_error(
        "ValueError", "Single '}' encountered in format string",
      )
    }
    index += 1
    if index == chars.length() {
      return named_format_error(
        "ValueError", "Single '{' encountered in format string",
      )
    }
    let field_start = index
    while index < chars.length() &&
          chars[index] != ':' &&
          chars[index] != '!' &&
          chars[index] != '}' {
      if chars[index] == '{' {
        return named_format_error("ValueError", "unexpected '{' in field name")
      }
      if chars[index] == '[' {
        index += 1
        while index < chars.length() && chars[index] != ']' {
          index += 1
        }
        if index == chars.length() {
          break
        }
      }
      index += 1
    }
    if index == chars.length() {
      return named_format_error(
        "ValueError", "expected '}' before end of string",
      )
    }
    let name = String::from_array(chars[field_start:index])
    let mut conversion : Char? = None
    if chars[index] == '!' {
      index += 1
      if index == chars.length() {
        return named_format_error(
          "ValueError", "end of string while looking for conversion specifier",
        )
      }
      conversion = Some(chars[index])
      index += 1
      if index == chars.length() {
        return named_format_error("ValueError", "unmatched '{' in format spec")
      }
      if chars[index] != ':' && chars[index] != '}' {
        return named_format_error(
          "ValueError", "expected ':' after conversion specifier",
        )
      }
    }
    let spec = if chars[index] == ':' {
      index += 1
      let start = index
      let mut nested = 0
      while index < chars.length() {
        if chars[index] == '{' {
          nested += 1
        }
        if chars[index] == '}' {
          if nested == 0 {
            break
          }
          nested -= 1
        }
        index += 1
      }
      if index == chars.length() {
        return named_format_error("ValueError", "unmatched '{' in format spec")
      }
      String::from_array(chars[start:index])
    } else {
      ""
    }
    index += 1
    let field = method_resolve_field(name, value, position)
    let field = match conversion {
      None => field
      Some('s') => Text(method_str(field))
      Some('r') => Text(method_repr(field))
      Some('a') => Text(method_repr(field, ascii=true))
      Some(character) => {
        ignore(
          named_format_error(
            "ValueError",
            "Unknown conversion specifier " + String::from_array([character]),
          ),
        )
        field
      }
    }
    let spec = method_expand(spec, value, position, depth - 1)
    let text = method_format_field(field, spec, available=available - used)
    used += Int64::from_int(text.length())
    output.write_string(BaseFormatter::fix_minus(text))
  }
  output.to_string()
}

///|
fn format_method_checked(
  format : String,
  value : NamedFormatValue,
  position : Int32?,
) -> String raise @core.DataError {
  method_expand(format, value, position, 2)
}
