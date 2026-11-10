///|
fn band_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn band_midpoint(
  a : (Double, Double),
  b : (Double, Double),
) -> (Double, Double) {
  (a.0 / 2.0 + b.0 / 2.0, a.1 / 2.0 + b.1 / 2.0)
}

///|
// This runs only for the exact valid segment written by append_fill_segment.
// Splits are in display space: interpolating a data midpoint would choose the
// wrong nearest sample on a logarithmic or otherwise nonlinear primary axis.
fn collect_drawing_band(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  upper : Array[@core.Point],
  lower : Array[@core.Point],
  source_start : Int32,
  scale : Scale,
  position : (Double, Double, Double, Double),
  metadata : @render.HitMetadata,
) -> Unit {
  guard metadata.band_horizontal() is Some(horizontal) else { return }
  let (left, top, width, height) = position
  let ups = upper.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let lows = lower.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let primary = (p : (Double, Double)) => if horizontal { p.1 } else { p.0 }
  // With a strictly monotone shared primary coordinate the emitted SVG polygon
  // is exactly the union of its consecutive strips, including crossed bounds.
  // A backtracking or repeated primary coordinate can change winding; preserve
  // its static polygon, but do not claim a misleading union of hit strips.
  let direction = primary(ups[1]) - primary(ups[0])
  if !band_finite(direction) || direction == 0.0 {
    return
  }
  for index in 0..<ups.length() {
    let up = ups[index]
    let low = lows[index]
    if !band_finite(up.0) ||
      !band_finite(up.1) ||
      !band_finite(low.0) ||
      !band_finite(low.1) ||
      primary(up) != primary(low) {
      return
    }
    if index > 0 {
      let delta = primary(up) - primary(ups[index - 1])
      if !band_finite(delta) ||
        delta == 0.0 ||
        (delta > 0.0) != (direction > 0.0) {
        return
      }
    }
  }
  let infos = Array(capacity=upper.length())
  for index in 0..<upper.length() {
    let up = upper[index]
    let low = lower[index]
    let screen = band_midpoint(ups[index], lows[index])
    let source_index = source_start + index
    let point = @drawing.hit_point(
      panel_index,
      artist_index,
      source_index,
      up.x(),
      up.y(),
      screen.0,
      screen.1,
    )
    let lower = if horizontal { low.x() } else { low.y() }
    let upper = if horizontal { up.x() } else { up.y() }
    let band = @drawing.band_info(
      lower,
      upper,
      horizontal~,
      stacked=metadata.band_stacked(),
    )
    infos.push(
      @drawing.hit_info(
        point,
        @drawing.HitKind::Area,
        value=metadata.band_value(source_index).unwrap_or(upper),
        series=metadata.series(),
        band=Some(band),
      ),
    )
  }
  let used = Array::make(upper.length(), false)
  for index in 0..<(upper.length() - 1) {
    let middle_up = band_midpoint(ups[index], ups[index + 1])
    let middle_low = band_midpoint(lows[index], lows[index + 1])
    for
      (sample, a, b, c, d) in [
        (index, ups[index], middle_up, middle_low, lows[index]),
        (index + 1, middle_up, ups[index + 1], lows[index + 1], middle_low),
      ] {
      if (a == d && b == c) ||
        a.0.min(b.0).min(c.0).min(d.0).max(left) >=
        a.0.max(b.0).max(c.0).max(d.0).min(left + width) ||
        a.1.min(b.1).min(c.1).min(d.1).max(top) >=
        a.1.max(b.1).max(c.1).max(d.1).min(top + height) {
        continue
      }
      used[sample] = true
      output.targets.push(
        @drawing.hit_target(
          infos[sample],
          @drawing.HitShape::Quadrilateral(
            a.0,
            a.1,
            b.0,
            b.1,
            c.0,
            c.1,
            d.0,
            d.1,
          ),
          position,
        ),
      )
    }
  }
  for index, active in used {
    if active {
      output.points.push(infos[index].point)
    }
  }
}
