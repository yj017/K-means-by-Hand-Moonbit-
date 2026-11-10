///|
fn Axes::set_numeric_scale(
  self : Axes,
  value : @scale.Scale,
  horizontal : Bool,
) -> Unit raise @core.DataError {
  let states = if horizontal {
    self.x_group_states()
  } else {
    self.y_group_states()
  }
  // Intrinsic direction and stable Scene context were bound at construction.
  // A scale change must preserve user overrides of those context providers.
  let axis = if horizontal {
    self.state.val.x_axis
  } else {
    self.state.val.y_axis
  }
  let previous_defaults = axis.locator_default_limits()
  states.sort_by((left, right) => {
    let first = if horizontal {
      left.val.share_x_order
    } else {
      left.val.share_y_order
    }
    let second = if horizontal {
      right.val.share_x_order
    } else {
      right.val.share_y_order
    }
    first.compare(second)
  })
  for state in states {
    let current = if horizontal { state.val.x_axis } else { state.val.y_axis }
    current.set_scale(value)
  }
  // Shared Ticker holders retain the last source sibling's installed handles
  // and owner. Do not rebind the requesting axes after this loop.
  if previous_defaults != axis.locator_default_limits() {
    self.autoscale_view(scalex=horizontal, scaley=!horizontal)
  }
}

///|
/// Set the x-axis scale on this axes and all axes sharing its x coordinate.
pub fn Axes::set_x_scale(
  self : Axes,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.set_numeric_scale(value, true)
}

///|
/// Set the y-axis scale on this axes and all axes sharing its y coordinate.
pub fn Axes::set_y_scale(
  self : Axes,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.set_numeric_scale(value, false)
}

///|
/// Set the x-axis scale on the default axes.
pub fn Figure::set_x_scale(
  self : Figure,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.axes().set_x_scale(value)
}

///|
/// Set the y-axis scale on the default axes.
pub fn Figure::set_y_scale(
  self : Figure,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.axes().set_y_scale(value)
}

///|
/// Return the current x-axis scale.
pub fn Axes::x_scale(self : Axes) -> @scale.Scale {
  self.state.val.x_axis.scale()
}

///|
/// Return the current y-axis scale.
pub fn Axes::y_scale(self : Axes) -> @scale.Scale {
  self.state.val.y_axis.scale()
}

///|
/// Add a plot with logarithmic x and y coordinates.
pub fn Axes::loglog(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.set_x_scale(@scale.log_scale())
  self.set_y_scale(@scale.log_scale())
  self.plot(xs, ys, color~, label~)
}

///|
/// Add a plot with a logarithmic x coordinate and linear y coordinate.
pub fn Axes::semilogx(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.set_x_scale(@scale.log_scale())
  self.plot(xs, ys, color~, label~)
}

///|
/// Add a plot with a linear x coordinate and logarithmic y coordinate.
pub fn Axes::semilogy(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.set_y_scale(@scale.log_scale())
  self.plot(xs, ys, color~, label~)
}

///|
/// Add a plot with logarithmic x and y coordinates to the default axes.
pub fn Figure::loglog(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().loglog(xs, ys, color~, label~)
}

///|
/// Add a plot with a logarithmic x coordinate to the default axes.
pub fn Figure::semilogx(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().semilogx(xs, ys, color~, label~)
}

///|
/// Add a plot with a logarithmic y coordinate to the default axes.
pub fn Figure::semilogy(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().semilogy(xs, ys, color~, label~)
}
