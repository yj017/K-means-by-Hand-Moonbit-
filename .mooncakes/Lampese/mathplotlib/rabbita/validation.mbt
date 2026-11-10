///|
fn svg_words(value : String) -> Array[String] {
  let words : Array[String] = []
  let mut token = ""
  for char in value.iter() {
    if char == ' ' ||
      char == '\t' ||
      char == '\n' ||
      char == '\r' ||
      char == ',' {
      if token.length() > 0 {
        words.push(token)
        token = ""
      }
    } else {
      token += char.to_string()
    }
  }
  if token.length() > 0 {
    words.push(token)
  }
  words
}

///|
fn validate_drawing(
  drawing : @drawing.Drawing,
  content : SvgContent,
) -> Unit raise AdapterError {
  if drawing.width() <= 0 || drawing.height() <= 0 {
    raise InvalidSvg("Drawing dimensions must be positive")
  }
  let attributes = match content {
    Element("svg", attributes, _) => attributes
    _ => raise InvalidSvg("The root element must be svg")
  }
  let mut view_box : String? = None
  for (name, value) in attributes {
    if name == "viewBox" {
      view_box = Some(value)
    } else if name == "preserveAspectRatio" {
      let words = svg_words(value)
      if words != ["xMidYMid"] && words != ["xMidYMid", "meet"] {
        raise InvalidSvg("Only preserveAspectRatio xMidYMid meet is supported")
      }
    }
  }
  let words = match view_box {
    Some(value) => svg_words(value)
    None => raise InvalidSvg("Drawing SVG must declare its viewBox")
  }
  if words.length() != 4 {
    raise InvalidSvg("Drawing viewBox must contain four numbers")
  }
  let numbers = words.map(word => {
    @string.parse_double(word[:]) catch {
      _ => raise InvalidSvg("Invalid viewBox number: " + word)
    }
  })
  if numbers[0] != 0.0 ||
    numbers[1] != 0.0 ||
    numbers[2] != drawing.width().to_double() ||
    numbers[3] != drawing.height().to_double() {
    raise InvalidSvg("Drawing viewBox must match 0 0 width height")
  }
}
