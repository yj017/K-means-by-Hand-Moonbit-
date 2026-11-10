///|
priv enum SvgContent {
  Element(String, Array[(String, String)], Array[SvgContent])
  Text(String)
}

///|
priv struct SvgFrame {
  name : String
  attributes : Array[(String, String)]
  children : Array[SvgContent]
}

///|
fn check_element(name : String) -> Unit raise AdapterError {
  match name {
    "svg"
    | "g"
    | "defs"
    | "clipPath"
    | "path"
    | "polyline"
    | "polygon"
    | "line"
    | "circle"
    | "ellipse"
    | "rect"
    | "text"
    | "tspan"
    | "image"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "title"
    | "desc" => ()
    _ => raise UnsupportedElement(name)
  }
}

///|
fn frame(element : @xml.XmlElement) -> SvgFrame raise AdapterError {
  check_element(element.name)
  {
    name: element.name,
    attributes: element.attributes.map(attribute => {
      (attribute.name, attribute.value)
    }),
    children: [],
  }
}

///|
fn append_content(
  stack : Array[SvgFrame],
  roots : Array[SvgContent],
  content : SvgContent,
) -> Unit {
  let destination = if stack.length() == 0 {
    roots
  } else {
    stack[stack.length() - 1].children
  }
  if destination.length() > 0 {
    match (destination[destination.length() - 1], content) {
      (Text(previous), Text(value)) => {
        destination[destination.length() - 1] = Text(previous + value)
        return
      }
      _ => ()
    }
  }
  destination.push(content)
}

///|
fn parse_svg(source : String) -> SvgContent raise AdapterError {
  let reader = @xml.Reader::from_string(source)
  let stack : Array[SvgFrame] = []
  let roots : Array[SvgContent] = []
  while true {
    let event = reader.read_event() catch {
      error => raise InvalidSvg(error.to_string())
    }
    match event.kind {
      Start(element) => stack.push(frame(element))
      Empty(element) => {
        let current = frame(element)
        append_content(
          stack,
          roots,
          Element(current.name, current.attributes, []),
        )
      }
      End(name) => {
        let current = match stack.pop() {
          Some(value) => value
          None => raise InvalidSvg("Unexpected closing tag: " + name)
        }
        if current.name != name {
          raise InvalidSvg("Mismatched closing tag: " + name)
        }
        append_content(
          stack,
          roots,
          Element(name, current.attributes, current.children),
        )
      }
      Text(value) | CData(value) =>
        if stack.length() > 0 {
          append_content(stack, roots, Text(value))
        } else if value.trim().length() > 0 {
          raise InvalidSvg("Text outside the SVG root")
        }
      Comment(_) | Decl(..) => ()
      PI(..) | DocType(_) =>
        raise InvalidSvg("Processing instructions and DTDs are unsupported")
      Eof => break
    }
  }
  if stack.length() != 0 || roots.length() != 1 {
    raise InvalidSvg("Expected exactly one complete SVG root")
  }
  match roots[0] {
    Element("svg", _, _) => roots[0]
    _ => raise InvalidSvg("The root element must be svg")
  }
}
