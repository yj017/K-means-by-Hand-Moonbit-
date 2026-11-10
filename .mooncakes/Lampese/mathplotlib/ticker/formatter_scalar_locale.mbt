///|
// CPython 3.12 locale.format_string's percent regex, not the raw percent parser.
priv struct ScalarLocaleMatch {
  start : Int32
  end : Int32
  code : Char
}

///|
fn scalar_locale_modifier(character : Char) -> Bool {
  match character {
    '-' | '#' | '0'..<='9' | ' ' | '+' | '*' | '.' | 'h' | 'l' | 'L' => true
    _ => false
  }
}

///|
fn scalar_locale_code(character : Char) -> Bool {
  match character {
    'e'
    | 'E'
    | 'f'
    | 'F'
    | 'g'
    | 'G'
    | 'd'
    | 'i'
    | 'o'
    | 'u'
    | 'x'
    | 'X'
    | 'c'
    | 'r'
    | 's'
    | '%' => true
    _ => false
  }
}

///|
fn scalar_locale_match_end(chars : Array[Char], start : Int32) -> Int32? {
  let mut index = start
  while index < chars.length() && scalar_locale_modifier(chars[index]) {
    index += 1
  }
  if index < chars.length() && scalar_locale_code(chars[index]) {
    Some(index + 1)
  } else {
    None
  }
}

///|
fn scalar_locale_match(
  chars : Array[Char],
  start : Int32,
) -> ScalarLocaleMatch? {
  let index = start + 1
  if index >= chars.length() {
    return None
  }
  if chars[index] == '(' {
    // The regex's non-greedy .*? key does not cross a newline. It can try
    // another ')' when an earlier one is not followed by a valid conversion.
    let mut close = index + 1
    while close < chars.length() && chars[close] != '\n' {
      if chars[close] == ')' {
        if scalar_locale_match_end(chars, close + 1) is Some(end) {
          return Some({ start, end, code: chars[end - 1], })
        }
      }
      close += 1
    }
    None
  } else {
    match scalar_locale_match_end(chars, index) {
      Some(end) => Some({ start, end, code: chars[end - 1], })
      None => None
    }
  }
}

///|
fn scalar_locale_group(text : String) -> (String, Int64) raise @core.DataError {
  let locale = @config.numeric_locale()
  let grouping = locale.grouping()
  if grouping.is_empty() {
    return (text, 0L)
  }
  let separator = locale.thousands_sep()
  let chars = text.to_array()
  if chars.is_empty() {
    ignore(named_format_error("IndexError", "string index out of range"))
  }
  let mut right = chars.length()
  if chars[right - 1] == ' ' {
    // Numeric native-percent padding is ASCII. Preserve the removed suffix.
    while right > 0 && chars[right - 1] == ' ' {
      right -= 1
    }
  }
  let right_spaces = String::from_array(chars[right:])
  let mut remaining = right
  let mut left_spaces = ""
  let groups : Array[String] = []
  let mut index = 0
  let mut last : Int32? = None
  let mut repeating = false
  while repeating || index < grouping.length() {
    let mut interval = if repeating {
      last.unwrap()
    } else {
      let interval = grouping[index]
      index += 1
      interval
    }
    if interval == 127 {
      break
    }
    if interval == 0 {
      match last {
        None => ignore(named_format_error("ValueError", "invalid grouping"))
        Some(previous) => {
          interval = previous
          repeating = true
        }
      }
    } else {
      last = Some(interval)
    }
    if remaining == 0 ||
      !(chars[remaining - 1] >= '0' && chars[remaining - 1] <= '9') {
      left_spaces = String::from_array(chars[:remaining])
      remaining = 0
      break
    }
    // Exact Python s[-interval:] / s[:-interval] slicing, including negative
    // finite intervals and Int32.MIN without overflowing an absolute value.
    let split64 = if interval > 0 {
      Int64::max(0L, Int64::from_int(remaining) - Int64::from_int(interval))
    } else {
      Int64::min(Int64::from_int(remaining), -Int64::from_int(interval))
    }
    let split = split64.to_int()
    groups.push(String::from_array(chars[split:remaining]))
    if repeating && split == remaining {
      return (
        named_format_error(
          "Unsupported", "locale negative repeated grouping does not terminate in CPython",
        ),
        0L,
      )
    }
    remaining = split
  }
  if remaining > 0 {
    groups.push(String::from_array(chars[:remaining]))
  }
  let separator_count = Int64::from_int(groups.length()) - 1L
  let mut units = Int64::from_int(left_spaces.length()) +
    Int64::from_int(right_spaces.length())
  for group in groups {
    units += Int64::from_int(group.length())
  }
  if separator_count > 0 {
    units += separator_count * Int64::from_int(separator.length())
  }
  if units > 2147483647L {
    return (
      named_format_error(
        "ResourceError", "localized number exceeds String addressability",
      ),
      0L,
    )
  }
  let result = StringBuilder()
  result.write_string(left_spaces)
  let mut first = true
  for index = groups.length() - 1; index >= 0; index = index - 1 {
    if !first {
      result.write_string(separator)
    }
    result.write_string(groups[index])
    first = false
  }
  result.write_string(right_spaces)
  (
    result.to_string(),
    // CPython len(str) is codepoints, independently of String address units.
    separator_count * Int64::from_int(separator.to_array().length()),
  )
}

///|
fn scalar_locale_strip_padding(text : String, amount : Int64) -> String {
  let chars = text.to_array()
  let mut amount = amount
  let mut left = 0
  while amount != 0L && left < chars.length() && chars[left] == ' ' {
    left += 1
    amount -= 1L
  }
  let mut right = chars.length() - 1
  while amount != 0L && right >= 0 && chars[right] == ' ' {
    right -= 1
    amount -= 1L
  }
  String::from_array(chars[left:Int32::max(left, right + 1)])
}

///|
fn scalar_locale_localize(text : String) -> String raise @core.DataError {
  if text.contains(".") {
    let parts = text.split(".").map(part => part.to_owned()).to_array()
    let (integer, separators) = scalar_locale_group(parts[0])
    parts[0] = integer
    let decimal = @config.numeric_locale().decimal_point()
    let mut units = Int64::from_int(decimal.length()) *
      Int64::from_int(parts.length() - 1)
    for part in parts {
      units += Int64::from_int(part.length())
    }
    if units > 2147483647L {
      return named_format_error(
        "ResourceError", "localized number exceeds String addressability",
      )
    }
    let result = parts.join(decimal)
    if separators != 0L {
      scalar_locale_strip_padding(result, separators)
    } else {
      result
    }
  } else {
    let (grouped, separators) = scalar_locale_group(text)
    if separators != 0L {
      scalar_locale_strip_padding(grouped, separators)
    } else {
      grouped
    }
  }
}

///|
// Native String-tuple percent pass. In particular, %a is not in locale's
// regex and consumes one of the prepared strings only at this final stage.
fn scalar_locale_string_tuple(
  format : String,
  values : Array[String],
  available : Int64,
) -> String raise @core.DataError {
  let chars = format.to_array()
  let result = StringBuilder()
  let mut index = 0
  let mut argument = 0
  let mut units = 0L
  while index < chars.length() {
    if chars[index] != '%' {
      units += Int64::from_int(chars[index].utf16_len())
      if units > available {
        return named_format_error(
          "ResourceError", "locale result exceeds String addressability",
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
          "ResourceError", "locale result exceeds String addressability",
        )
      }
      result.write_char('%')
      index += 1
      continue
    }
    if chars[index] == '(' {
      return named_format_error("TypeError", "format requires a mapping")
    }
    let mut left = false
    while index < chars.length() &&
          chars[index] is ('-' | '+' | ' ' | '#' | '0') {
      if chars[index] == '-' {
        left = true
      }
      index += 1
    }
    if index < chars.length() && chars[index] == '*' {
      return named_format_error(
        "TypeError",
        if argument < values.length() {
          "* wants int"
        } else {
          "not enough arguments for format string"
        },
      )
    }
    let mut width = 0L
    while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
      let digit = Int64::from_int(chars[index].to_int() - 48)
      if width > (9223372036854775807L - digit) / 10L {
        return named_format_error("ValueError", "width too big")
      }
      width = width * 10L + digit
      index += 1
    }
    let mut precision : Int32? = None
    if index < chars.length() && chars[index] == '.' {
      index += 1
      if index < chars.length() && chars[index] == '*' {
        return named_format_error(
          "TypeError",
          if argument < values.length() {
            "* wants int"
          } else {
            "not enough arguments for format string"
          },
        )
      }
      let mut digits = 0
      while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
        let digit = chars[index].to_int() - 48
        if digits > (2147483647 - digit) / 10 {
          return named_format_error("ValueError", "precision too big")
        }
        digits = digits * 10 + digit
        index += 1
      }
      precision = Some(digits)
    }
    if index < chars.length() && chars[index] is ('h' | 'l' | 'L') {
      index += 1
    }
    if index >= chars.length() {
      return named_format_error("ValueError", "incomplete format")
    }
    let position = index
    let code = chars[index]
    index += 1
    if argument >= values.length() {
      return named_format_error(
        "TypeError", "not enough arguments for format string",
      )
    }
    let value = values[argument]
    argument += 1
    let mut field = match code {
      's' => value
      'r' => method_quote(value)
      'a' => method_quote(value, ascii=true)
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
    // String precision and width count Python codepoints. Budget counts UTF16
    // address units, including a two-unit astral character in an %s field.
    let field_chars = field.to_array()
    if precision is Some(limit) && limit < field_chars.length() {
      field = String::from_array(field_chars[:limit])
    }
    let padding = Int64::max(
      0L,
      width - Int64::from_int(field.to_array().length()),
    )
    let final_units = Int64::from_int(field.length()) + padding
    if final_units > available - units {
      return named_format_error(
        "ResourceError", "locale result exceeds String addressability",
      )
    }
    units += final_units
    if !left && padding > 0L {
      result.write_string(method_repeat(' ', padding))
    }
    result.write_string(field)
    if left && padding > 0L {
      result.write_string(method_repeat(' ', padding))
    }
  }
  if argument < values.length() {
    return named_format_error(
      "TypeError", "not all arguments converted during string formatting",
    )
  }
  result.to_string()
}

///|
fn scalar_locale_format_string(
  format : String,
  value : ScalarNumber,
  available : Int64,
) -> String raise @core.DataError {
  let chars = format.to_array()
  let matches : Array[ScalarLocaleMatch] = []
  let replacement = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '%' && scalar_locale_match(chars, index) is Some(found) {
      matches.push(found)
      replacement.write_string("%s")
      index = found.end
    } else {
      replacement.write_char(chars[index])
      index += 1
    }
  }
  let fields : Array[String] = []
  let mut used = false
  for found in matches {
    if found.code == '%' {
      fields.push("%")
    } else {
      if used {
        return named_format_error("IndexError", "tuple index out of range")
      }
      used = true
      let percent = String::from_array(chars[found.start:found.end])
      // _format creates this intermediate scalar string before locale grouping
      // and before the final replacement string exists. Grouping can remove
      // all of an inf/nan field's spaces, so final remaining is not its budget.
      let formatted = scalar_percent_format(percent, value)
      fields.push(
        if found.code is ('e' | 'E' | 'f' | 'F' | 'g' | 'G' | 'd' | 'i' | 'u') {
          scalar_locale_localize(formatted)
        } else {
          formatted
        },
      )
    }
  }
  scalar_locale_string_tuple(replacement.to_string(), fields, available)
}

///|
fn scalar_named_format(
  format : String,
  value : ScalarNumber,
  use_locale : Bool,
  use_math_text : Bool,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  let formatted = if !use_locale {
    scalar_percent_format(format, value, available~)
  } else if use_math_text {
    let output = StringBuilder()
    let mut first = true
    let mut units = 0L
    for part in format.split(",") {
      if !first {
        units += 1L
        output.write_char(',')
      }
      let field = scalar_locale_format_string(
        part.to_owned(),
        value,
        available - units,
      )
      let commas = field
        .to_array()
        .filter(character => character == ',')
        .length()
      let escaped_units = Int64::from_int(field.length()) +
        Int64::from_int(commas) * 2L
      if escaped_units > available - units {
        return named_format_error(
          "ResourceError", "locale math text exceeds String addressability",
        )
      }
      output.write_string(field.replace_all(old=",", new="{,}"))
      units += escaped_units
      first = false
    }
    output.to_string()
  } else {
    scalar_locale_format_string(format, value, available)
  }
  if @config.unicode_minus() {
    formatted.replace_all(old="-", new="−")
  } else {
    formatted
  }
}
