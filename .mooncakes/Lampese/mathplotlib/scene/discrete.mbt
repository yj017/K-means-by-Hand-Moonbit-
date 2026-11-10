///|
fn discrete_error(message : String) -> @core.DataError {
  @core.DataError::InvalidReference(message~)
}

///|
fn finite_discrete(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn stem_locations(
  heads : Array[Double],
  locs : Array[Double],
) -> Array[Double] raise @core.DataError {
  if locs.length() == 0 {
    let result = Array(capacity=heads.length())
    for index in 0..<heads.length() {
      result.push(Double::from_int(index))
    }
    result
  } else {
    if locs.length() != heads.length() {
      raise @core.DataError::LengthMismatch(
        expected=heads.length(),
        actual=locs.length(),
      )
    }
    locs.copy()
  }
}

///|
/// Draw stems from a baseline to each scalar head.
pub fn Figure::stem(
  self : Figure,
  heads : Array[Double],
  locs~ : Array[Double] = [],
  bottom~ : Double = 0.0,
  orientation~ : String = "vertical",
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().stem(heads, locs~, bottom~, orientation~, color~, label~)
}

///|
/// Draw stems through the axes view.
pub fn Axes::stem(
  self : Axes,
  heads : Array[Double],
  locs~ : Array[Double] = [],
  bottom~ : Double = 0.0,
  orientation~ : String = "vertical",
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if orientation != "vertical" && orientation != "horizontal" {
    raise discrete_error("stem orientation must be vertical or horizontal")
  }
  if !finite_discrete(bottom) {
    raise @core.DataError::NonFiniteLimit(
      axis=if orientation == "vertical" { "y" } else { "x" },
    )
  }
  let locations = stem_locations(heads, locs)
  let source = @render.stem_hit_data(
    heads,
    locations,
    bottom,
    orientation == "horizontal",
  ).unwrap()
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  let markers = Array(capacity=heads.length())
  for index in 0..<heads.length() {
    let head = heads[index]
    let location = locations[index]
    if orientation == "vertical" {
      self.push_artist(
        Artist::Line(
          [@core.point(location, bottom), @core.point(location, head)],
          @core.style(resolved_color),
        ),
      )
      markers.push(@core.point(location, head))
    } else {
      self.push_artist(
        Artist::Line(
          [@core.point(bottom, location), @core.point(head, location)],
          @core.style(resolved_color),
        ),
      )
      markers.push(@core.point(head, location))
    }
    self.record_stem_hit(source.view(rod=Some(index)), label)
  }
  if orientation == "vertical" {
    self.push_artist(Artist::HLine(bottom, @core.style(resolved_color)))
  } else {
    self.push_artist(Artist::VLine(bottom, @core.style(resolved_color)))
  }
  self.push_artist(
    Artist::Scatter(markers, @core.style(resolved_color, width=0.0, radius=3.5)),
  )
  self.record_stem_hit(source.view(), label)
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
  self.add_container(ContainerKind::Stem, start, label)
}

///|
fn event_value(
  values : Array[Double],
  index : Int32,
  fallback : Double,
) -> Double {
  if values.length() == 0 {
    fallback
  } else if values.length() == 1 {
    values[0]
  } else {
    values[index]
  }
}

///|
/// Draw parallel event markers for one or more sequences of positions.
pub fn Figure::eventplot(
  self : Figure,
  positions : Array[Array[Double]],
  orientation~ : String = "horizontal",
  lineoffsets~ : Array[Double] = [],
  linelengths~ : Array[Double] = [],
  linewidth~ : Double = 1.0,
  color~ : String = "",
) -> Unit raise @core.DataError {
  self
  .axes()
  .eventplot(
    positions,
    orientation~,
    lineoffsets~,
    linelengths~,
    linewidth~,
    color~,
  )
}

///|
/// Draw parallel event markers through the axes view.
pub fn Axes::eventplot(
  self : Axes,
  positions : Array[Array[Double]],
  orientation~ : String = "horizontal",
  lineoffsets~ : Array[Double] = [],
  linelengths~ : Array[Double] = [],
  linewidth~ : Double = 1.0,
  color~ : String = "",
) -> Unit raise @core.DataError {
  if orientation != "horizontal" && orientation != "vertical" {
    raise discrete_error("eventplot orientation must be horizontal or vertical")
  }
  if !finite_discrete(linewidth) || linewidth < 0.0 {
    raise discrete_error("eventplot linewidth must be finite and non-negative")
  }
  if lineoffsets.length() != 0 &&
    lineoffsets.length() != 1 &&
    lineoffsets.length() != positions.length() {
    raise @core.DataError::LengthMismatch(
      expected=positions.length(),
      actual=lineoffsets.length(),
    )
  }
  if linelengths.length() != 0 &&
    linelengths.length() != 1 &&
    linelengths.length() != positions.length() {
    raise @core.DataError::LengthMismatch(
      expected=positions.length(),
      actual=linelengths.length(),
    )
  }
  let resolved_color = self.resolve_color(color)
  for group_index, group in positions {
    let offset = if lineoffsets.length() == 0 {
      if positions.length() == 1 {
        1.0
      } else {
        Double::from_int(group_index)
      }
    } else if lineoffsets.length() == 1 && positions.length() > 1 {
      Double::from_int(group_index) * lineoffsets[0]
    } else {
      lineoffsets[group_index]
    }
    let length = event_value(linelengths, group_index, 1.0)
    if !finite_discrete(offset) || !finite_discrete(length) || length < 0.0 {
      raise discrete_error("eventplot offsets and lengths must be finite")
    }
    for position in group {
      if !finite_discrete(position) {
        continue
      }
      if orientation == "horizontal" {
        self.push_artist(
          Artist::Line(
            [
              @core.point(position, offset - length / 2.0),
              @core.point(position, offset + length / 2.0),
            ],
            @core.style(resolved_color, width=linewidth),
          ),
        )
      } else {
        self.push_artist(
          Artist::Line(
            [
              @core.point(offset - length / 2.0, position),
              @core.point(offset + length / 2.0, position),
            ],
            @core.style(resolved_color, width=linewidth),
          ),
        )
      }
    }
  }
}
