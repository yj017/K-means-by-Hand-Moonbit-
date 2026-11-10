///|
/// Reset this panel through the source-ordered coordinate clear lifecycle.
/// Already performed mutations remain observable if a checked provider fails.
pub fn Axes::clear_checked(self : Axes) -> Unit raise @core.DataError {
  for horizontal in [true, false] {
    let axis = if horizontal {
      self.state.val.x_axis
    } else {
      self.state.val.y_axis
    }
    axis.clear()
    let siblings = if horizontal {
      self.x_group_states()
    } else {
      self.y_group_states()
    }
    for state in siblings {
      if !physical_equal(state, self.state) {
        let peer = if horizontal { state.val.x_axis } else { state.val.y_axis }
        peer.set_scale(@scale.linear_scale())
      }
    }
  }
  // Axes.__clear's late visible-minor setter is distinct from scale defaults:
  // it deliberately leaves the shared minor-locator default flag false.
  if @config.minor_ticks_visible() {
    self.state.val.x_axis.set_minor_locator(
      @ticker.AutoMinorLocator::new().as_minor_locator(),
    )
  }
  if @config.minor_ticks_visible(horizontal=false) {
    self.state.val.y_axis.set_minor_locator(
      @ticker.AutoMinorLocator::new().as_minor_locator(),
    )
  }
  self.state.val.clear_presentation()
  for horizontal in [true, false] {
    self.clear_coordinate_view(horizontal)
  }
}

///|
fn Axes::clear_coordinate_view(
  self : Axes,
  horizontal : Bool,
) -> Unit raise @core.DataError {
  let axis = if horizontal {
    self.state.val.x_axis
  } else {
    self.state.val.y_axis
  }
  let target = if horizontal {
    self.state.val.share_x_target
  } else {
    self.state.val.share_y_target
  }
  match target {
    Some(state) => {
      self.join_shared_axis(state, horizontal)
      let source = if horizontal { state.val.x_axis } else { state.val.y_axis }
      axis.share_numeric_tickers(source)
      // Original sharex/sharey joins and aliases tickers before get_xlim/ylim.
      // A user view callback can fail here after those mutations have occurred.
      let (lower, upper) = source.lifecycle_view_interval_checked()
      axis.set_cleared_view_limits(
        lower,
        upper,
        automatic=source.autoscale_on(),
      )
      // Geometry inheritance is the final source assignment, not a scale reset.
      axis.inherit_scale_from(source)
    }
    None => {
      axis.set_cleared_view_limits(0.0, 1.0, automatic=true)
      let limits = axis.current_view_limits().unwrap_or(@core.limits(0.0, 1.0))
      let lower = limits.lower()
      let upper = limits.upper()
      let siblings = if horizontal {
        self.x_group_states()
      } else {
        self.y_group_states()
      }
      for state in siblings {
        if !physical_equal(state, self.state) {
          let peer = if horizontal {
            state.val.x_axis
          } else {
            state.val.y_axis
          }
          peer.set_cleared_view_limits(lower, upper, automatic=true)
        }
      }
    }
  }
}
