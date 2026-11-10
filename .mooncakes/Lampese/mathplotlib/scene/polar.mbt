///|
/// The direction of increasing polar angles; all angle inputs are radians.
pub(all) enum PolarDirection {
  CounterClockwise
  Clockwise
} derive(Eq, Debug)

///|
pub extend PolarDirection with Eq::{equal, not_equal}

///|
pub extend PolarDirection with @debug.Debug::{to_repr}

///|
priv struct PolarState {
  mut radius_max : Double?
  mut theta_offset : Double
  mut direction : PolarDirection
  mut theta_ticks : Array[Double]
  mut theta_labels : Array[String]
  mut radius_ticks : Array[Double]?
  mut radius_labels : Array[String]
  closed : Array[Bool]
  hit_data : Array[@render.PolarHitData]
  mut radar_labels : Array[String]?
  mut cartesian_grid : Array[(Bool, String, Double, Bool, String, Double)]
  mut cartesian_margins : (Double, Double)
}

///|
/// A polar panel retaining original theta/radius samples independently of its
/// projected SVG. Plot helpers return no mutable Cartesian Line2D handle.
pub struct PolarAxes {
  priv axes : Axes
}

///|
/// Add an independent full-circle polar panel at a normalized Figure rectangle.
pub fn Figure::add_polar_axes(
  self : Figure,
  left : Double,
  bottom : Double,
  width : Double,
  height : Double,
) -> PolarAxes raise @gridspec.LayoutError {
  let axes = self.add_axes(left, bottom, width, height)
  axes.state.val.polar = Some({
    radius_max: None,
    theta_offset: 0.0,
    direction: CounterClockwise,
    theta_ticks: [
      for i in 0..<8 => i.to_double() * @math.PI / 4.0
    ],
    theta_labels: [
      for i in 0..<8 => "\{i * 45}°"
    ],
    radius_ticks: None,
    radius_labels: [],
    closed: [],
    hit_data: [],
    radar_labels: None,
    cartesian_grid: [
      polar_grid_signature(axes.x_axis()),
      polar_grid_signature(axes.y_axis()),
    ],
    cartesian_margins: axes.margins(),
  })
  { axes, }
}

///|
fn PolarAxes::config(self : PolarAxes) -> PolarState {
  self.axes.state.val.polar.unwrap()
}

///|
fn AxesData::polar_projection(self : AxesData) -> @render.PolarProjection? {
  self.polar.map(p => {
    @render.polar_projection(
      p.radius_max,
      p.theta_offset,
      p.direction == Clockwise,
      p.theta_ticks,
      p.theta_labels,
      p.radius_ticks,
      p.radius_labels,
      p.closed,
      cartesian_compatible=p.cartesian_grid ==
        [polar_grid_signature(self.x_axis), polar_grid_signature(self.y_axis)] &&
        p.cartesian_margins == (self.x_margin, self.y_margin),
      hit_data=p.hit_data,
    )
  })
}

///|
fn polar_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn polar_grid_signature(
  axis : @axis.Axis,
) -> (Bool, String, Double, Bool, String, Double) {
  (
    axis.grid_visible(),
    axis.grid_color(),
    axis.grid_width(),
    axis.minor_grid_visible(),
    axis.minor_grid_color(),
    axis.minor_grid_width(),
  )
}

///|
fn polar_nonnegative(
  value : Double,
  name : String,
) -> Unit raise @core.DataError {
  if !polar_finite(value) || value < 0.0 {
    raise @core.DataError::InvalidReference(
      message="polar \{name} must be finite and nonnegative",
    )
  }
}

///|
/// Draw straight chords through projected samples. A closed path adds only a
/// rendered closing vertex, and closes only when every original pair is valid.
pub fn PolarAxes::plot(
  self : PolarAxes,
  theta : Array[Double],
  radius : Array[Double],
  closed~ : Bool = false,
  color~ : String = "",
  linewidth~ : Double = 1.5,
  label~ : String = "",
) -> Unit raise @core.DataError {
  polar_nonnegative(linewidth, "linewidth")
  let points = @core.series(theta, radius).points()
  let resolved = self.axes.resolve_color(color)
  self.axes.push_artist(Line(points, @core.style(resolved, width=linewidth)))
  self.config().closed.push(closed)
  self.config().hit_data.push(@render.polar_hit_data(points, label))
  self.axes.add_auto_legend(label, resolved, LegendKind::Line)
}

///|
/// Draw filled sectors centered at theta, with one required angular width in
/// radians. Radii begin at zero; nonpositive or missing samples keep their slots.
pub fn PolarAxes::bar(
  self : PolarAxes,
  theta : Array[Double],
  radius : Array[Double],
  width~ : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  if !polar_finite(width) || width <= 0.0 || width > 2.0 * @math.PI {
    raise @core.DataError::InvalidReference(
      message="polar bar width must be finite and in (0, 2pi] radians",
    )
  }
  let points = @core.series(theta, radius).points()
  let resolved = self.axes.resolve_color(color)
  self.axes.push_artist(
    Bar(points, @core.style(resolved, width=0.0, fill=resolved)),
  )
  self.config().closed.push(false)
  self.config().hit_data.push(@render.polar_bar_hit_data(points, label, width))
  self.axes.add_auto_legend(label, resolved, LegendKind::Patch)
}

///|
/// Draw circular markers; size is their SVG pixel radius, not marker area.
pub fn PolarAxes::scatter(
  self : PolarAxes,
  theta : Array[Double],
  radius : Array[Double],
  color~ : String = "",
  size~ : Double = 3.5,
  label~ : String = "",
) -> Unit raise @core.DataError {
  polar_nonnegative(size, "marker size")
  let points = @core.series(theta, radius).points()
  let resolved = self.axes.resolve_color(color)
  self.axes.push_artist(
    Scatter(points, @core.style(resolved, width=0.0, radius=size)),
  )
  self.config().closed.push(false)
  self.config().hit_data.push(
    @render.polar_hit_data(points, label, scatter=true),
  )
  self.axes.add_auto_legend(label, resolved, LegendKind::Marker)
}

///|
/// Draw a closed outline with equally spaced categories. Multiple radar calls
/// in one panel require exactly the same ordered labels.
pub fn PolarAxes::radar(
  self : PolarAxes,
  values : Array[Double],
  labels : Array[String],
  color~ : String = "",
  linewidth~ : Double = 1.5,
  label~ : String = "",
) -> Unit raise @core.DataError {
  if values.length() != labels.length() {
    raise @core.DataError::LengthMismatch(
      expected=values.length(),
      actual=labels.length(),
    )
  }
  if values.length() < 3 {
    raise @core.DataError::InvalidReference(
      message="radar needs at least three categories",
    )
  }
  polar_nonnegative(linewidth, "linewidth")
  let config = self.config()
  if config.radar_labels is Some(previous) && previous != labels {
    raise @core.DataError::InvalidReference(
      message="radar category labels must match this panel",
    )
  }
  let theta = [
    for i in 0..<values.length() => {
      2.0 * @math.PI * i.to_double() / values.length().to_double()
    }
  ]
  self.plot(theta, values, closed=true, color~, linewidth~, label~)
  let last = config.hit_data.length() - 1
  config.hit_data[last] = config.hit_data[last].with_categories(labels)
  config.radar_labels = Some(labels.copy())
  config.theta_ticks = theta
  config.theta_labels = labels.copy()
}

///|
pub fn PolarAxes::set_radius_max(
  self : PolarAxes,
  value : Double,
) -> Unit raise @core.DataError {
  if !polar_finite(value) || value <= 0.0 {
    raise @core.DataError::InvalidReference(
      message="polar radius maximum must be finite and positive",
    )
  }
  self.config().radius_max = Some(value)
}

///|
pub fn PolarAxes::set_theta_offset(
  self : PolarAxes,
  radians : Double,
) -> Unit raise @core.DataError {
  if !polar_finite(radians) {
    raise @core.DataError::InvalidReference(
      message="polar theta offset must be finite radians",
    )
  }
  self.config().theta_offset = radians
}

///|
pub fn PolarAxes::set_direction(
  self : PolarAxes,
  direction : PolarDirection,
) -> Unit {
  self.config().direction = direction
}

///|
fn validate_polar_ticks(
  values : Array[Double],
  labels : Array[String],
  radial : Bool,
) -> Unit raise @core.DataError {
  if !labels.is_empty() && labels.length() != values.length() {
    raise @core.DataError::LengthMismatch(
      expected=values.length(),
      actual=labels.length(),
    )
  }
  for value in values {
    if !polar_finite(value) || (radial && value < 0.0) {
      raise @core.DataError::InvalidReference(
        message="polar ticks must be finite; radius ticks must be nonnegative",
      )
    }
  }
}

///|
pub fn PolarAxes::set_theta_ticks(
  self : PolarAxes,
  values : Array[Double],
  labels~ : Array[String] = [],
) -> Unit raise @core.DataError {
  validate_polar_ticks(values, labels, false)
  self.config().theta_ticks = values.copy()
  self.config().theta_labels = labels.copy()
}

///|
pub fn PolarAxes::set_radius_ticks(
  self : PolarAxes,
  values : Array[Double],
  labels~ : Array[String] = [],
) -> Unit raise @core.DataError {
  validate_polar_ticks(values, labels, true)
  self.config().radius_ticks = Some(values.copy())
  self.config().radius_labels = labels.copy()
}

///|
pub fn PolarAxes::set_title(self : PolarAxes, value : String) -> Unit {
  self.axes.set_title(value)
}

///|
pub fn PolarAxes::set_legend(
  self : PolarAxes,
  entries : Array[LegendEntry],
) -> Unit {
  self.axes.set_legend(entries)
}

///|
pub fn PolarAxes::legend(
  self : PolarAxes,
  entries : Array[LegendEntry],
) -> Unit {
  self.set_legend(entries)
}

///|
pub fn PolarAxes::set_legend_position(
  self : PolarAxes,
  position : LegendPosition,
) -> Unit {
  self.axes.set_legend_position(position)
}

///|
pub fn PolarAxes::legend_entries(self : PolarAxes) -> Array[LegendEntry] {
  self.axes.legend_entries()
}

///|
/// Remove series/title/legend while retaining the polar projection and settings.
pub fn PolarAxes::clear(self : PolarAxes) -> Unit {
  self.axes.clear()
}
