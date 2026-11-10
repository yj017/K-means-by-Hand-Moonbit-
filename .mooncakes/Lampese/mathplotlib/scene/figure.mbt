///|
/// A backend-independent figure containing ordered axes panels.
pub struct Figure {
  width : Int32
  height : Int32
  margin : Int32
  axes : Array[@ref.Ref[AxesData]]
  priv axes_selection : Array[@ref.Ref[AxesData]]
  subfigures : Array[@ref.Ref[SubFigureData]]
  colorbars : Array[@colorbar.Colorbar]
  mut share_group_seed : Int32
  priv mut share_x_next_order : Int64
  priv mut share_y_next_order : Int64
  mut title : String?
  priv mut subplot_left : Double
  priv mut subplot_bottom : Double
  priv mut subplot_right : Double
  priv mut subplot_top : Double
  priv mut subplot_wspace : Double?
  priv mut subplot_hspace : Double?
}

///|
/// Create an empty figure with one default axes panel.
pub fn figure(width~ : Int32 = 640, height~ : Int32 = 480) -> Figure {
  let margin = 56
  let figure_width = Double::from_int(width)
  let figure_height = Double::from_int(height)
  let left = if width > 0 {
    Double::from_int(margin) / figure_width
  } else {
    0.0
  }
  let bottom = if height > 0 {
    Double::from_int(margin) / figure_height
  } else {
    0.0
  }
  let default_axes = @ref.new({
    artists: [],
    polar: None,
    line_originals: [],
    artist_hits: [],
    barb_intents: Map([]),
    contour_intents: Map([]),
    contourf_intents: Map([]),
    tricolor_intents: Map([]),
    streamplot_intents: Map([]),
    x_axis: @axis.axis(),
    y_axis: @axis.axis(horizontal=false),
    title: None,
    explicit_bounds: None,
    legend: [],
    auto_legend: [],
    explicit_legend: false,
    legend_position: UpperRight,
    containers: [],
    rect: None,
    position_override: None,
    active_position: None,
    subplot_spec: None,
    share_x_group: None,
    share_y_group: None,
    share_x_order: 0L,
    share_y_order: 0L,
    share_x_target: None,
    share_y_target: None,
    share_x_members: None,
    share_y_members: None,
    show_x_tick_labels: true,
    show_y_tick_labels: true,
    frame_visible: true,
    spines: default_spines(),
    x_margin: @config.x_margin(),
    y_margin: @config.y_margin(),
    raw_x_data: @core.limits(1.0 / 0.0, -1.0 / 0.0),
    raw_y_data: @core.limits(1.0 / 0.0, -1.0 / 0.0),
    x_data_minpos: 1.0 / 0.0,
    y_data_minpos: 1.0 / 0.0,
    ignore_existing_data_limits: true,
    tight: None,
    use_sticky_edges: true,
    color_cycle: default_color_cycle(),
    color_cycle_index: 0,
    data_aspect: None,
    anchor: Anchor::Named("C"),
    adjustable: "box",
    box_aspect: None,
    secondary_x: [],
    secondary_y: [],
  })
  let result : Figure = {
    width,
    height,
    margin,
    axes: [default_axes],
    axes_selection: [default_axes],
    subfigures: [],
    colorbars: [],
    share_group_seed: -1,
    share_x_next_order: 0L,
    share_y_next_order: 0L,
    title: None,
    subplot_left: left,
    subplot_bottom: bottom,
    subplot_right: 1.0 - left,
    subplot_top: 1.0 - bottom,
    subplot_wspace: None,
    subplot_hspace: None,
  }
  let axes : Axes = { figure: result, state: default_axes, }
  axes.bind_axis_data(true)
  axes.bind_axis_data(false)
  try! axes.clear_checked()
  result
}

///|
/// Set the figure title.
pub fn Figure::set_title(self : Figure, title : String) -> Unit {
  self.title = Some(title)
}

///|
/// Clear all axes, artists, legends, and colorbars while retaining the
/// figure's dimensions and subplot layout.
pub fn Figure::clear(self : Figure) -> Unit {
  try! self.clear_checked()
}

///|
/// Execute the checked Axes clear lifecycle once per retained panel.
/// The panel-preserving Figure convenience contract remains unchanged.
pub fn Figure::clear_checked(self : Figure) -> Unit raise @core.DataError {
  for state in self.axes.copy() {
    ({ figure: self, state, } : Axes).clear_checked()
  }
  for data in self.subfigures {
    data.val.clear_titles()
  }
  self.title = None
  self.subfigures.clear()
  self.colorbars.clear()
}

///|
/// Set the x-axis label on the default axes.
pub fn Figure::set_x_label(self : Figure, label : String) -> Unit {
  self.default_axes_data().val.x_axis.set_label(label)
}

///|
/// Set the y-axis label on the default axes.
pub fn Figure::set_y_label(self : Figure, label : String) -> Unit {
  self.default_axes_data().val.y_axis.set_label(label)
}

///|
/// Set explicit data limits for the default axes.
pub fn Figure::set_bounds(
  self : Figure,
  limits : @core.Bounds,
) -> Unit raise @core.DataError {
  if !limits.is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="both")
  }
  self.axes().set_bounds(limits)
}

///|
/// Set x-axis limits on the default axes, preserving their direction.
pub fn Figure::set_x_limits(
  self : Figure,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  if !@core.limits(lower, upper).is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="x")
  }
  self.axes().set_x_limits(lower, upper)
}

///|
/// Set y-axis limits on the default axes, preserving their direction.
pub fn Figure::set_y_limits(
  self : Figure,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  if !@core.limits(lower, upper).is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="y")
  }
  self.axes().set_y_limits(lower, upper)
}

///|
/// Set the automatic x-axis margin on the default axes.
pub fn Figure::set_x_margin(
  self : Figure,
  value : Double,
) -> Unit raise @core.DataError {
  self.axes().set_x_margin(value)
}

///|
/// Set the automatic y-axis margin on the default axes.
pub fn Figure::set_y_margin(
  self : Figure,
  value : Double,
) -> Unit raise @core.DataError {
  self.axes().set_y_margin(value)
}

///|
/// Set both automatic margins on the default axes.
pub fn Figure::set_margins(
  self : Figure,
  x : Double,
  y : Double,
) -> Unit raise @core.DataError {
  self.axes().set_margins(x, y)
}

///|
/// Return the default axes' automatic margins.
pub fn Figure::margins(self : Figure) -> (Double, Double) {
  (self.axes().x_margin(), self.axes().y_margin())
}

///|
/// Return the default axes' automatic x-axis margin.
pub fn Figure::x_margin(self : Figure) -> Double {
  self.axes().x_margin()
}

///|
/// Return the default axes' automatic y-axis margin.
pub fn Figure::y_margin(self : Figure) -> Double {
  self.axes().y_margin()
}

///|
/// Restore automatic limits for one or both axes.
pub fn Figure::autoscale(
  self : Figure,
  enable~ : Bool? = Some(true),
  axis~ : String = "both",
  tight? : Bool,
) -> Unit raise @core.DataError {
  self.axes().autoscale(enable~, axis~, tight?)
}

///|
/// Set fixed x-axis tick positions on the default axes.
pub fn Figure::set_x_ticks(
  self : Figure,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.axes().set_x_ticks(values)
}

///|
/// Set fixed y-axis tick positions on the default axes.
pub fn Figure::set_y_ticks(
  self : Figure,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.axes().set_y_ticks(values)
}

///|
/// Set the numeric major locator on the default x axis.
pub fn Figure::set_x_locator(
  self : Figure,
  locator : @ticker.Locator,
) -> Unit raise @core.DataError {
  self.axes().set_x_locator(locator)
}

///|
/// Set the numeric major locator on the default y axis.
pub fn Figure::set_y_locator(
  self : Figure,
  locator : @ticker.Locator,
) -> Unit raise @core.DataError {
  self.axes().set_y_locator(locator)
}

///|
/// Set the numeric formatter on the default x axis.
pub fn Figure::set_x_formatter(
  self : Figure,
  formatter : @ticker.Formatter,
) -> Unit {
  self.axes().set_x_formatter(formatter)
}

///|
/// Set the numeric formatter on the default y axis.
pub fn Figure::set_y_formatter(
  self : Figure,
  formatter : @ticker.Formatter,
) -> Unit {
  self.axes().set_y_formatter(formatter)
}

///|
/// Set the minor locator on the default x axis.
pub fn Figure::set_x_minor_locator(
  self : Figure,
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  self.axes().set_x_minor_locator(locator)
}

///|
/// Set the minor locator on the default y axis.
pub fn Figure::set_y_minor_locator(
  self : Figure,
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  self.axes().set_y_minor_locator(locator)
}

///|
/// Set fixed x-axis tick labels on the default axes.
pub fn Figure::set_x_tick_labels(
  self : Figure,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.axes().set_x_tick_labels(labels)
}

///|
/// Set fixed y-axis tick labels on the default axes.
pub fn Figure::set_y_tick_labels(
  self : Figure,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.axes().set_y_tick_labels(labels)
}

///|
/// Return the figure width in display units.
pub fn Figure::width(self : Figure) -> Int32 {
  self.width
}

///|
/// Return the figure height in display units.
pub fn Figure::height(self : Figure) -> Int32 {
  self.height
}

///|
/// Return the plot margin in display units.
pub fn Figure::margin(self : Figure) -> Int32 {
  self.margin
}

///|
/// Return artists from the default axes in insertion order.
pub fn Figure::artists(self : Figure) -> Array[Artist] {
  let artists = self.default_axes_data().val.artists
  let result = Array(capacity=artists.length())
  for artist in artists {
    result.push(copy_artist(artist))
  }
  result
}

///|
/// Return the optional figure title.
pub fn Figure::title(self : Figure) -> String? {
  self.title
}

///|
/// Return the optional x-axis label from the default axes.
pub fn Figure::x_label(self : Figure) -> String? {
  self.default_axes_data().val.x_axis.label()
}

///|
/// Return the optional y-axis label from the default axes.
pub fn Figure::y_label(self : Figure) -> String? {
  self.default_axes_data().val.y_axis.label()
}

///|
/// Return explicit limits from the default axes, if present.
pub fn Figure::explicit_bounds(self : Figure) -> @core.Bounds? {
  self.default_axes_data().val.explicit_bounds
}

///|
/// Return explicit x limits, or the resolved datalim view, on the default axes.
pub fn Figure::x_limits(self : Figure) -> @core.Limits? {
  self.axes().x_limits()
}

///|
/// Return explicit y limits, or the resolved datalim view, on the default axes.
pub fn Figure::y_limits(self : Figure) -> @core.Limits? {
  self.axes().y_limits()
}

///|
/// Return the x-axis object from the default axes.
pub fn Figure::x_axis(self : Figure) -> @axis.Axis {
  self.default_axes_data().val.x_axis
}

///|
/// Return the y-axis object from the default axes.
pub fn Figure::y_axis(self : Figure) -> @axis.Axis {
  self.default_axes_data().val.y_axis
}

///|
/// Set equal data scaling on the default axes panel.
pub fn Figure::set_aspect_equal(self : Figure) -> Unit {
  self.axes().set_aspect_equal()
}

///|
/// Restore automatic aspect handling on the default axes panel.
pub fn Figure::set_aspect_auto(self : Figure) -> Unit {
  self.axes().set_aspect_auto()
}

///|
/// Hide axis decorations on the default axes panel while retaining artists.
pub fn Figure::set_axis_off(self : Figure) -> Unit {
  self.axes().set_axis_off()
}

///|
/// Show axis decorations on the default axes panel.
pub fn Figure::set_axis_on(self : Figure) -> Unit {
  self.axes().set_axis_on()
}

///|
/// Set the x-axis tick label side on the default axes panel.
pub fn Figure::set_x_tick_position(
  self : Figure,
  position : @axis.TickPosition,
) -> Unit {
  self.axes().set_x_tick_position(position)
}

///|
/// Set the y-axis tick label side on the default axes panel.
pub fn Figure::set_y_tick_position(
  self : Figure,
  position : @axis.TickPosition,
) -> Unit {
  self.axes().set_y_tick_position(position)
}

///|
/// Configure major or minor grid lines on the default axes panel.
pub fn Figure::grid(
  self : Figure,
  visible~ : Bool = true,
  which~ : String = "both",
  color~ : String = "#e5e7eb",
  linewidth~ : Double = 1.0,
  axis~ : String = "both",
) -> Unit raise @core.DataError {
  self.axes().grid(visible~, which~, color~, linewidth~, axis~)
}

///|
/// Return the first/default axes panel for this figure.
/// If all panels have been removed, create a 1-by-1 subplot.
pub fn Figure::axes(self : Figure) -> Axes {
  { figure: self, state: self.default_axes_data(), }
}

///|
/// Return handles for all axes panels in creation order.
pub fn Figure::axes_list(self : Figure) -> Array[Axes] {
  let result = Array(capacity=self.axes.length())
  for state in self.axes {
    result.push({ figure: self, state, })
  }
  result
}

///|
/// Add a panel at a GridSpec span. A fresh figure reuses its default panel.
pub fn Figure::add_subplot(self : Figure, spec : @gridspec.SubplotSpec) -> Axes {
  self.add_subplot_with_targets(spec, None, None)
}

///|
/// Add a line plot from paired x/y samples.
pub fn Figure::plot(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().plot(xs, ys, color~, label~)
}

///|
/// Add a line plot from explicit points to the default axes.
pub fn Figure::line(
  self : Figure,
  points : Array[@core.Point],
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  self.axes().line(points, color~, label~)
}

///|
/// Add a scatter plot to the default axes.
pub fn Figure::scatter(
  self : Figure,
  points : Array[@core.Point],
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  self.axes().scatter(points, color~, label~)
}

///|
/// Add bars to the default axes.
pub fn Figure::bar(
  self : Figure,
  points : Array[@core.Point],
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  self.axes().bar(points, color~, label~)
}
