///|
priv struct DrawingCapture {
  points : Array[@drawing.HitPoint]
  targets : Array[@drawing.HitTarget]
  exclusions : Array[(Int32, (Double, Double, Double, Double))]
  polar_circles : Array[(Int32, (Double, Double, Double))]
}

///|
/// Use the ordinary SVG draw once, retaining exact document and semantic targets.
pub fn render_drawing_with_positions_checked(
  figure : @render.Figure,
) -> (@drawing.Drawing, Array[(Double, Double, Double, Double)]) raise @core.DataError {
  let capture : DrawingCapture = {
    points: [],
    targets: [],
    exclusions: [],
    polar_circles: [],
  }
  let (document, positions) = render_with_hits_checked(figure, Some(capture))
  (
    @drawing.drawing(
      figure.width(),
      figure.height(),
      document,
      capture.points,
      targets=capture.targets,
      exclusions=capture.exclusions,
      polar_circles=capture.polar_circles,
    ),
    positions,
  )
}

///|
fn drawing_category(axis : @axis.Axis, value : Double) -> String? {
  guard axis.get_category_units() is Some(units) else { return None }
  let labels = units.labels()
  for index, label in labels {
    if value == index.to_double() {
      return Some(label)
    }
  }
  None
}

///|
fn drawing_point_category(
  panel : @render.Panel,
  point : @core.Point,
  horizontal : Bool,
) -> String? {
  let preferred = if horizontal {
    drawing_category(panel.y_axis(), point.y())
  } else {
    drawing_category(panel.x_axis(), point.x())
  }
  match preferred {
    Some(_) => preferred
    None =>
      if horizontal {
        drawing_category(panel.x_axis(), point.x())
      } else {
        drawing_category(panel.y_axis(), point.y())
      }
  }
}

///|
fn drawing_point_value(panel : @render.Panel, point : @core.Point) -> Double {
  if panel.x_axis().get_category_units() is None &&
    panel.y_axis().get_category_units() is Some(_) {
    point.x()
  } else {
    point.y()
  }
}

///|
// Collect at the actual data draw stage. Original samples survive invalid-point
// filtering and step-path expansion; category labels come from the live axis.
fn collect_drawing_points(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  points : Array[@core.Point],
  scale : Scale,
  position : (Double, Double, Double, Double),
  panel : @render.Panel,
  metadata : @render.HitMetadata,
  kind : @drawing.HitKind,
  count? : Int32,
) -> Unit {
  let (left, top, width, height) = position
  let length = count.unwrap_or(points.length())
  for index in 0..<length {
    let point = points[index]
    if !valid_point(scale, point) {
      continue
    }
    let x = map_x(scale, left, width, point.x())
    let y = map_y(scale, top, height, point.y())
    if x.is_nan() ||
      x.is_inf() ||
      y.is_nan() ||
      y.is_inf() ||
      x < left ||
      x > left + width ||
      y < top ||
      y > top + height {
      continue
    }
    let hit = @drawing.hit_point(
      panel_index,
      artist_index,
      index,
      point.x(),
      point.y(),
      x,
      y,
    )
    let info = @drawing.hit_info(
      hit,
      kind,
      value=drawing_point_value(panel, point),
      series=metadata.series(),
      category=drawing_point_category(panel, point, false),
    )
    output.points.push(hit)
    output.targets.push(
      @drawing.hit_target(info, @drawing.HitShape::Point, position),
    )
  }
}

///|
fn collect_drawing_bar(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  rectangle : RenderedBar,
  panel : @render.Panel,
  metadata : @render.HitMetadata,
  position : (Double, Double, Double, Double),
  horizontal : Bool,
) -> Unit {
  let (left, top, width, height) = position
  let x0 = Double::max(rectangle.left, left)
  let y0 = Double::max(rectangle.top, top)
  let x1 = Double::min(rectangle.left + rectangle.width, left + width)
  let y1 = Double::min(rectangle.top + rectangle.height, top + height)
  if x0.is_nan() ||
    y0.is_nan() ||
    x1.is_nan() ||
    y1.is_nan() ||
    x0.is_inf() ||
    y0.is_inf() ||
    x1.is_inf() ||
    y1.is_inf() ||
    x1 <= x0 ||
    y1 <= y0 {
    return
  }
  let point = rectangle.point
  let hit = @drawing.hit_point(
    panel_index,
    artist_index,
    rectangle.source_index,
    point.x(),
    point.y(),
    (x0 + x1) / 2.0,
    (y0 + y1) / 2.0,
  )
  let interval = metadata.interval(rectangle.source_index)
  let kind = if interval is Some(_) {
    @drawing.HitKind::Histogram
  } else if horizontal {
    @drawing.HitKind::BarH
  } else {
    @drawing.HitKind::Bar
  }
  let value = match rectangle.segment {
    Some(segment) => segment.value
    None => if horizontal { point.x() } else { point.y() }
  }
  let category = match rectangle.segment {
    Some(segment) => segment.category
    None => drawing_point_category(panel, point, horizontal)
  }
  let info = @drawing.hit_info(
    hit,
    kind,
    value~,
    series=metadata.series(),
    category~,
    interval~,
  )
  output.points.push(hit)
  output.targets.push(
    @drawing.hit_target(
      info,
      @drawing.HitShape::Rectangle(
        rectangle.left,
        rectangle.top,
        rectangle.width,
        rectangle.height,
      ),
      position,
    ),
  )
}

///|
fn collect_drawing_pie(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  index : Int32,
  value : Double,
  labels : Array[String],
  series : String,
  cx : Double,
  cy : Double,
  radius : Double,
  start : Double,
  sweep : Double,
  fraction : Double,
  position : (Double, Double, Double, Double),
) -> Unit {
  let (x, y) = pie_point(cx, cy, radius * 0.65, start + sweep / 2.0)
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    index,
    index.to_double(),
    value,
    x,
    y,
  )
  let category = if index < labels.length() {
    Some(labels[index])
  } else {
    None
  }
  let info = @drawing.hit_info(
    point,
    @drawing.HitKind::Pie,
    value~,
    series~,
    category~,
    fraction=Some(fraction),
  )
  output.points.push(point)
  output.targets.push(
    @drawing.hit_target(
      info,
      @drawing.HitShape::Sector(cx, cy, radius, start, sweep),
      position,
    ),
  )
}
