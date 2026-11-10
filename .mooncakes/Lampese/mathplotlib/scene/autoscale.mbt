///|
fn validate_autoscale_axis(
  axis : String,
  all~ : Bool = false,
) -> Unit raise @core.DataError {
  if axis != "both" && axis != "x" && axis != "y" && !(all && axis == "all") {
    raise @core.DataError::InvalidTicks(
      message="autoscale axis must be 'both', 'x', or 'y'",
    )
  }
}

///|
/// Schedule a lazy view update without enabling an axis or changing its viewport.
pub fn Axes::request_autoscale_view(
  self : Axes,
  axis~ : String = "all",
  tight? : Bool,
) -> Unit raise @core.DataError {
  validate_autoscale_axis(axis, all=true)
  if axis == "all" || axis == "both" || axis == "x" {
    self.state.val.x_axis.request_autoscale()
  }
  if axis == "all" || axis == "both" || axis == "y" {
    self.state.val.y_axis.request_autoscale()
  }
  if tight is Some(value) {
    self.state.val.tight = Some(value)
  }
}

///|
/// Enable automatic limits and request them lazily. None preserves both flags.
/// Tight requests zero only the selected local margins; autoscale_view does not.
pub fn Axes::autoscale(
  self : Axes,
  enable~ : Bool? = Some(true),
  axis~ : String = "both",
  tight? : Bool,
) -> Unit raise @core.DataError {
  validate_autoscale_axis(axis)
  let (scalex, scaley) = match enable {
    None => (true, true)
    Some(enabled) => {
      let x = axis == "both" || axis == "x"
      let y = axis == "both" || axis == "y"
      if x {
        self.state.val.x_axis.set_autoscale_on(enabled)
      }
      if y {
        self.state.val.y_axis.set_autoscale_on(enabled)
      }
      (x && enabled, y && enabled)
    }
  }
  if scalex {
    if tight == Some(true) {
      self.state.val.x_margin = 0.0
    }
    self.request_autoscale_view(axis="x", tight?)
  }
  if scaley {
    if tight == Some(true) {
      self.state.val.y_margin = 0.0
    }
    self.request_autoscale_view(axis="y", tight?)
  }
}

///|
/// Resolve shared pending requests before computing either coordinate.
/// Requests are consumed before callbacks, so an error does not restore them.
pub fn Axes::unstale_view(self : Axes) -> Unit raise @core.DataError {
  let xs = self.x_group_states()
  let ys = self.y_group_states()
  let mut scalex = false
  let mut scaley = false
  for state in xs {
    scalex = scalex || state.val.x_axis.autoscale_stale()
  }
  for state in ys {
    scaley = scaley || state.val.y_axis.autoscale_stale()
  }
  if !scalex && !scaley {
    return
  }
  if scalex {
    for state in xs {
      state.val.x_axis.clear_autoscale_request()
    }
  }
  if scaley {
    for state in ys {
      state.val.y_axis.clear_autoscale_request()
    }
  }
  self.autoscale_view(scalex~, scaley~)
}

///|
/// Recompute selected automatic views now, using cached shared data intervals.
/// `axis` is a compatibility selector combined with scalex/scaley.
pub fn Axes::autoscale_view(
  self : Axes,
  tight? : Bool,
  scalex~ : Bool = true,
  scaley~ : Bool = true,
  axis~ : String = "both",
) -> Unit raise @core.DataError {
  validate_autoscale_axis(axis)
  if tight is Some(value) {
    self.state.val.tight = Some(value)
  }
  let scalex = scalex && (axis == "both" || axis == "x")
  let scaley = scaley && (axis == "both" || axis == "y")
  // The source collects both directions' sticky arrays before computing x.
  let xs = self.x_group_states()
  let ys = self.y_group_states()
  let x_stickies = self.autoscale_stickies(xs, true, scalex)
  let y_stickies = self.autoscale_stickies(ys, false, scaley)
  if scalex {
    self.autoscale_coordinate(xs, x_stickies, true)
  }
  if scaley {
    self.autoscale_coordinate(ys, y_stickies, false)
  }
}

///|
fn Axes::autoscale_stickies(
  self : Axes,
  states : Array[@ref.Ref[AxesData]],
  horizontal : Bool,
  selected : Bool,
) -> Array[Double] {
  let result : Array[Double] = []
  let axis = if horizontal {
    self.state.val.x_axis
  } else {
    self.state.val.y_axis
  }
  let margin = if horizontal {
    self.state.val.x_margin
  } else {
    self.state.val.y_margin
  }
  if self.state.val.use_sticky_edges &&
    selected &&
    axis.autoscale_on() &&
    margin != 0.0 {
    for state in states {
      let values = @svg.artist_sticky_edges(
        state.val.artists.map(to_render_artist),
        horizontal,
      )
      for value in values {
        result.push(value)
      }
    }
  }
  // The original captures both sticky arrays and filters against each scale
  // before any x callback can replace the y scale.
  if axis.scale().is_log() {
    result.filter(value => value > 0.0)
  } else {
    result
  }
}

///|
fn Axes::autoscale_coordinate(
  self : Axes,
  states : Array[@ref.Ref[AxesData]],
  stickies : Array[Double],
  horizontal : Bool,
) -> Unit raise @core.DataError {
  let axis = if horizontal {
    self.state.val.x_axis
  } else {
    self.state.val.y_axis
  }
  // All installed ticker roles share the same raw-data/view lifecycle.
  if !axis.autoscale_on() {
    return
  }
  let endpoints : Array[Double] = []
  for state in states {
    let values = if horizontal {
      state.val.raw_x_data
    } else {
      state.val.raw_y_data
    }
    endpoints.push(values.lower())
    endpoints.push(values.upper())
  }
  let margin = if horizontal {
    self.state.val.x_margin
  } else {
    self.state.val.y_margin
  }
  if axis.autoscale_bounds_checked(
      endpoints,
      margin~,
      stickies~,
      tight=self.state.val.tight.unwrap_or(false),
      tight_provider=Some(() => self.state.val.tight.unwrap_or(false)),
      log_stickies=Some(false),
      data_minpos=Some(() => {
        states.map(state => {
          if horizontal {
            state.val.x_data_minpos
          } else {
            state.val.y_data_minpos
          }
        })
      }),
    )
    is Some(candidate) {
    // Source set_bound first reads old bounds, then independently reads view
    // direction. Both callbacks remain observable even with two new endpoints.
    let _ = axis.lifecycle_view_interval_checked()
    let (first, last) = axis.lifecycle_view_interval_checked()
    let low = Double::min(candidate.lower(), candidate.upper())
    let high = Double::max(candidate.lower(), candidate.upper())
    let (lower, upper) = if first > last { (high, low) } else { (low, high) }
    self.store_coordinate_bounds(states, horizontal, lower, upper, None)
  }
}

///|
fn Axes::store_coordinate_bounds(
  self : Axes,
  states : Array[@ref.Ref[AxesData]],
  horizontal : Bool,
  lower : Double,
  upper : Double,
  automatic : Bool?,
) -> Unit raise @core.DataError {
  let axis = if horizontal {
    self.state.val.x_axis
  } else {
    self.state.val.y_axis
  }
  let view = axis.set_bound_limits_checked(lower, upper, automatic~)
  // Source clears all siblings before emitting the current limit change.
  for state in states {
    let peer = if horizontal { state.val.x_axis } else { state.val.y_axis }
    peer.clear_autoscale_request()
  }
  for state in states {
    if !physical_equal(state, self.state) {
      let peer = if horizontal { state.val.x_axis } else { state.val.y_axis }
      let _ = peer.set_bound_limits_checked(
        view.lower(),
        view.upper(),
        automatic~,
      )
    }
  }
}

///|
/// Read the resolved x viewport, propagating checked provider errors.
pub fn Axes::get_xlim_checked(
  self : Axes,
) -> @core.Limits raise @core.DataError {
  let (lower, upper) = self.state.val.x_axis.lifecycle_view_interval_checked()
  @core.limits(lower, upper)
}

///|
/// Read the resolved y viewport, propagating checked provider errors.
pub fn Axes::get_ylim_checked(
  self : Axes,
) -> @core.Limits raise @core.DataError {
  let (lower, upper) = self.state.val.y_axis.lifecycle_view_interval_checked()
  @core.limits(lower, upper)
}

///|
pub fn Axes::get_autoscalex_on(self : Axes) -> Bool {
  self.state.val.x_axis.autoscale_on()
}

///|
pub fn Axes::get_autoscaley_on(self : Axes) -> Bool {
  self.state.val.y_axis.autoscale_on()
}

///|
pub fn Axes::get_autoscale_on(self : Axes) -> Bool {
  self.get_autoscalex_on() && self.get_autoscaley_on()
}

///|
pub fn Axes::set_autoscalex_on(self : Axes, enabled : Bool) -> Unit {
  self.state.val.x_axis.set_autoscale_on(enabled)
}

///|
pub fn Axes::set_autoscaley_on(self : Axes, enabled : Bool) -> Unit {
  self.state.val.y_axis.set_autoscale_on(enabled)
}

///|
pub fn Axes::set_autoscale_on(self : Axes, enabled : Bool) -> Unit {
  self.set_autoscalex_on(enabled)
  self.set_autoscaley_on(enabled)
}

///|
pub fn Axes::autoscale_tight(self : Axes) -> Bool? {
  self.state.val.tight
}

///|
pub fn Axes::use_sticky_edges(self : Axes) -> Bool {
  self.state.val.use_sticky_edges
}

///|
pub fn Axes::set_use_sticky_edges(self : Axes, enabled : Bool) -> Unit {
  self.state.val.use_sticky_edges = enabled
}

///|
pub fn Figure::autoscale_view(
  self : Figure,
  tight? : Bool,
  scalex~ : Bool = true,
  scaley~ : Bool = true,
  axis~ : String = "both",
) -> Unit raise @core.DataError {
  self.axes().autoscale_view(tight?, scalex~, scaley~, axis~)
}

///|
fn Axes::set_coordinate_limits_checked(
  self : Axes,
  lower : Double,
  upper : Double,
  horizontal : Bool,
  automatic : Bool?,
) -> Unit raise @core.DataError {
  let states = if horizontal {
    self.x_group_states()
  } else {
    self.y_group_states()
  }
  self.store_coordinate_bounds(states, horizontal, lower, upper, automatic)
}
