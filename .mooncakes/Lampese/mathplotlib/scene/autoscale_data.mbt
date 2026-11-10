///|
fn empty_data_interval() -> @core.Limits {
  @core.limits(1.0 / 0.0, -1.0 / 0.0)
}

///|
fn merge_data_interval(
  old : @core.Limits,
  fresh : @core.Limits,
  ignore : Bool,
) -> @core.Limits {
  if ignore {
    fresh
  } else {
    @core.limits(
      Double::min(old.lower(), fresh.lower()),
      Double::max(old.upper(), fresh.upper()),
    )
  }
}

///|
fn Axes::update_artist_data_limits(self : Axes, artist : Artist) -> Unit {
  let (update_x, update_y) = match artist {
    Artist::Text(_, _, _, _)
    | Artist::Annotation(_)
    | Artist::Table(_)
    | Artist::Pie(_, _, _, _)
    | Artist::Donut(_, _, _, _, _) => return
    Artist::HLine(_, _) | Artist::HSpan(_, _, _) => (false, true)
    Artist::VLine(_, _) | Artist::VSpan(_, _, _) => (true, false)
    _ => (true, true)
  }
  let artists = [to_render_artist(artist)]
  let x = @svg.artist_data_interval(artists, true)
  let y = @svg.artist_data_interval(artists, false)
  // Line paths consume ignore even if every nonempty vertex is nonfinite.
  // Collection/image dataLim updates instead reject fully empty/nonfinite Bbox.
  let consume = match artist {
    Artist::Line(points, _) => !points.is_empty()
    Artist::HLine(_, _) | Artist::VLine(_, _) | Artist::AxLine(_, _, _) => true
    _ => x.lower() <= x.upper() || y.lower() <= y.upper()
  }
  if !consume {
    return
  }
  let state = self.state.val
  let ignore = state.ignore_existing_data_limits
  if update_x {
    state.raw_x_data = merge_data_interval(state.raw_x_data, x, ignore)
    let value = @svg.artist_minpos(artists, true)
    state.x_data_minpos = if ignore {
      value
    } else {
      Double::min(state.x_data_minpos, value)
    }
  }
  if update_y {
    state.raw_y_data = merge_data_interval(state.raw_y_data, y, ignore)
    let value = @svg.artist_minpos(artists, false)
    state.y_data_minpos = if ignore {
      value
    } else {
      Double::min(state.y_data_minpos, value)
    }
  }
  state.ignore_existing_data_limits = false
}

///|
/// Rebuild cached data limits from the currently attached geometry.
/// This does not request a view update or enable autoscaling.
/// Optionally skip hidden registered Lines before querying their pending data.
pub fn Axes::relim(self : Axes, visible_only~ : Bool = false) -> Unit {
  try! self.relim_checked(visible_only~)
}

///|
/// Rebuild data limits in artist order, retaining a merged prefix on failure.
pub fn Axes::relim_checked(
  self : Axes,
  visible_only~ : Bool = false,
) -> Unit raise @core.DataError {
  let state = self.state.val
  state.raw_x_data = empty_data_interval()
  state.raw_y_data = empty_data_interval()
  // Bbox.set_points(null) leaves its existing minimum-positive metadata.
  // The next successful ignore update resets only its selected coordinates.
  state.ignore_existing_data_limits = true
  for artist in state.artists {
    let mut skip = false
    if artist is Artist::Line(points, _) {
      for line in state.line_originals {
        if physical_equal(points, line.points) {
          if visible_only && !line.get_visible() {
            skip = true
          } else {
            ignore(line.points_snapshot_checked())
          }
          break
        }
      }
    }
    if skip {
      continue
    }
    self.update_artist_data_limits(artist)
  }
}

///|
/// Cached raw data limits, independent of viewport and displayed scale.
pub fn Axes::data_limits(
  self : Axes,
  horizontal~ : Bool = true,
) -> @core.Limits {
  if horizontal {
    self.state.val.raw_x_data
  } else {
    self.state.val.raw_y_data
  }
}

///|
/// Cached minimum positive raw coordinate, including interior artist points.
pub fn Axes::data_minpos(self : Axes, horizontal~ : Bool = true) -> Double {
  if horizontal {
    self.state.val.x_data_minpos
  } else {
    self.state.val.y_data_minpos
  }
}

///|
pub fn Axes::ignore_existing_data_limits(self : Axes) -> Bool {
  self.state.val.ignore_existing_data_limits
}

///|
/// Extend cached data limits without requesting or enabling a view update.
/// A paired vertex mask is used after the source's any-finite early test.
pub fn Axes::update_datalim(
  self : Axes,
  points : Array[@core.Point],
  update_x~ : Bool = true,
  update_y~ : Bool = true,
) -> Unit {
  let mut any_finite = false
  for point in points {
    let x = point.x()
    let y = point.y()
    if (!x.is_nan() && !x.is_inf()) || (!y.is_nan() && !y.is_inf()) {
      any_finite = true
    }
  }
  if !any_finite {
    return
  }
  let artists = [@render.Artist::Line(points, @core.style("#000000"))]
  let state = self.state.val
  let ignore = state.ignore_existing_data_limits
  if update_x {
    state.raw_x_data = merge_data_interval(
      state.raw_x_data,
      @svg.artist_data_interval(artists, true),
      ignore,
    )
    let fresh = @svg.artist_minpos(artists, true)
    state.x_data_minpos = if ignore {
      fresh
    } else {
      Double::min(state.x_data_minpos, fresh)
    }
  }
  if update_y {
    state.raw_y_data = merge_data_interval(
      state.raw_y_data,
      @svg.artist_data_interval(artists, false),
      ignore,
    )
    let fresh = @svg.artist_minpos(artists, false)
    state.y_data_minpos = if ignore {
      fresh
    } else {
      Double::min(state.y_data_minpos, fresh)
    }
  }
  state.ignore_existing_data_limits = false
}
