///|
fn colorbar_float(value : Double) -> String {
  Double::to_string(value)
}

///|
fn colorbar_tick_value(norm : @colors.ColorNorm, ratio : Double) -> Double {
  match norm {
    @colors.ColorNorm::Boundary(boundary) => {
      let values = boundary.boundaries()
      let position = ratio * Double::from_int(values.length() - 1)
      values[Int32::min(values.length() - 1, Int32::max(0, position.to_int()))]
    }
    _ => try! norm.inverse(ratio)
  }
}

///|
fn colorbar_extensions(norm : @colors.ColorNorm) -> (Bool, Bool) {
  match norm {
    @colors.ColorNorm::Boundary(boundary) => {
      let mode = boundary.extend_mode()
      (mode == "min" || mode == "both", mode == "max" || mode == "both")
    }
    _ => (false, false)
  }
}

///|
fn colorbar_ticks(
  norm : @colors.ColorNorm,
  count : Int32,
) -> Array[(Double, Double)] {
  match norm {
    @colors.ColorNorm::Boundary(boundary) => {
      let values = boundary.boundaries()
      let result : Array[(Double, Double)] = []
      if values.length() == 1 {
        result.push((0.0, values[0]))
      } else {
        for index in 0..<values.length() {
          result.push(
            (
              Double::from_int(index) / Double::from_int(values.length() - 1),
              values[index],
            ),
          )
        }
      }
      result
    }
    _ => {
      let result : Array[(Double, Double)] = []
      let actual_count = Int32::max(2, count)
      for tick in 0..<actual_count {
        let ratio = Double::from_int(tick) / Double::from_int(actual_count - 1)
        result.push((ratio, colorbar_tick_value(norm, ratio)))
      }
      result
    }
  }
}

///|
fn append_colorbar_vertical(
  writer : @xml.Writer,
  figure : @render.Figure,
  bar : @colorbar.Colorbar,
  index : Int32,
) -> Unit {
  let width = 16.0
  let left = Double::from_int(figure.width() - figure.margin()) +
    22.0 +
    Double::from_int(index) * 48.0
  let top = Double::from_int(figure.margin())
  let height = Double::from_int(figure.height() - figure.margin() * 2)
  let steps = 64
  for step in 0..<steps {
    let ratio = 1.0 - Double::from_int(step) / Double::from_int(steps - 1)
    let y = top + Double::from_int(step) / Double::from_int(steps) * height
    try! writer.empty_element("rect", [
      ("x", float_text(left)),
      ("y", float_text(y)),
      ("width", float_text(width)),
      ("height", float_text(height / Double::from_int(steps) + 1.0)),
      ("fill", bar.cmap().sample(ratio).to_css()),
      ("stroke", "none"),
    ])
  }
  let (extend_min, extend_max) = colorbar_extensions(bar.norm())
  if extend_max {
    try! writer.empty_element("polygon", [
      (
        "points",
        float_text(left) +
        "," +
        float_text(top) +
        " " +
        float_text(left + width) +
        "," +
        float_text(top) +
        " " +
        float_text(left + width / 2.0) +
        "," +
        float_text(top - 7.0),
      ),
      ("fill", bar.cmap().sample_extended(1.1).to_css()),
      ("stroke", "none"),
    ])
  }
  if extend_min {
    let bottom = top + height
    try! writer.empty_element("polygon", [
      (
        "points",
        float_text(left) +
        "," +
        float_text(bottom) +
        " " +
        float_text(left + width) +
        "," +
        float_text(bottom) +
        " " +
        float_text(left + width / 2.0) +
        "," +
        float_text(bottom + 7.0),
      ),
      ("fill", bar.cmap().sample_extended(-0.1).to_css()),
      ("stroke", "none"),
    ])
  }
  try! writer.empty_element("rect", [
    ("x", float_text(left)),
    ("y", float_text(top)),
    ("width", float_text(width)),
    ("height", float_text(height)),
    ("fill", "none"),
    ("stroke", "#374151"),
    ("stroke-width", "1"),
  ])
  if bar.norm().scaled() {
    for (ratio, value) in colorbar_ticks(bar.norm(), bar.tick_count()) {
      let y = top + (1.0 - ratio) * height
      try! writer.empty_element("line", [
        ("x1", float_text(left + width)),
        ("y1", float_text(y)),
        ("x2", float_text(left + width + 5.0)),
        ("y2", float_text(y)),
        ("stroke", "#374151"),
        ("stroke-width", "1"),
      ])
      append_text(
        writer,
        left + width + 8.0,
        y + 3.0,
        colorbar_float(value),
        "start",
        10,
      )
    }
  }
  match bar.label() {
    Some(value) =>
      append_text(
        writer,
        left + width + 42.0,
        top + height / 2.0,
        value,
        "middle",
        12,
      )
    None => ()
  }
}

///|
fn append_colorbar_horizontal(
  writer : @xml.Writer,
  figure : @render.Figure,
  bar : @colorbar.Colorbar,
  index : Int32,
) -> Unit {
  let left = Double::from_int(figure.margin())
  let top = Double::from_int(figure.height() - figure.margin()) +
    24.0 +
    Double::from_int(index) * 48.0
  let width = Double::from_int(figure.width() - figure.margin() * 2)
  let height = 16.0
  let steps = 64
  for step in 0..<steps {
    let ratio = Double::from_int(step) / Double::from_int(steps - 1)
    let x = left + ratio * width
    try! writer.empty_element("rect", [
      ("x", float_text(x)),
      ("y", float_text(top)),
      ("width", float_text(width / Double::from_int(steps) + 1.0)),
      ("height", float_text(height)),
      ("fill", bar.cmap().sample(ratio).to_css()),
      ("stroke", "none"),
    ])
  }
  let (extend_min, extend_max) = colorbar_extensions(bar.norm())
  if extend_min {
    try! writer.empty_element("polygon", [
      (
        "points",
        float_text(left) +
        "," +
        float_text(top) +
        " " +
        float_text(left) +
        "," +
        float_text(top + height) +
        " " +
        float_text(left - 7.0) +
        "," +
        float_text(top + height / 2.0),
      ),
      ("fill", bar.cmap().sample_extended(-0.1).to_css()),
      ("stroke", "none"),
    ])
  }
  if extend_max {
    let right = left + width
    try! writer.empty_element("polygon", [
      (
        "points",
        float_text(right) +
        "," +
        float_text(top) +
        " " +
        float_text(right) +
        "," +
        float_text(top + height) +
        " " +
        float_text(right + 7.0) +
        "," +
        float_text(top + height / 2.0),
      ),
      ("fill", bar.cmap().sample_extended(1.1).to_css()),
      ("stroke", "none"),
    ])
  }
  try! writer.empty_element("rect", [
    ("x", float_text(left)),
    ("y", float_text(top)),
    ("width", float_text(width)),
    ("height", float_text(height)),
    ("fill", "none"),
    ("stroke", "#374151"),
    ("stroke-width", "1"),
  ])
  if bar.norm().scaled() {
    for (ratio, value) in colorbar_ticks(bar.norm(), bar.tick_count()) {
      let x = left + ratio * width
      try! writer.empty_element("line", [
        ("x1", float_text(x)),
        ("y1", float_text(top + height)),
        ("x2", float_text(x)),
        ("y2", float_text(top + height + 5.0)),
        ("stroke", "#374151"),
        ("stroke-width", "1"),
      ])
      append_text(
        writer,
        x,
        top + height + 17.0,
        colorbar_float(value),
        "middle",
        10,
      )
    }
  }
  match bar.label() {
    Some(value) =>
      append_text(
        writer,
        left + width / 2.0,
        top + height + 34.0,
        value,
        "middle",
        12,
      )
    None => ()
  }
}

///|
fn append_colorbar(
  writer : @xml.Writer,
  figure : @render.Figure,
  bar : @colorbar.Colorbar,
  index : Int32,
) -> Unit {
  match bar.orientation() {
    @colorbar.Orientation::Vertical =>
      append_colorbar_vertical(writer, figure, bar, index)
    @colorbar.Orientation::Horizontal =>
      append_colorbar_horizontal(writer, figure, bar, index)
  }
}
