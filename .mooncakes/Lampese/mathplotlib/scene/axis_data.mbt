///|
fn Axes::bind_axis_data(self : Axes, horizontal : Bool) -> Unit {
  let state = self.state
  let provider = fn() {
    let current = state.val
    let values = if horizontal {
      current.raw_x_data
    } else {
      current.raw_y_data
    }
    (values.lower(), values.upper())
  }
  let axis = if horizontal { state.val.x_axis } else { state.val.y_axis }
  axis.bind_data_interval(provider)
  let figure = self.figure
  axis.bind_unit_group(() => {
    let axes : Axes = { figure, state, }
    let states = if horizontal {
      axes.x_group_states()
    } else {
      axes.y_group_states()
    }
    states.map(peer => {
      if horizontal {
        peer.val.x_axis
      } else {
        peer.val.y_axis
      }
    })
  })
  axis.bind_unit_data_mutated(() => {
    let current = state.val
    let values = if horizontal {
      current.raw_x_data
    } else {
      current.raw_y_data
    }
    values.lower() != 1.0 / 0.0 || values.upper() != -1.0 / 0.0
  })
  axis.bind_units_changed(() => {
    let axes : Axes = { figure, state, }
    axes.recache_line_units()
    axes.relim_checked()
    axes.request_autoscale_view(axis=if horizontal { "x" } else { "y" })
  })
  axis.bind_autoscale_view(() => {
    let axes : Axes = { figure, state, }
    axes.unstale_view()
  })
  axis.bind_minpos(() => {
    let minimum = if horizontal {
      state.val.x_data_minpos
    } else {
      state.val.y_data_minpos
    }
    // Area endpoints may span (0, 1) without containing an interior sample.
    // Keep the raw data minimum, but use the locator's standard probability
    // fallback when that derived minimum cannot be a Logit domain boundary.
    if axis.scale().is_logit() && minimum >= 1.0 && !minimum.is_inf() {
      1.0e-7
    } else {
      minimum
    }
  })
  axis.bind_shared_minpos(() => {
    let axes : Axes = { figure, state, }
    let siblings = if horizontal {
      axes.x_group_states()
    } else {
      axes.y_group_states()
    }
    siblings.map(candidate => {
      let sibling_axis = if horizontal {
        candidate.val.x_axis
      } else {
        candidate.val.y_axis
      }
      sibling_axis.get_minpos()
    })
  })
  axis.bind_tick_geometry(
    fn() {
      let axes : Axes = { figure, state, }
      let rect = state.val.active_position.unwrap_or_else(fn() {
        axes.original_position_rect()
      })
      if horizontal {
        rect.width()
      } else {
        rect.height()
      }
    },
    horizontal,
  )
  axis.bind_formatter_geometry(fn() {
    let axes : Axes = { figure, state, }
    let rect = state.val.active_position.unwrap_or_else(fn() {
      axes.original_position_rect()
    })
    if horizontal {
      (rect.x(), rect.width())
    } else {
      (figure.height.to_double() - rect.y() - rect.height(), rect.height())
    }
  })
  axis.bind_render_view_interval(fn() raise @core.DataError {
    for index, candidate in figure.axes {
      if physical_equal(candidate, state) {
        if @svg.panel_view(figure.to_render_figure(), index) is Some((_, x, y)) {
          let limits = if horizontal { x } else { y }
          return (limits.lower(), limits.upper())
        }
      }
    }
    if @svg.panel_view(
        figure.to_render_figure(extra=state),
        figure.axes.length(),
      )
      is Some((_, x, y)) {
      let limits = if horizontal { x } else { y }
      return (limits.lower(), limits.upper())
    }
    let limits = axis.current_view_limits().unwrap_or(@core.limits(0.0, 1.0))
    (limits.lower(), limits.upper())
  })
}
