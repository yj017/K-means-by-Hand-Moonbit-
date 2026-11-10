///|
/// A handle to one independent plotting panel in a figure.
pub struct Axes {
  figure : Figure
  state : @ref.Ref[AxesData]
}

///|
/// Return the figure owning these axes.
pub fn Axes::figure(self : Axes) -> Figure {
  self.figure
}

///|
/// Return the allocated display rectangle in pixels, with a top-left origin.
/// This includes manual position updates but does not apply aspect shrinking.
/// The implicit default panel returns None until laid out or positioned.
pub fn Axes::rect(self : Axes) -> @gridspec.Rect? {
  if self.state.val.position_override is Some(rect) {
    return Some(rect)
  }
  match self.state.val.subplot_spec {
    Some(spec) => Some(self.figure.subplot_rect(spec))
    None => self.state.val.rect
  }
}

///|
/// Return this panel's x-axis object.
pub fn Axes::x_axis(self : Axes) -> @axis.Axis {
  self.state.val.x_axis
}

///|
/// Return this panel's y-axis object.
pub fn Axes::y_axis(self : Axes) -> @axis.Axis {
  self.state.val.y_axis
}

///|
/// Set an equal data aspect for this axes panel.
///
/// The SVG backend keeps one data unit equally sized on both axes and places
/// the resulting plot rectangle using the panel's anchor.
/// share=true also sets the direct x/y shared siblings to aspect 1.
pub fn Axes::set_aspect_equal(self : Axes, share~ : Bool = false) -> Unit {
  self.apply_data_aspect(Some(1.0), share)
}

///|
/// Restore automatic aspect handling for this axes panel.
/// share=true also restores the direct x/y shared siblings.
pub fn Axes::set_aspect_auto(self : Axes, share~ : Bool = false) -> Unit {
  self.apply_data_aspect(None, share)
}

///|
/// Return whether this axes panel uses equal data scaling.
pub fn Axes::aspect_equal(self : Axes) -> Bool {
  self.state.val.data_aspect == Some(1.0)
}

///|
/// Hide the frame, ticks, labels, grid, and secondary axes for this panel.
pub fn Axes::set_axis_off(self : Axes) -> Unit {
  self.state.val.frame_visible = false
}

///|
/// Show the frame, ticks, labels, grid, and secondary axes for this panel.
pub fn Axes::set_axis_on(self : Axes) -> Unit {
  self.state.val.frame_visible = true
}

///|
/// Return whether this panel's primary axis decorations are visible.
pub fn Axes::axis_visible(self : Axes) -> Bool {
  self.state.val.frame_visible
}

///|
fn validate_margin(value : Double) -> Unit raise @core.DataError {
  if value <= -0.5 {
    raise @core.DataError::InvalidTicks(
      message="axes margins must be greater than -0.5",
    )
  }
}

///|
/// Set the automatic x-axis margin as a fraction of the data span.
pub fn Axes::set_x_margin(
  self : Axes,
  value : Double,
) -> Unit raise @core.DataError {
  validate_margin(value)
  self.state.val.x_margin = value
  self.state.val.x_axis.request_autoscale()
}

///|
/// Set the automatic y-axis margin as a fraction of the data span.
pub fn Axes::set_y_margin(
  self : Axes,
  value : Double,
) -> Unit raise @core.DataError {
  validate_margin(value)
  self.state.val.y_margin = value
  self.state.val.y_axis.request_autoscale()
}

///|
/// Set both automatic axis margins.
pub fn Axes::set_margins(
  self : Axes,
  x : Double,
  y : Double,
) -> Unit raise @core.DataError {
  validate_margin(x)
  validate_margin(y)
  self.state.val.tight = Some(true)
  self.state.val.x_margin = x
  self.state.val.y_margin = y
  self.state.val.x_axis.request_autoscale()
  self.state.val.y_axis.request_autoscale()
}

///|
/// Return the automatic margins as an `(x, y)` pair.
pub fn Axes::margins(self : Axes) -> (Double, Double) {
  (self.state.val.x_margin, self.state.val.y_margin)
}

///|
/// Return the automatic x-axis margin.
pub fn Axes::x_margin(self : Axes) -> Double {
  self.state.val.x_margin
}

///|
/// Return the automatic y-axis margin.
pub fn Axes::y_margin(self : Axes) -> Double {
  self.state.val.y_margin
}

///|
/// Set the x-axis tick label side for this panel.
pub fn Axes::set_x_tick_position(
  self : Axes,
  position : @axis.TickPosition,
) -> Unit {
  self.state.val.x_axis.set_tick_position(position)
}

///|
/// Set the y-axis tick label side for this panel.
pub fn Axes::set_y_tick_position(
  self : Axes,
  position : @axis.TickPosition,
) -> Unit {
  self.state.val.y_axis.set_tick_position(position)
}

///|
/// Configure major or minor grid lines for this axes panel.
///
/// `which` accepts `"both"`, `"x"`, `"y"`, `"major"`, or `"minor"`.
/// `axis` selects `"both"`, `"x"`, or `"y"` with the default or major/minor mode.
/// The legacy `which="x"`/`"y"` selectors require the default `axis="both"`.
/// Shared axes propagate the corresponding setting to their linked panels.
pub fn Axes::grid(
  self : Axes,
  visible~ : Bool = true,
  which~ : String = "both",
  color~ : String = "#e5e7eb",
  linewidth~ : Double = 1.0,
  axis~ : String = "both",
) -> Unit raise @core.DataError {
  if which != "both" &&
    which != "x" &&
    which != "y" &&
    which != "major" &&
    which != "minor" {
    raise @core.DataError::InvalidTicks(
      message="grid which must be 'both', 'x', 'y', 'major', or 'minor'",
    )
  }
  if axis != "both" && axis != "x" && axis != "y" {
    raise @core.DataError::InvalidTicks(
      message="grid axis must be 'both', 'x', or 'y'",
    )
  }
  if (which == "x" || which == "y") && axis != "both" {
    raise @core.DataError::InvalidTicks(
      message="grid axis is only valid with 'both', 'major', or 'minor' which",
    )
  }
  if which == "major" || which == "minor" {
    if which == "minor" {
      if axis == "both" || axis == "x" {
        for state in self.x_group_states() {
          state.val.x_axis.set_minor_grid(visible, color, linewidth)
        }
      }
      if axis == "both" || axis == "y" {
        for state in self.y_group_states() {
          state.val.y_axis.set_minor_grid(visible, color, linewidth)
        }
      }
    } else {
      if axis == "both" || axis == "x" {
        for state in self.x_group_states() {
          state.val.x_axis.set_grid(visible, color, linewidth)
        }
      }
      if axis == "both" || axis == "y" {
        for state in self.y_group_states() {
          state.val.y_axis.set_grid(visible, color, linewidth)
        }
      }
    }
    return
  }
  if (which == "both" && axis != "y") || which == "x" {
    for state in self.x_group_states() {
      state.val.x_axis.set_grid(visible, color, linewidth)
    }
  }
  if (which == "both" && axis != "x") || which == "y" {
    for state in self.y_group_states() {
      state.val.y_axis.set_grid(visible, color, linewidth)
    }
  }
}

///|
/// Return this panel's artists in insertion order.
pub fn Axes::artists(self : Axes) -> Array[Artist] {
  let state = self.state.val
  let artists = state.artists
  let result = Array(capacity=artists.length())
  for artist in artists {
    match artist {
      Artist::Line(points, style) => {
        let mut current_style = style
        for line in state.line_originals {
          if physical_equal(points, line.points) {
            current_style = line.style
            break
          }
        }
        // Appearance is a current immutable snapshot; this query must not
        // trigger conversion of pending original data.
        result.push(Artist::Line(copy_points(points), current_style))
      }
      _ => result.push(copy_artist(artist))
    }
  }
  result
}

///|
/// Set this panel's title.
pub fn Axes::set_title(self : Axes, title : String) -> Unit {
  self.state.val.title = Some(title)
}

///|
/// Return this panel's optional title.
pub fn Axes::title(self : Axes) -> String? {
  self.state.val.title
}

///|
/// Set this panel's x-axis label.
pub fn Axes::set_x_label(self : Axes, label : String) -> Unit {
  self.state.val.x_axis.set_label(label)
}

///|
/// Set this panel's y-axis label.
pub fn Axes::set_y_label(self : Axes, label : String) -> Unit {
  self.state.val.y_axis.set_label(label)
}

///|
/// Return explicit x limits, or a resolved datalim view after aspect application.
pub fn Axes::x_limits(self : Axes) -> @core.Limits? {
  if self.state.val.adjustable == "datalim" &&
    self.state.val.data_aspect is Some(_) {
    self.state.val.x_axis.current_view_limits()
  } else {
    self.state.val.x_axis.limits()
  }
}

///|
/// Return explicit y limits, or a resolved datalim view after aspect application.
pub fn Axes::y_limits(self : Axes) -> @core.Limits? {
  if self.state.val.adjustable == "datalim" &&
    self.state.val.data_aspect is Some(_) {
    self.state.val.y_axis.current_view_limits()
  } else {
    self.state.val.y_axis.limits()
  }
}

///|
/// Set explicit limits for this panel.
pub fn Axes::set_bounds(
  self : Axes,
  limits : @core.Bounds,
) -> Unit raise @core.DataError {
  if !limits.is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="both")
  }
  self.state.val.explicit_bounds = Some(limits)
  self.set_x_limits(limits.xmin(), limits.xmax())
  self.set_y_limits(limits.ymin(), limits.ymax())
}

///|
/// Set the x-axis limits through this axes handle.
pub fn Axes::set_x_limits(
  self : Axes,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  if !@core.limits(lower, upper).is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="x")
  }
  for state in self.x_group_states() {
    state.val.x_axis.set_limits(lower, upper)
  }
}

///|
/// Set the y-axis limits through this axes handle.
pub fn Axes::set_y_limits(
  self : Axes,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  if !@core.limits(lower, upper).is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="y")
  }
  for state in self.y_group_states() {
    state.val.y_axis.set_limits(lower, upper)
  }
}

///|
/// Set fixed x-axis tick positions through this axes handle.
pub fn Axes::set_x_ticks(
  self : Axes,
  values : Array[Double],
) -> Unit raise @core.DataError {
  for state in self.x_group_states() {
    state.val.x_axis.set_ticks(values)
  }
}

///|
/// Set fixed y-axis tick positions through this axes handle.
pub fn Axes::set_y_ticks(
  self : Axes,
  values : Array[Double],
) -> Unit raise @core.DataError {
  for state in self.y_group_states() {
    state.val.y_axis.set_ticks(values)
  }
}

///|
/// Set the numeric major locator through this axes handle.
pub fn Axes::set_x_locator(
  self : Axes,
  locator : @ticker.Locator,
) -> Unit raise @core.DataError {
  for state in self.x_group_states() {
    state.val.x_axis.set_locator(locator)
  }
  self.state.val.x_axis.bind_locator_data()
}

///|
/// Set the numeric major locator through this axes handle.
pub fn Axes::set_y_locator(
  self : Axes,
  locator : @ticker.Locator,
) -> Unit raise @core.DataError {
  for state in self.y_group_states() {
    state.val.y_axis.set_locator(locator)
  }
  self.state.val.y_axis.bind_locator_data()
}

///|
/// Set the numeric formatter through this axes handle.
pub fn Axes::set_x_formatter(
  self : Axes,
  formatter : @ticker.Formatter,
) -> Unit {
  for state in self.x_group_states() {
    state.val.x_axis.set_formatter(formatter)
  }
}

///|
/// Set the numeric formatter through this axes handle.
pub fn Axes::set_y_formatter(
  self : Axes,
  formatter : @ticker.Formatter,
) -> Unit {
  for state in self.y_group_states() {
    state.val.y_axis.set_formatter(formatter)
  }
}

///|
/// Set the minor locator through this axes handle.
pub fn Axes::set_x_minor_locator(
  self : Axes,
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  for state in self.x_group_states() {
    state.val.x_axis.set_minor_locator(locator)
  }
  self.state.val.x_axis.bind_locator_data(minor=true)
}

///|
/// Set the minor locator through this axes handle.
pub fn Axes::set_y_minor_locator(
  self : Axes,
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  for state in self.y_group_states() {
    state.val.y_axis.set_minor_locator(locator)
  }
  self.state.val.y_axis.bind_locator_data(minor=true)
}

///|
/// Set fixed x-axis tick labels through this axes handle.
pub fn Axes::set_x_tick_labels(
  self : Axes,
  labels : Array[String],
) -> Unit raise @core.DataError {
  for state in self.x_group_states() {
    state.val.x_axis.set_tick_labels(labels)
  }
}

///|
/// Set fixed y-axis tick labels through this axes handle.
pub fn Axes::set_y_tick_labels(
  self : Axes,
  labels : Array[String],
) -> Unit raise @core.DataError {
  for state in self.y_group_states() {
    state.val.y_axis.set_tick_labels(labels)
  }
}

///|
/// Clear this axes' artists and presentation state while retaining its panel
/// rectangle and shared-axis membership.
pub fn Axes::clear(self : Axes) -> Unit {
  try! self.clear_checked()
}

///|
/// Add a line plot through the axes view.
pub fn Axes::plot(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let values = @core.series(xs, ys)
  self.line(values.points(), color~, label~)
}

///|
/// Add explicit line points through the axes view.
pub fn Axes::line(
  self : Axes,
  points : Array[@core.Point],
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  self.attach_line_with_originals(
    points,
    LineData::Numeric(points.map(point => point.x())),
    LineData::Numeric(points.map(point => point.y())),
    color~,
    label~,
  )
}

///|
/// Add scatter points through the axes view.
pub fn Axes::scatter(
  self : Axes,
  points : Array[@core.Point],
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  let resolved_color = self.resolve_color(color)
  self.push_artist(
    Artist::Scatter(
      copy_points(points),
      @core.style(resolved_color, width=0.0, radius=3.5),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Marker)
}

///|
/// Add bars through the axes view.
pub fn Axes::bar(
  self : Axes,
  points : Array[@core.Point],
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::Bar(
      copy_points(points),
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
  self.add_container(ContainerKind::Bar, start, label)
}
