///|
fn collect_drawing_stairs_face(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  visible : Array[@core.Point],
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  metadata : @render.HitMetadata,
  style : @core.Style,
) -> Unit {
  guard metadata.discrete() is Some(source) else { return }
  let fill = if style.fill() == "" { style.color() } else { style.fill() }
  if source.kind != Stairs ||
    source.datum_count() == 0 ||
    !discrete_effective_paint_visible(fill) ||
    !source.matches_path(visible) {
    return
  }
  let (left, top, width, height) = bounds
  // Deleting even one invalid vertex can connect unrelated plateaus with a
  // diagonal closing edge. The full original polygon must remain intact.
  for p in visible {
    if !valid_point(scale, p) ||
      !violin_screen_finite(map_x(scale, left, width, p.x())) ||
      !violin_screen_finite(map_y(scale, top, height, p.y())) {
      return
    }
  }
  let first = source.datum(0).unwrap()
  guard first.band is Some(first_band) else { return }
  guard first.interval is Some((first_start, first_end)) else { return }
  let direction = first_end - first_start
  if !violin_screen_finite(direction) || direction == 0.0 {
    return
  }
  let mut previous = first_start
  let primary = (value : Double) => {
    if first_band.horizontal {
      map_y(scale, top, height, value)
    } else {
      map_x(scale, left, width, value)
    }
  }
  let screen_direction = primary(first_end) - primary(first_start)
  if !violin_screen_finite(screen_direction) || screen_direction == 0.0 {
    return
  }
  for i in 0..<source.datum_count() {
    let datum = source.datum(i).unwrap()
    guard datum.interval is Some((a, b)) else { return }
    guard datum.band is Some(band) else { return }
    let delta = b - a
    let screen_delta = primary(b) - primary(a)
    if a != previous ||
      band.horizontal != first_band.horizontal ||
      band.lower != first_band.lower ||
      band.upper != datum.value ||
      !violin_screen_finite(a) ||
      !violin_screen_finite(b) ||
      !violin_screen_finite(delta) ||
      delta == 0.0 ||
      (delta > 0.0) != (direction > 0.0) ||
      !violin_screen_finite(screen_delta) ||
      screen_delta == 0.0 ||
      (screen_delta > 0.0) != (screen_direction > 0.0) ||
      !violin_screen_finite(datum.value) ||
      !violin_screen_finite(band.lower) {
      return
    }
    previous = b
  }
  for i in 0..<source.datum_count() {
    let datum = source.datum(i).unwrap()
    let (start, end) = datum.interval.unwrap()
    let band = datum.band.unwrap()
    let (x0, x1, y0, y1) = if band.horizontal {
      (
        map_x(scale, left, width, band.lower),
        map_x(scale, left, width, band.upper),
        map_y(scale, top, height, start),
        map_y(scale, top, height, end),
      )
    } else {
      (
        map_x(scale, left, width, start),
        map_x(scale, left, width, end),
        map_y(scale, top, height, band.lower),
        map_y(scale, top, height, band.upper),
      )
    }
    if !violin_screen_finite(x0) ||
      !violin_screen_finite(x1) ||
      !violin_screen_finite(y0) ||
      !violin_screen_finite(y1) {
      continue
    }
    let xmin = x0.min(x1)
    let xmax = x0.max(x1)
    let ymin = y0.min(y1)
    let ymax = y0.max(y1)
    let clipped_left = xmin.max(left)
    let clipped_right = xmax.min(left + width)
    let clipped_top = ymin.max(top)
    let clipped_bottom = ymax.min(top + height)
    if clipped_left >= clipped_right || clipped_top >= clipped_bottom {
      continue
    }
    let info = discrete_info(
      datum,
      Stairs,
      panel_index,
      artist_index,
      metadata.series(),
      clipped_left / 2.0 + clipped_right / 2.0,
      clipped_top / 2.0 + clipped_bottom / 2.0,
    )
    output.points.push(info.point)
    output.targets.push(
      @drawing.hit_target(
        info,
        Rectangle(xmin, ymin, xmax - xmin, ymax - ymin),
        bounds,
      ),
    )
  }
}
