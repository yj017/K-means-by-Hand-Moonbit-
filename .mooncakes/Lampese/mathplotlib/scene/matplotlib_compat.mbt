///|
/// Matplotlib-style aliases for the object-oriented scene API.
///
/// The aliases keep the existing value types and error behavior while making
/// common examples easier to port from `matplotlib.pyplot`.

///|
pub fn Figure::suptitle(self : Figure, title : String) -> Unit {
  self.set_title(title)
}

///|
pub fn Figure::get_axes(self : Figure) -> Array[Axes] {
  self.axes_list()
}

///|
pub fn Figure::set_xlabel(self : Figure, label : String) -> Unit {
  self.set_x_label(label)
}

///|
pub fn Figure::set_ylabel(self : Figure, label : String) -> Unit {
  self.set_y_label(label)
}

///|
pub fn Figure::set_xlim(
  self : Figure,
  lower : Double,
  upper : Double,
  auto~ : Bool? = Some(false),
) -> Unit raise @core.DataError {
  self.axes().set_xlim(lower, upper, auto~)
}

///|
pub fn Figure::set_ylim(
  self : Figure,
  lower : Double,
  upper : Double,
  auto~ : Bool? = Some(false),
) -> Unit raise @core.DataError {
  self.axes().set_ylim(lower, upper, auto~)
}

///|
/// Matplotlib spelling for setting the x-axis scale.
pub fn Figure::set_xscale(
  self : Figure,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.set_x_scale(value)
}

///|
/// Matplotlib spelling for setting the y-axis scale.
pub fn Figure::set_yscale(
  self : Figure,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.set_y_scale(value)
}

///|
/// Matplotlib spelling for setting the automatic x-axis margin.
pub fn Figure::set_xmargin(
  self : Figure,
  value : Double,
) -> Unit raise @core.DataError {
  self.set_x_margin(value)
}

///|
/// Matplotlib spelling for setting the automatic y-axis margin.
pub fn Figure::set_ymargin(
  self : Figure,
  value : Double,
) -> Unit raise @core.DataError {
  self.set_y_margin(value)
}

///|
pub fn Figure::set_xticks(
  self : Figure,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.set_x_ticks(values)
}

///|
pub fn Figure::set_yticks(
  self : Figure,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.set_y_ticks(values)
}

///|
pub fn Figure::set_xticklabels(
  self : Figure,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.set_x_tick_labels(labels)
}

///|
pub fn Figure::set_yticklabels(
  self : Figure,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.set_y_tick_labels(labels)
}

///|
pub fn Axes::get_figure(self : Axes) -> Figure {
  self.figure()
}

///|
pub fn Axes::get_title(self : Axes) -> String? {
  self.title()
}

///|
pub fn Axes::set_xlabel(self : Axes, label : String) -> Unit {
  self.set_x_label(label)
}

///|
pub fn Axes::set_ylabel(self : Axes, label : String) -> Unit {
  self.set_y_label(label)
}

///|
pub fn Axes::get_xlabel(self : Axes) -> String? {
  self.state.val.x_axis.label()
}

///|
pub fn Axes::get_ylabel(self : Axes) -> String? {
  self.state.val.y_axis.label()
}

///|
pub fn Axes::set_xlim(
  self : Axes,
  lower : Double,
  upper : Double,
  auto~ : Bool? = Some(false),
) -> Unit raise @core.DataError {
  self.set_coordinate_limits_checked(lower, upper, true, auto)
}

///|
pub fn Axes::set_ylim(
  self : Axes,
  lower : Double,
  upper : Double,
  auto~ : Bool? = Some(false),
) -> Unit raise @core.DataError {
  self.set_coordinate_limits_checked(lower, upper, false, auto)
}

///|
/// Matplotlib spelling for setting the x-axis scale.
pub fn Axes::set_xscale(
  self : Axes,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.set_x_scale(value)
}

///|
/// Matplotlib spelling for setting the y-axis scale.
pub fn Axes::set_yscale(
  self : Axes,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  self.set_y_scale(value)
}

///|
/// Matplotlib spelling for setting the automatic x-axis margin.
pub fn Axes::set_xmargin(
  self : Axes,
  value : Double,
) -> Unit raise @core.DataError {
  self.set_x_margin(value)
}

///|
/// Matplotlib spelling for setting the automatic y-axis margin.
pub fn Axes::set_ymargin(
  self : Axes,
  value : Double,
) -> Unit raise @core.DataError {
  self.set_y_margin(value)
}

///|
/// Return the automatic `(x, y)` margins for this axes.
pub fn Axes::get_margins(self : Axes) -> (Double, Double) {
  self.margins()
}

///|
pub fn Axes::get_xlim(self : Axes) -> @core.Limits? {
  Some(try! self.get_xlim_checked())
}

///|
pub fn Axes::get_ylim(self : Axes) -> @core.Limits? {
  Some(try! self.get_ylim_checked())
}

///|
pub fn Axes::set_xticks(
  self : Axes,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.set_x_ticks(values)
}

///|
pub fn Axes::set_yticks(
  self : Axes,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.set_y_ticks(values)
}

///|
pub fn Axes::set_xticklabels(
  self : Axes,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.set_x_tick_labels(labels)
}

///|
pub fn Axes::set_yticklabels(
  self : Axes,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.set_y_tick_labels(labels)
}

///|
pub fn Axes::get_subplotspec(self : Axes) -> @gridspec.SubplotSpec? {
  self.state.val.subplot_spec
}
