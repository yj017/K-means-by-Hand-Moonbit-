///|
fn append_text(
  writer : @xml.Writer,
  x : Double,
  y : Double,
  value : String,
  anchor : String,
  size : Double,
) -> Unit {
  try! writer.start_element("text", [
    ("x", float_text(x)),
    ("y", float_text(y)),
    ("text-anchor", anchor),
    ("font-family", "sans-serif"),
    ("font-size", float_text(size)),
  ])
  try! writer.text(value)
  try! writer.end_element("text")
}

///|
fn append_artist_text(
  writer : @xml.Writer,
  x : Double,
  y : Double,
  value : String,
  style : @core.Style,
) -> Unit {
  try! writer.start_element("text", [
    ("x", float_text(x)),
    ("y", float_text(y)),
    ("text-anchor", "start"),
    ("font-family", "sans-serif"),
    ("font-size", style.font_size().to_string()),
    ("fill", style.color()),
  ])
  try! writer.text(value)
  try! writer.end_element("text")
}

///|
fn annotation_coordinate_point(
  coordinate : String,
  x : Double,
  y : Double,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  figure_width : Double,
  figure_height : Double,
) -> @core.Point? {
  if coordinate == "data" {
    if valid_point(scale, @core.point(x, y)) {
      Some(
        @core.point(
          map_x(scale, left, plot_width, x),
          map_y(scale, top, plot_height, y),
        ),
      )
    } else {
      None
    }
  } else if coordinate == "axes fraction" {
    Some(@core.point(left + x * plot_width, top + (1.0 - y) * plot_height))
  } else if coordinate == "figure fraction" {
    Some(@core.point(x * figure_width, (1.0 - y) * figure_height))
  } else if coordinate == "display" {
    Some(@core.point(x, y))
  } else {
    None
  }
}

///|
fn annotation_path(
  connector : String,
  start : @core.Point,
  end : @core.Point,
) -> String {
  let result = StringBuilder()
  if connector == "arc3" {
    let control_x = (start.x() + end.x()) / 2.0
    let control_y = (start.y() + end.y()) / 2.0 -
      Double::abs(end.x() - start.x()) * 0.15
    result.write_string("M ")
    result.write_string(float_text(start.x()))
    result.write_string(" ")
    result.write_string(float_text(start.y()))
    result.write_string(" Q ")
    result.write_string(float_text(control_x))
    result.write_string(" ")
    result.write_string(float_text(control_y))
    result.write_string(" ")
    result.write_string(float_text(end.x()))
    result.write_string(" ")
    result.write_string(float_text(end.y()))
  } else {
    result.write_string("M ")
    result.write_string(float_text(start.x()))
    result.write_string(" ")
    result.write_string(float_text(start.y()))
    result.write_string(" L ")
    result.write_string(float_text(end.x()))
    result.write_string(" ")
    result.write_string(float_text(end.y()))
  }
  result.to_string()
}

///|
fn append_annotation_arrowhead(
  writer : @xml.Writer,
  tail : @core.Point,
  tip : @core.Point,
  color : String,
  linewidth : Double,
  head_length : Double,
  head_width : Double,
) -> Unit {
  let dx = tip.x() - tail.x()
  let dy = tip.y() - tail.y()
  let magnitude = (dx * dx + dy * dy).sqrt()
  if magnitude == 0.0 {
    return
  }
  let length = Double::min(head_length, magnitude)
  if length == 0.0 || head_width == 0.0 {
    return
  }
  let unit_x = dx / magnitude
  let unit_y = dy / magnitude
  let base_x = tip.x() - unit_x * length
  let base_y = tip.y() - unit_y * length
  let half_width = head_width / 2.0
  let left_x = base_x - unit_y * half_width
  let left_y = base_y + unit_x * half_width
  let right_x = base_x + unit_y * half_width
  let right_y = base_y - unit_x * half_width
  try! writer.empty_element("polygon", [
    (
      "points",
      marker_polygon_points([left_x, left_y, tip.x(), tip.y(), right_x, right_y]),
    ),
    ("fill", color),
    ("stroke", color),
    ("stroke-width", float_text(linewidth)),
  ])
}

///|
fn append_annotation(
  writer : @xml.Writer,
  figure : @render.Figure,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  annotation : @render.Annotation,
) -> Unit {
  let figure_width = Double::from_int(figure.width())
  let figure_height = Double::from_int(figure.height())
  let anchor = annotation_coordinate_point(
    annotation.xycoords(),
    annotation.x(),
    annotation.y(),
    scale,
    left,
    top,
    plot_width,
    plot_height,
    figure_width,
    figure_height,
  )
  let text = match anchor {
    None => None
    Some(anchor) =>
      if annotation.textcoords() == "offset points" {
        Some(
          @core.point(
            anchor.x() + annotation.text_x() * 4.0 / 3.0,
            anchor.y() - annotation.text_y() * 4.0 / 3.0,
          ),
        )
      } else if annotation.textcoords() == "offset pixels" {
        Some(
          @core.point(
            anchor.x() + annotation.text_x(),
            anchor.y() + annotation.text_y(),
          ),
        )
      } else {
        annotation_coordinate_point(
          annotation.textcoords(),
          annotation.text_x(),
          annotation.text_y(),
          scale,
          left,
          top,
          plot_width,
          plot_height,
          figure_width,
          figure_height,
        )
      }
  }
  match (anchor, text) {
    (Some(anchor), Some(text)) => {
      if annotation.arrow() {
        let connector = annotation.connector()
        if connector == "angle" {
          let elbow = @core.point(anchor.x(), text.y())
          try! writer.empty_element("polyline", [
            ("fill", "none"),
            ("stroke", annotation.arrowcolor()),
            ("stroke-width", float_text(annotation.linewidth())),
            (
              "points",
              marker_polygon_points([
                text.x(),
                text.y(),
                elbow.x(),
                elbow.y(),
                anchor.x(),
                anchor.y(),
              ]),
            ),
          ])
          append_annotation_arrowhead(
            writer,
            elbow,
            anchor,
            annotation.arrowcolor(),
            annotation.linewidth(),
            annotation.head_length(),
            annotation.head_width(),
          )
        } else {
          try! writer.empty_element("path", [
            ("d", annotation_path(connector, text, anchor)),
            ("fill", "none"),
            ("stroke", annotation.arrowcolor()),
            ("stroke-width", float_text(annotation.linewidth())),
          ])
          append_annotation_arrowhead(
            writer,
            text,
            anchor,
            annotation.arrowcolor(),
            annotation.linewidth(),
            annotation.head_length(),
            annotation.head_width(),
          )
        }
      }
      append_artist_text(
        writer,
        text.x(),
        text.y(),
        annotation.value(),
        annotation.style(),
      )
    }
    _ => ()
  }
}
