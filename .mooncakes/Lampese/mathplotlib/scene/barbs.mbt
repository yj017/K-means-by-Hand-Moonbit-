///|
fn validate_barbs_style(
  linewidth : Double,
  barb_length : Double,
) -> Unit raise @core.DataError {
  if linewidth.is_nan() || linewidth.is_inf() || linewidth < 0.0 {
    raise @core.DataError::InvalidQuiver(
      message="barbs linewidth must be finite and non-negative",
    )
  }
  if barb_length.is_nan() || barb_length.is_inf() || barb_length < 0.0 {
    raise @core.DataError::InvalidQuiver(
      message="barb length must be finite and non-negative",
    )
  }
}

///|
fn add_barb_artists(
  axes : Axes,
  source : @render.BarbHitData,
  source_index : Int32,
  x : Double,
  y : Double,
  u : Double,
  v : Double,
  color : String,
  linewidth : Double,
  barb_length : Double,
) -> Unit {
  let magnitude = (u * u + v * v).sqrt()
  if magnitude == 0.0 {
    return
  }
  let unit_x = u / magnitude
  let unit_y = v / magnitude
  let perpendicular_x = -unit_y
  let perpendicular_y = unit_x
  let start = @core.point(x, y)
  let end = @core.point(x + u, y + v)
  let style = @core.style(color, width=linewidth)
  axes.push_barb_component(
    Artist::Line([start, end], style),
    source,
    source_index,
  )
  let wing_length = Double::min(barb_length, magnitude * 0.35)
  if wing_length > 0.0 {
    for index in 1..<=3 {
      let fraction = Double::from_int(index) / 4.0
      let barb_x = end.x() - unit_x * magnitude * fraction
      let barb_y = end.y() - unit_y * magnitude * fraction
      let side = if index % 2 == 0 { -1.0 } else { 1.0 }
      let wing = @core.point(
        barb_x + perpendicular_x * wing_length * side,
        barb_y + perpendicular_y * wing_length * side,
      )
      axes.push_barb_component(
        Artist::Line([@core.point(barb_x, barb_y), wing], style),
        source,
        source_index,
      )
    }
  }
}

///|
/// Draw basic wind barbs for paired data-coordinate vectors.
pub fn Figure::barbs(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  barb_length~ : Double = 0.25,
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().barbs(xs, ys, us, vs, color~, linewidth~, barb_length~, label~)
}

///|
/// Draw basic wind barbs for paired data-coordinate vectors.
pub fn Axes::barbs(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  barb_length~ : Double = 0.25,
  label~ : String = "",
) -> Unit raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  if xs.length() != us.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=us.length(),
    )
  }
  if xs.length() != vs.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=vs.length(),
    )
  }
  validate_barbs_style(linewidth, barb_length)
  let resolved_color = self.resolve_color(color)
  let first_artist = self.state.val.artists.length()
  let source = barb_source(xs, ys, us, vs, label)
  for index in 0..<xs.length() {
    let x = xs[index]
    let y = ys[index]
    let u = us[index]
    let v = vs[index]
    if x.is_nan() || x.is_inf() || y.is_nan() || y.is_inf() {
      raise @core.DataError::NonFiniteLimit(axis="both")
    }
    if u.is_nan() || u.is_inf() || v.is_nan() || v.is_inf() {
      raise @core.DataError::InvalidQuiver(
        message="barb vectors must be finite",
      )
    }
    add_barb_artists(
      self, source, index, x, y, u, v, resolved_color, linewidth, barb_length,
    )
  }
  self.add_auto_legend(
    label,
    resolved_color,
    LegendKind::Line,
    record_series=self.state.val.artists.length() > first_artist,
  )
}

///|
/// Validate the Matplotlib-style magnitude increments used by advanced barbs.
fn validate_barb_increments(
  half_increment : Double,
  full_increment : Double,
  flag_increment : Double,
  pivot : String,
) -> Unit raise @core.DataError {
  if half_increment.is_nan() ||
    half_increment.is_inf() ||
    half_increment <= 0.0 ||
    full_increment.is_nan() ||
    full_increment.is_inf() ||
    full_increment < half_increment ||
    flag_increment.is_nan() ||
    flag_increment.is_inf() ||
    flag_increment < full_increment {
    raise @core.DataError::InvalidQuiver(
      message="barb increments must be finite and ordered positive values",
    )
  }
  if pivot != "tail" && pivot != "middle" && pivot != "tip" {
    raise @core.DataError::InvalidQuiver(
      message="barb pivot must be tail, middle, or tip",
    )
  }
}

///|
fn barb_anchor(
  x : Double,
  y : Double,
  u : Double,
  v : Double,
  pivot : String,
) -> (@core.Point, @core.Point) {
  if pivot == "tip" {
    (@core.point(x - u, y - v), @core.point(x, y))
  } else if pivot == "middle" {
    (
      @core.point(x - u / 2.0, y - v / 2.0),
      @core.point(x + u / 2.0, y + v / 2.0),
    )
  } else {
    (@core.point(x, y), @core.point(x + u, y + v))
  }
}

///|
fn add_barb_flag(
  axes : Axes,
  source : @render.BarbHitData,
  source_index : Int32,
  end : @core.Point,
  unit_x : Double,
  unit_y : Double,
  perpendicular_x : Double,
  perpendicular_y : Double,
  cursor : Double,
  span : Double,
  side : Double,
  style : @core.Style,
) -> Unit {
  let root = @core.point(
    end.x() - unit_x * (cursor + span * 0.1),
    end.y() - unit_y * (cursor + span * 0.1),
  )
  let outer = @core.point(
    end.x() - unit_x * (cursor + span),
    end.y() - unit_y * (cursor + span),
  )
  let tip = @core.point(
    root.x() + perpendicular_x * span * side,
    root.y() + perpendicular_y * span * side,
  )
  axes.push_barb_component(
    Artist::Polygon([root, outer, tip], style),
    source,
    source_index,
  )
}

///|
fn add_barb_advanced_artists(
  axes : Axes,
  source : @render.BarbHitData,
  source_index : Int32,
  x : Double,
  y : Double,
  u : Double,
  v : Double,
  color : String,
  linewidth : Double,
  barb_length : Double,
  half_increment : Double,
  full_increment : Double,
  flag_increment : Double,
  rounding : Bool,
  flip : Bool,
  fill_empty : Bool,
  pivot : String,
) -> Unit raise @core.DataError {
  let magnitude = (u * u + v * v).sqrt()
  if !barb_derived_finite(magnitude) {
    raise @core.DataError::InvalidQuiver(
      message="barb derived magnitude must be finite",
    )
  }
  let (start, end) = barb_anchor(x, y, u, v, pivot)
  let style = @core.style(color, width=linewidth, fill=color)
  if magnitude == 0.0 {
    if fill_empty {
      axes.push_barb_component(
        Artist::Scatter(
          [end],
          @core.style(color, width=linewidth, radius=barb_length * 0.3),
        ),
        source,
        source_index,
      )
    }
    return
  }
  let unit_x = u / magnitude
  let unit_y = v / magnitude
  let perpendicular_x = -unit_y
  let perpendicular_y = unit_x
  let side = if flip { -1.0 } else { 1.0 }
  let effective_magnitude = if rounding {
    (magnitude / half_increment + 0.5).floor() * half_increment
  } else {
    magnitude
  }
  if !barb_derived_finite(effective_magnitude) {
    raise @core.DataError::InvalidQuiver(
      message="barb derived magnitude must be finite",
    )
  }
  if effective_magnitude < half_increment {
    if fill_empty {
      axes.push_barb_component(
        Artist::Scatter(
          [end],
          @core.style(color, width=linewidth, radius=barb_length * 0.3),
        ),
        source,
        source_index,
      )
    }
    return
  }
  let (flag_count, full_count, half_count) = checked_barb_counts(
    effective_magnitude,
    half_increment,
    full_increment,
    flag_increment,
    axes.state.val.artists.length(),
  )
  axes.push_barb_component(
    Artist::Line([start, end], style),
    source,
    source_index,
  )
  let span = Double::min(barb_length, magnitude * 0.35)
  let mut cursor = 0.0
  for _ in 0..<flag_count {
    add_barb_flag(
      axes, source, source_index, end, unit_x, unit_y, perpendicular_x, perpendicular_y,
      cursor, span, side, style,
    )
    cursor += span * 0.9
  }
  for _ in 0..<full_count {
    let root = @core.point(end.x() - unit_x * cursor, end.y() - unit_y * cursor)
    let wing = @core.point(
      root.x() + perpendicular_x * span * side,
      root.y() + perpendicular_y * span * side,
    )
    axes.push_barb_component(
      Artist::Line([root, wing], style),
      source,
      source_index,
    )
    cursor += span * 0.9
  }
  if half_count > 0 {
    let root = @core.point(end.x() - unit_x * cursor, end.y() - unit_y * cursor)
    let wing = @core.point(
      root.x() + perpendicular_x * span * 0.5 * side,
      root.y() + perpendicular_y * span * 0.5 * side,
    )
    axes.push_barb_component(
      Artist::Line([root, wing], style),
      source,
      source_index,
    )
  }
}

///|
/// Draw wind barbs with magnitude increments, pivot, flip, and calm-barb
/// options. The default increments match Matplotlib's half/full/flag values.
pub fn Figure::barbs_with_options(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  barb_length~ : Double = 0.25,
  label~ : String = "",
  half_increment~ : Double = 5.0,
  full_increment~ : Double = 10.0,
  flag_increment~ : Double = 50.0,
  rounding~ : Bool = true,
  flip~ : Bool = false,
  fill_empty~ : Bool = true,
  pivot~ : String = "tail",
) -> Unit raise @core.DataError {
  self
  .axes()
  .barbs_with_options(
    xs,
    ys,
    us,
    vs,
    color~,
    linewidth~,
    barb_length~,
    label~,
    half_increment~,
    full_increment~,
    flag_increment~,
    rounding~,
    flip~,
    fill_empty~,
    pivot~,
  )
}

///|
/// Draw wind barbs with magnitude increments, pivot, flip, and calm-barb
/// options. The default increments match Matplotlib's half/full/flag values.
pub fn Axes::barbs_with_options(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  barb_length~ : Double = 0.25,
  label~ : String = "",
  half_increment~ : Double = 5.0,
  full_increment~ : Double = 10.0,
  flag_increment~ : Double = 50.0,
  rounding~ : Bool = true,
  flip~ : Bool = false,
  fill_empty~ : Bool = true,
  pivot~ : String = "tail",
) -> Unit raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  if xs.length() != us.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=us.length(),
    )
  }
  if xs.length() != vs.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=vs.length(),
    )
  }
  validate_barbs_style(linewidth, barb_length)
  validate_barb_increments(
    half_increment, full_increment, flag_increment, pivot,
  )
  let resolved_color = self.resolve_color(color)
  let first_artist = self.state.val.artists.length()
  let source = barb_source(xs, ys, us, vs, label)
  for index in 0..<xs.length() {
    let x = xs[index]
    let y = ys[index]
    let u = us[index]
    let v = vs[index]
    if x.is_nan() || x.is_inf() || y.is_nan() || y.is_inf() {
      raise @core.DataError::NonFiniteLimit(axis="both")
    }
    if u.is_nan() || u.is_inf() || v.is_nan() || v.is_inf() {
      raise @core.DataError::InvalidQuiver(
        message="barb vectors must be finite",
      )
    }
    add_barb_advanced_artists(
      self, source, index, x, y, u, v, resolved_color, linewidth, barb_length, half_increment,
      full_increment, flag_increment, rounding, flip, fill_empty, pivot,
    )
  }
  self.add_auto_legend(
    label,
    resolved_color,
    LegendKind::Line,
    record_series=self.state.val.artists.length() > first_artist,
  )
}
