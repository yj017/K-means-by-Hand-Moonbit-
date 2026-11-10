///|
// A component boundary separates two injective scalar encodings. In particular,
// ("a-b", "c") cannot collide with ("a", "b-c"), even for arbitrary Unicode.
fn resource_component(value : String) -> String {
  let result = StringBuilder()
  for char in value.iter() {
    result.write_string(char.to_int().to_string())
    result.write_char('_')
  }
  result.to_string()
}

///|
fn resource_id(chart_id : String, source_id : String) -> String {
  "moonplot-resource-" +
  resource_component(chart_id) +
  "-" +
  resource_component(source_id)
}

///|
fn resource_space(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\n' || char == '\r' || char == '\u{c}'
}

///|
fn resource_chars(chars : Array[Char], start : Int32, end : Int32) -> String {
  let result = StringBuilder()
  for index in start..<end {
    result.write_char(chars[index])
  }
  result.to_string()
}

///|
fn resource_hex(char : Char) -> Int32? {
  if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else if char >= 'a' && char <= 'f' {
    Some(char.to_int() - 'a'.to_int() + 10)
  } else if char >= 'A' && char <= 'F' {
    Some(char.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
// URI fragments are decoded before ID lookup. Decoding is strict so malformed
// percent escapes cannot accidentally escape the current chart's namespace.
fn resource_fragment(value : String) -> String raise AdapterError {
  let chars = value.to_array()
  let result = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '%' {
      result.write_char(chars[index])
      index += 1
      continue
    }
    let bytes : Array[Int32] = []
    while index < chars.length() && chars[index] == '%' {
      guard index + 2 < chars.length() else {
        raise InvalidSvg("Incomplete percent escape in SVG reference: " + value)
      }
      guard (resource_hex(chars[index + 1]), resource_hex(chars[index + 2]))
        is (Some(high), Some(low)) else {
        raise InvalidSvg("Invalid percent escape in SVG reference: " + value)
      }
      bytes.push(high * 16 + low)
      index += 3
    }
    let mut position = 0
    while position < bytes.length() {
      let first = bytes[position]
      let (count, initial, minimum) = if first < 0x80 {
        (1, first, 0)
      } else if first >= 0xc2 && first <= 0xdf {
        (2, first - 0xc0, 0x80)
      } else if first >= 0xe0 && first <= 0xef {
        (3, first - 0xe0, 0x800)
      } else if first >= 0xf0 && first <= 0xf4 {
        (4, first - 0xf0, 0x10000)
      } else {
        raise InvalidSvg("Invalid UTF-8 in SVG reference: " + value)
      }
      if position + count > bytes.length() {
        raise InvalidSvg("Incomplete UTF-8 in SVG reference: " + value)
      }
      let mut scalar = initial
      for offset in 1..<count {
        let byte = bytes[position + offset]
        if byte < 0x80 || byte > 0xbf {
          raise InvalidSvg(
            "Invalid UTF-8 continuation in SVG reference: " + value,
          )
        }
        scalar = scalar * 64 + byte - 0x80
      }
      if scalar < minimum ||
        scalar > 0x10ffff ||
        (scalar >= 0xd800 && scalar <= 0xdfff) ||
        scalar == 0 {
        raise InvalidSvg("Invalid Unicode scalar in SVG reference: " + value)
      }
      result.write_char(scalar.unsafe_to_char())
      position += count
    }
  }
  result.to_string()
}

///|
// The existing public root ID remains chart_id + "-svg". Encode its fragment
// when necessary; resource IDs themselves contain only unreserved ASCII.
fn resource_uri(value : String) -> String {
  let result = StringBuilder()
  let digits = "0123456789ABCDEF".to_array()
  for char in value.iter() {
    let scalar = char.to_int()
    if char.is_ascii_alphabetic() ||
      char.is_ascii_digit() ||
      char == '-' ||
      char == '_' ||
      char == '.' ||
      char == '~' {
      result.write_char(char)
    } else {
      let bytes = if scalar < 0x80 {
        [scalar]
      } else if scalar < 0x800 {
        [0xc0 + scalar / 64, 0x80 + scalar % 64]
      } else if scalar < 0x10000 {
        [0xe0 + scalar / 4096, 0x80 + scalar / 64 % 64, 0x80 + scalar % 64]
      } else {
        [
          0xf0 + scalar / 262144,
          0x80 + scalar / 4096 % 64,
          0x80 + scalar / 64 % 64,
          0x80 + scalar % 64,
        ]
      }
      for byte in bytes {
        result.write_char('%')
        result.write_char(digits[byte / 16])
        result.write_char(digits[byte % 16])
      }
    }
  }
  result.to_string()
}

///|
fn collect_resource_ids(
  content : SvgContent,
  ids : Map[String, String],
  chart_id : String,
  root : Bool,
) -> Unit raise AdapterError {
  match content {
    Text(_) => ()
    Element(_, attributes, children) => {
      let mut has_id = false
      for (name, value) in attributes {
        if name == "id" {
          if has_id {
            raise InvalidSvg("Duplicate id attribute in SVG element")
          }
          has_id = true
          if value.trim().length() == 0 {
            raise InvalidSvg("SVG IDs must not be empty")
          }
          if ids.contains(value) {
            raise InvalidSvg("Duplicate SVG ID: " + value)
          }
          ids[value] = if root {
            chart_id + "-svg"
          } else {
            resource_id(chart_id, value)
          }
        }
      }
      for child in children {
        collect_resource_ids(child, ids, chart_id, false)
      }
    }
  }
}

///|
fn scoped_resource_fragment(
  fragment : String,
  ids : Map[String, String],
) -> String raise AdapterError {
  let decoded = resource_fragment(fragment)
  // A literal percent ID and its decoded spelling in the same source would
  // make the intended reference ambiguous; require an unambiguous spelling.
  if decoded != fragment && ids.contains(decoded) && ids.contains(fragment) {
    raise InvalidSvg("Ambiguous percent-encoded SVG reference: " + fragment)
  }
  match ids.get(decoded) {
    Some(value) => "#" + resource_uri(value)
    None => raise InvalidSvg("Unknown local SVG reference: " + fragment)
  }
}

///|
// Decode a CSS escape in a string or url token, returning the next position.
fn resource_css_escape(
  chars : Array[Char],
  start : Int32,
  result : StringBuilder,
) -> Int32 raise AdapterError {
  let mut index = start + 1
  if index == chars.length() {
    raise InvalidSvg("Incomplete CSS escape in SVG attribute")
  }
  if chars[index] == '\n' || chars[index] == '\r' || chars[index] == '\u{c}' {
    if chars[index] == '\r' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '\n' {
      index += 1
    }
    return index + 1
  }
  match resource_hex(chars[index]) {
    Some(_) => {
      let mut scalar = 0
      let mut count = 0
      while index < chars.length() && count < 6 {
        match resource_hex(chars[index]) {
          Some(digit) => {
            scalar = scalar * 16 + digit
            index += 1
            count += 1
          }
          None => break
        }
      }
      if index < chars.length() && resource_space(chars[index]) {
        if chars[index] == '\r' &&
          index + 1 < chars.length() &&
          chars[index + 1] == '\n' {
          index += 1
        }
        index += 1
      }
      if scalar == 0 ||
        scalar > 0x10ffff ||
        (scalar >= 0xd800 && scalar <= 0xdfff) {
        raise InvalidSvg("Invalid Unicode CSS escape in SVG reference")
      }
      result.write_char(scalar.unsafe_to_char())
      index
    }
    None => {
      result.write_char(chars[index])
      index + 1
    }
  }
}

///|
fn resource_css_string(
  chars : Array[Char],
  start : Int32,
) -> (String, Int32) raise AdapterError {
  let quote = chars[start]
  let result = StringBuilder()
  let mut index = start + 1
  while index < chars.length() {
    if chars[index] == quote {
      return (result.to_string(), index + 1)
    } else if chars[index] == '\\' {
      index = resource_css_escape(chars, index, result)
    } else if chars[index] == '\n' ||
      chars[index] == '\r' ||
      chars[index] == '\u{c}' {
      raise InvalidSvg("Unescaped newline in SVG CSS string")
    } else {
      result.write_char(chars[index])
      index += 1
    }
  }
  raise InvalidSvg("Unclosed CSS string in SVG attribute")
}

///|
fn resource_css_url(
  chars : Array[Char],
  open : Int32,
) -> (String, Int32) raise AdapterError {
  let mut index = open + 1
  while index < chars.length() && resource_space(chars[index]) {
    index += 1
  }
  let result = StringBuilder()
  if index < chars.length() && (chars[index] == '\'' || chars[index] == '"') {
    let (value, next) = resource_css_string(chars, index)
    result.write_string(value)
    index = next
    while index < chars.length() && resource_space(chars[index]) {
      index += 1
    }
  } else {
    while index < chars.length() && chars[index] != ')' {
      if chars[index] == '\\' {
        index = resource_css_escape(chars, index, result)
      } else if resource_space(chars[index]) {
        while index < chars.length() && resource_space(chars[index]) {
          index += 1
        }
        break
      } else if chars[index] == '\'' ||
        chars[index] == '"' ||
        chars[index] == '(' {
        raise InvalidSvg("Malformed unquoted SVG CSS url")
      } else {
        result.write_char(chars[index])
        index += 1
      }
    }
  }
  if index >= chars.length() || chars[index] != ')' {
    raise InvalidSvg("Unclosed or malformed SVG CSS url")
  }
  (result.to_string(), index + 1)
}

///|
fn resource_css_ident(char : Char) -> Bool {
  char.is_ascii_alphabetic() ||
  char.is_ascii_digit() ||
  char == '_' ||
  char == '-' ||
  char.to_int() >= 0x80
}

///|
fn resource_css_name(
  chars : Array[Char],
  start : Int32,
) -> (String, Int32) raise AdapterError {
  let result = StringBuilder()
  let mut index = start
  while index < chars.length() {
    if resource_css_ident(chars[index]) {
      result.write_char(chars[index].to_ascii_lowercase())
      index += 1
    } else if chars[index] == '\\' {
      index = resource_css_escape(chars, index, result)
    } else {
      break
    }
  }
  (result.to_string().to_lower(), index)
}

///|
// Scan CSS tokens rather than replacing substrings: strings, comments, external
// URLs and data URLs retain their exact source, while local url() is canonical.
fn scope_resource_urls(
  value : String,
  ids : Map[String, String],
) -> String raise AdapterError {
  let chars = value.to_array()
  let result = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    let start = index
    if chars[index] == '\'' || chars[index] == '"' {
      let (_, next) = resource_css_string(chars, index)
      index = next
    } else if index + 1 < chars.length() &&
      chars[index] == '/' &&
      chars[index + 1] == '*' {
      index += 2
      while index + 1 < chars.length() &&
            !(chars[index] == '*' && chars[index + 1] == '/') {
        index += 1
      }
      if index + 1 >= chars.length() {
        raise InvalidSvg("Unclosed SVG CSS comment")
      }
      index += 2
    } else if resource_css_ident(chars[index]) || chars[index] == '\\' {
      let (name, end) = resource_css_name(chars, index)
      if name == "url" && end < chars.length() && chars[end] == '(' {
        let (url, next) = resource_css_url(chars, end)
        if url.has_prefix("#") {
          result.write_string("url(\"")
          result.write_string(scoped_resource_fragment(url[1:].to_owned(), ids))
          result.write_string("\")")
          index = next
          continue
        }
        index = next
      } else {
        index = end
      }
    } else {
      index += 1
    }
    result.write_string(resource_chars(chars, start, index))
  }
  result.to_string()
}

///|
fn scope_resource_idrefs(
  value : String,
  ids : Map[String, String],
) -> String raise AdapterError {
  let result = StringBuilder()
  let token = StringBuilder()
  for char in value.iter() {
    if resource_space(char) {
      if !token.is_empty() {
        match ids.get(token.to_string()) {
          Some(id) => result.write_string(id)
          None => raise InvalidSvg("Unknown SVG IDREF: " + token.to_string())
        }
        token.reset()
      }
      result.write_char(char)
    } else {
      token.write_char(char)
    }
  }
  if !token.is_empty() {
    match ids.get(token.to_string()) {
      Some(id) => result.write_string(id)
      None => raise InvalidSvg("Unknown SVG IDREF: " + token.to_string())
    }
  }
  result.to_string()
}

///|
fn rewrite_resource_ids(
  content : SvgContent,
  ids : Map[String, String],
) -> SvgContent raise AdapterError {
  match content {
    Text(_) => content
    Element(name, attributes, children) => {
      let rewritten = attributes.map(attribute => {
        let (key, value) = attribute
        let scoped = match key {
          "id" => ids[value]
          "href" | "xlink:href" => {
            let url = value.trim().to_owned()
            if url.has_prefix("#") {
              scoped_resource_fragment(url[1:].to_owned(), ids)
            } else {
              value
            }
          }
          // Pure IDREF normalization is ready for public SVG ARIA setters.
          // Rabbita 0.16.7 still explicitly rejects these at node construction.
          "aria-labelledby" | "aria-describedby" =>
            scope_resource_idrefs(value, ids)
          "style"
          | "fill"
          | "stroke"
          | "clip-path"
          | "filter"
          | "mask"
          | "cursor"
          | "marker-start"
          | "marker-mid"
          | "marker-end" => scope_resource_urls(value, ids)
          _ => value
        }
        (key, scoped)
      })
      // Both legacy and SVG2 href become the same public Rabbita attribute.
      // Reject conflicting spellings instead of depending on attribute order.
      let mut href : String? = None
      for (key, value) in rewritten {
        if key == "href" || key == "xlink:href" {
          if href is Some(previous) && previous != value {
            raise InvalidSvg(
              "Conflicting href and xlink:href on SVG element: " + name,
            )
          }
          href = Some(value)
        }
      }
      Element(
        name,
        rewritten,
        children.map(child => rewrite_resource_ids(child, ids)),
      )
    }
  }
}

///|
fn scope_svg_resources(
  content : SvgContent,
  chart_id : String,
) -> SvgContent raise AdapterError {
  if chart_id.trim().length() == 0 {
    raise InvalidSvg("Chart IDs must not be empty")
  }
  let ids : Map[String, String] = Map([])
  collect_resource_ids(content, ids, chart_id, true)
  rewrite_resource_ids(content, ids)
}
