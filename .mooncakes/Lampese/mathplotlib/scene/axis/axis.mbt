///|
/// Locations supported for axis tick labels.
pub(all) enum TickPosition {
  Top
  Bottom
  Left
  Right
  Both
}

///|
/// A coordinate axis with limits, tick formatting, and presentation settings.
pub struct Axis {
  priv mut function_scale : AxisFunctionScale?
  priv units_state : AxisUnitState
  priv formatter_axis_binding : @ticker.FormatterAxisBinding
  priv mut tickers : AxisNumericTickers
  priv formatter_messages : Array[String]
  priv mut minpos_provider : (() -> Double raise @core.DataError)?
  priv mut shared_minpos_provider : (() -> Array[Double] raise @core.DataError)?
  priv mut render_minpos_provider : (() -> Double raise @core.DataError)?
  priv mut render_shared_minpos_provider : (() -> Array[Double] raise @core.DataError)?
  priv mut autoscale_minpos_provider : (() -> Array[Double] raise @core.DataError)?
  priv mut render_autoscale_minpos_provider : (() -> Array[Double] raise @core.DataError)?
  priv mut data_interval_provider : (() -> (Double, Double))?
  priv mut formatter_geometry_provider : (() -> (Double, Double))?
  priv mut tick_layout_origin : Double?
  priv mut tick_length_provider : (() -> Double)?
  priv mut numeric_view_provider : (() -> (Double, Double) raise @core.DataError)?
  priv mut render_view_provider : (() -> (Double, Double) raise @core.DataError)?
  priv mut autoscale_view_provider : (() -> Unit raise @core.DataError)?
  priv mut autoscale_enabled : Bool
  priv mut autoscale_pending : Bool
  priv mut stored_view : @core.Limits
  priv mut tick_layout_length : Double?
  priv mut tick_layout_view : (Double, Double)?
  priv mut tick_layout_active : Bool
  priv mut tick_horizontal : Bool
  priv mut tick_label_size : Double?
  mut limits : @core.Limits?
  mut auto_view : @core.Limits?
  mut inverted : Bool
  mut label : String?
  priv mut label_default : Bool
  mut tick_count : Int32
  priv mut tick_count_configured : Bool
  priv mut date_converter : @date.DateConverter?
  mut category : @category.CategoryAxis?
  mut date_format : String?
  mut date_offset_minutes : Int32
  mut date_timezone : @date.DateTimeZone?
  priv mut date_timezone_is_default : Bool
  priv mut date_timezone_override : Bool
  priv mut remove_minor_overlap : Bool
  mut scale : @scale.Scale
  mut tick_position : TickPosition?
  mut grid_visible : Bool
  mut grid_color : String
  mut grid_width : Double
  mut minor_grid_visible : Bool
  mut minor_grid_color : String
  mut minor_grid_width : Double
}

///|
/// Construct an axis with fresh linear locator and formatter defaults.
pub fn axis(horizontal~ : Bool = true) -> Axis {
  let result : Axis = {
    function_scale: None,
    units_state: AxisUnitState::new(),
    formatter_axis_binding: @ticker.FormatterAxisBinding::new(),
    tickers: AxisNumericTickers::new(),
    formatter_messages: [],
    minpos_provider: None,
    shared_minpos_provider: None,
    render_minpos_provider: None,
    render_shared_minpos_provider: None,
    autoscale_minpos_provider: None,
    render_autoscale_minpos_provider: None,
    data_interval_provider: None,
    formatter_geometry_provider: None,
    tick_layout_origin: None,
    tick_length_provider: None,
    numeric_view_provider: None,
    render_view_provider: None,
    autoscale_view_provider: None,
    autoscale_enabled: true,
    autoscale_pending: false,
    stored_view: @core.limits(0.0, 1.0),
    tick_layout_length: None,
    tick_layout_view: None,
    tick_layout_active: false,
    tick_horizontal: horizontal,
    tick_label_size: None,
    limits: None,
    auto_view: None,
    inverted: false,
    label: None,
    label_default: true,
    tick_count: 6,
    tick_count_configured: false,
    date_converter: None,
    category: None,
    date_format: None,
    date_offset_minutes: 0,
    date_timezone: None,
    date_timezone_is_default: true,
    date_timezone_override: false,
    remove_minor_overlap: true,
    scale: @scale.linear_scale(),
    tick_position: None,
    grid_visible: @config.grid_visible(),
    grid_color: @config.grid_color(),
    grid_width: @config.grid_linewidth(),
    minor_grid_visible: false,
    minor_grid_color: @config.grid_color(),
    minor_grid_width: @config.grid_linewidth() / 2.0,
  }
  result.formatter_axis_binding.bind_view_interval(() => {
    let (lower, upper) = result.view_interval_checked()
    @ticker.FormatterViewInterval::NdArray(
      @ticker.TickValues::from_array([lower, upper]),
    )
  })
  result.formatter_axis_binding.bind_transform_linthresh(() => {
    result.scale
    .symlog_linthresh()
    .map(value => @ticker.ScalarNumber::Number(value))
  })
  // All linear constructors are pure. There is no date/category state or
  // user callback here, so the checked setter's preconditions cannot fail.
  try! result.set_scale(@scale.linear_scale())
  result
}

///|
/// Set explicit limits while preserving their direction.
pub fn Axis::set_limits(
  self : Axis,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  let limits = @core.limits(lower, upper)
  if !limits.is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="axis")
  }
  if self.function_scale is Some(_) {
    ignore(self.set_bound_limits_checked(lower, upper, automatic=Some(false)))
    return
  }
  if self.tickers.major_locator_kind != Numeric {
    ignore(self.set_bound_limits_checked(lower, upper, automatic=Some(false)))
    return
  }
  if self.scale.is_logit() {
    let resolved = self.logit_limit_bounds_checked(lower, upper)
    self.limits = Some(resolved)
    self.auto_view = None
    self.inverted = resolved.lower() > resolved.upper()
    self.stored_view = resolved
    self.autoscale_enabled = false
    self.autoscale_pending = false
    if self.tick_layout_view is Some(_) {
      self.tick_layout_view = Some((resolved.lower(), resolved.upper()))
    }
    return
  }
  if self.scale.is_log() && (lower <= 0.0 || upper <= 0.0) {
    raise @core.DataError::InvalidTicks(
      message="log scale limits must be positive",
    )
  }
  self.limits = Some(limits)
  self.auto_view = None
  self.inverted = lower > upper
  self.stored_view = limits
  self.autoscale_enabled = false
  self.autoscale_pending = false
  if self.tick_layout_view is Some(_) {
    self.tick_layout_view = Some((lower, upper))
  }
}

///|
/// Clear explicit limits and return to automatic range computation,
/// preserving the axis direction.
pub fn Axis::clear_limits(self : Axis) -> Unit {
  self.limits = None
  self.auto_view = None
  self.autoscale_enabled = true
  self.autoscale_pending = true
}

///|
/// Restore tickers, units and presentation while retaining the view and context.
/// Shared peers observe the replacement ticker objects through the same holder.
pub fn Axis::clear(self : Axis) -> Unit {
  self.formatter_messages.clear()
  self.tick_label_size = None
  self.label = None
  self.label_default = true
  self.reset_unit_state()
  self.tick_count = 6
  self.tick_count_configured = false
  self.tickers.automatic_date_locator = None
  self.date_converter = None
  self.category = None
  self.date_format = None
  self.date_offset_minutes = 0
  self.date_timezone = None
  self.date_timezone_is_default = true
  self.date_timezone_override = false
  self.tickers.date_locator = None
  self.tickers.date_formatter = None
  self.tickers.date_formatter_default = false
  self.tickers.minor_date_locator = None
  self.tickers.minor_date_formatter = None
  self.tick_position = None
  self.grid_visible = @config.grid_visible()
  self.grid_color = @config.grid_color()
  self.grid_width = @config.grid_linewidth()
  self.minor_grid_visible = false
  self.minor_grid_color = @config.grid_color()
  self.minor_grid_width = @config.grid_linewidth() / 2.0
  // Clear the typed converter guards before installing numeric defaults. The
  // constructors/setters cannot fail in this linear, callback-free profile.
  // Do not replace the holder or detach any previously retained object.
  try! self.set_scale(@scale.linear_scale())
}

///|
/// Set the coordinate scale for this axis.
pub fn Axis::set_scale(
  self : Axis,
  value : @scale.Scale,
) -> Unit raise @core.DataError {
  if value.is_nonlinear() && self.date_format is Some(_) {
    raise @core.DataError::InvalidTicks(
      message="date axis cannot be combined with a non-linear scale",
    )
  }
  if value.is_log() && self.category is Some(_) {
    raise @core.DataError::InvalidTicks(
      message="log scale cannot be combined with category data",
    )
  }
  self.scale = value
  self.function_scale = None
  self.install_scale_defaults()
  self.mark_scale_defaults()
}

///|
/// Return the configured coordinate scale.
pub fn Axis::scale(self : Axis) -> @scale.Scale {
  self.scale
}

///|
/// Return explicit limits, if any.
pub fn Axis::limits(self : Axis) -> @core.Limits? {
  self.limits
}

///|
/// Set the axis label.
pub fn Axis::set_label(self : Axis, label : String) -> Unit {
  self.label = Some(label)
  self.label_default = false
}

///|
/// Return the optional axis label.
pub fn Axis::label(self : Axis) -> String? {
  self.label
}

///|
/// Set the side on which this axis's tick labels are rendered.
///
/// The renderer interprets `Top`/`Bottom` for an x axis and
/// `Left`/`Right` for a y axis. `Both` renders labels on both sides.
pub fn Axis::set_tick_position(self : Axis, position : TickPosition) -> Unit {
  self.tick_position = Some(position)
}

///|
/// Return the explicitly configured tick label side, if any.
pub fn Axis::tick_position(self : Axis) -> TickPosition? {
  self.tick_position
}

///|
/// Restore the renderer's default tick label side.
pub fn Axis::clear_tick_position(self : Axis) -> Unit {
  self.tick_position = None
}

///|
/// Configure major grid lines for this axis.
///
/// Grid lines are disabled by default, matching Matplotlib's
/// `axes.grid=False`. The renderer consumes the style without changing tick
/// positions or labels.
pub fn Axis::set_grid(
  self : Axis,
  visible : Bool,
  color : String,
  linewidth : Double,
) -> Unit raise @core.DataError {
  if linewidth.is_nan() || linewidth.is_inf() || linewidth <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="grid linewidth must be finite and positive",
    )
  }
  if color.length() == 0 {
    raise @core.DataError::InvalidTicks(message="grid color must not be empty")
  }
  self.grid_visible = visible
  self.grid_color = color
  self.grid_width = linewidth
}

///|
/// Return whether major grid lines are enabled for this axis.
pub fn Axis::grid_visible(self : Axis) -> Bool {
  self.grid_visible
}

///|
/// Return the major grid line color.
pub fn Axis::grid_color(self : Axis) -> String {
  self.grid_color
}

///|
/// Return the major grid line width.
pub fn Axis::grid_width(self : Axis) -> Double {
  self.grid_width
}

///|
/// Configure minor grid lines independently from major grids.
pub fn Axis::set_minor_grid(
  self : Axis,
  visible : Bool,
  color : String,
  linewidth : Double,
) -> Unit raise @core.DataError {
  if linewidth.is_nan() || linewidth.is_inf() || linewidth <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="minor grid linewidth must be finite and positive",
    )
  }
  if color.length() == 0 {
    raise @core.DataError::InvalidTicks(
      message="minor grid color must not be empty",
    )
  }
  self.minor_grid_visible = visible
  self.minor_grid_color = color
  self.minor_grid_width = linewidth
}

///|
/// Return whether minor grid lines are enabled.
pub fn Axis::minor_grid_visible(self : Axis) -> Bool {
  self.minor_grid_visible
}

///|
/// Return the minor grid line color.
pub fn Axis::minor_grid_color(self : Axis) -> String {
  self.minor_grid_color
}

///|
/// Return the minor grid line width.
pub fn Axis::minor_grid_width(self : Axis) -> Double {
  self.minor_grid_width
}

///|
/// Select the convenience scale sampler's desired tick count.
/// An explicitly installed locator keeps control of tick placement.
pub fn Axis::set_tick_count(self : Axis, count : Int32) -> Unit {
  self.tick_count = if count < 2 { 2 } else { count }
  self.tick_count_configured = true
  if self.tickers.major_locator_default &&
    self.tickers.major_locator_kind == Numeric {
    // An explicit convenience count selects the existing scale sampler.
    // It does not replace a locator that the user installed explicitly.
    self.tickers.locator = None
    self.tickers.major_locator_default = false
    self.tickers.major_locator_kind = Numeric
  }
  self.tickers.automatic_date_locator = self.tickers.automatic_date_locator.map(value => {
      try! value.with_maxticks(@date.All(self.tick_count))
    },
  )
}

///|
/// Return the desired number of ticks.
pub fn Axis::tick_count(self : Axis) -> Int32 {
  self.tick_count
}

///|
/// Set a numeric locator for automatic major ticks.
pub fn Axis::set_locator(
  self : Axis,
  locator : @ticker.Locator,
) -> Unit raise @core.DataError {
  if self.function_scale is None {
    match (self.scale, locator) {
      (
        @scale.Scale::Log,
        @ticker.Locator::Linear(..)
        | @ticker.Locator::MaxN(..),
      ) =>
        raise @core.DataError::InvalidTicks(
          message="linear locator cannot be used with log scale",
        )
      (@scale.Scale::Log, @ticker.Locator::Fixed(values)) =>
        for value in values {
          if value <= 0.0 {
            raise @core.DataError::InvalidTicks(
              message="log scale locator values must be positive",
            )
          }
        }
      _ => ()
    }
  }
  self.tickers.major_locator_default = false
  self.tickers.major_locator_kind = Numeric
  self.tickers.locator = Some(locator.copy())
  self.bind_locator_data()
  self.tickers.date_locator = None
  self.tickers.fixed_ticks = None
  self.tickers.fixed_labels = None
}

///|
/// Return the configured numeric locator, if any.
pub fn Axis::locator(self : Axis) -> @ticker.Locator? {
  match self.tickers.locator {
    Some(value) => Some(value.copy())
    None => None
  }
}

///|
/// Clear the numeric locator and use the convenience scale sampler.
pub fn Axis::clear_locator(self : Axis) -> Unit {
  self.tickers.major_locator_default = false
  self.tickers.major_locator_kind = Numeric
  self.tickers.locator = None
  self.tickers.fixed_ticks = None
  self.tickers.fixed_labels = None
}

///|
/// Set a minor locator used between major tick positions.
pub fn Axis::set_minor_locator(
  self : Axis,
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  if self.function_scale is None {
    match (self.scale, locator) {
      (@scale.Scale::Log, @ticker.MinorLocator::Auto(..)) =>
        raise @core.DataError::InvalidTicks(
          message="automatic minor locator cannot be used with log scale",
        )
      (@scale.Scale::Log, @ticker.MinorLocator::Fixed(values)) =>
        for value in values {
          if value <= 0.0 {
            raise @core.DataError::InvalidTicks(
              message="log scale minor locator values must be positive",
            )
          }
        }
      _ => ()
    }
  }
  self.tickers.minor_locator_default = false
  self.tickers.minor_locator_kind = Numeric
  self.tickers.minor_locator = Some(locator.copy())
  self.bind_locator_data(minor=true)
  self.tickers.minor_date_locator = None
}

///|
/// Return the configured minor locator, if any.
pub fn Axis::minor_locator(self : Axis) -> @ticker.MinorLocator? {
  match self.tickers.minor_locator {
    Some(value) => Some(value.copy())
    None => None
  }
}

///|
/// Clear the minor locator.
pub fn Axis::clear_minor_locator(self : Axis) -> Unit {
  self.tickers.minor_locator_default = false
  self.tickers.minor_locator_kind = Numeric
  self.tickers.minor_locator = None
  self.tickers.minor_date_locator = None
}

///|
/// Set fixed tick positions, replacing automatic linear ticks.
pub fn Axis::set_ticks(
  self : Axis,
  values : Array[Double],
) -> Unit raise @core.DataError {
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="tick positions must be finite",
      )
    }
    if self.scale.is_log() && value <= 0.0 {
      raise @core.DataError::InvalidTicks(
        message="log scale tick positions must be positive",
      )
    }
  }
  self.tickers.major_locator_default = false
  self.tickers.major_locator_kind = Numeric
  self.tickers.fixed_ticks = Some(values.copy())
  self.tickers.fixed_labels = None
  self.tickers.locator = None
  self.tickers.date_locator = None
}

///|
/// Configure this axis to format numeric day values as dates.
///
/// An empty format selects a range-dependent format at render time. The
/// numeric values remain Matplotlib day ordinals, so existing plot methods
/// can be used after converting dates with `DateTime::to_ordinal`.
pub fn Axis::set_date_format(
  self : Axis,
  format : String,
) -> Unit raise @core.DataError {
  self.configure_date_format(format)
}

///|
fn Axis::configure_date_format(
  self : Axis,
  format : String,
  unit? : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  if self.scale.is_nonlinear() {
    raise @core.DataError::InvalidTicks(
      message="date axis cannot be combined with a non-linear scale",
    )
  }
  if self.get_category_units() is Some(_) {
    raise @core.DataError::InvalidTicks(
      message="date axis cannot be combined with category data",
    )
  }
  match self.category {
    Some(_) =>
      raise @core.DataError::InvalidTicks(
        message="date axis cannot be combined with category data",
      )
    None => ()
  }
  let converter = self.date_converter.unwrap_or(@date.default_date_converter())
  let unit = match unit {
    Some(_) => unit
    None if !self.date_timezone_is_default =>
      Some(self.explicit_date_timezone())
    None => None
  }
  let info = self.checked_date_axisinfo(converter, unit?)
  self.date_format = Some(format)
  self.date_converter = Some(converter)
  if self.date_timezone_is_default &&
    (self.date_timezone is None || format != "") {
    self.date_timezone = info.major_locator().timezone()
    self.date_offset_minutes = info.major_locator().offset_minutes()
  }
  self.install_date_unit_defaults(info)
  if format != "" && self.tickers.fixed_labels is None {
    self.tickers.major_formatter_kind = Date
    self.tickers.major_formatter_default = false
    self.tickers.date_format = Some(format)
    self.tickers.date_formatter = None
    self.tickers.date_formatter_default = false
    self.tickers.formatter = None
    self.tickers.named_formatter = None
    self.tickers.fixed_labels = None
  }
  self.sync_default_date_formatter()
  self.capture_date_units_extension()
  self.formatter_messages.clear()
}

///|
/// Configure automatic date formatting for this axis.
pub fn Axis::set_date(self : Axis) -> Unit raise @core.DataError {
  self.set_date_format("")
}

///|
/// Set the fixed UTC offset for date tick positions and labels.
///
/// ```mbt check
/// test {
///   let axis = @axis.axis()
///   try! axis.set_date_offset(345)
///   assert_eq(axis.date_offset_minutes(), 345)
/// }
/// ```
pub fn Axis::set_date_offset(
  self : Axis,
  offset_minutes : Int32,
) -> Unit raise @core.DataError {
  if offset_minutes <= -1440 || offset_minutes >= 1440 {
    raise @core.DataError::InvalidTicks(
      message="date offset must be in -1439..1439 minutes",
    )
  }
  if self.date_format is None {
    self.configure_date_format(
      "",
      unit=try! @date.fixed_timezone(offset_minutes),
    )
  }
  self.date_timezone = None
  self.date_timezone_is_default = false
  self.date_timezone_override = true
  match self.tickers.date_locator {
    Some(locator) =>
      self.tickers.date_locator = Some(try! locator.with_offset(offset_minutes))
    None => ()
  }
  self.date_offset_minutes = offset_minutes
  self.tickers.automatic_date_locator = self.tickers.automatic_date_locator.map(value => {
      try! value.with_offset(offset_minutes)
    },
  )
  self.tickers.date_formatter = self.tickers.date_formatter.map(formatter => {
    try! formatter.with_offset(offset_minutes)
  })
  self.tickers.minor_date_locator = self.tickers.minor_date_locator.map(locator => {
    try! locator.with_offset(offset_minutes)
  })
  self.tickers.minor_date_formatter = self.tickers.minor_date_formatter.map(formatter => {
    try! formatter.with_offset(offset_minutes)
  })
  self.capture_date_units_extension()
}

///|
/// Return the fixed UTC offset used for date tick positions and labels.
pub fn Axis::date_offset_minutes(self : Axis) -> Int32 {
  self.date_offset_minutes
}

///|
/// Set an explicit transition-aware timezone for date labels.
///
/// Calendar tick positions and label conversion follow the configured UTC
/// transitions. Spring gaps are skipped and fall folds can emit both instants.
pub fn Axis::set_date_timezone(
  self : Axis,
  timezone : @date.DateTimeZone,
) -> Unit raise @core.DataError {
  if self.date_format is None {
    self.configure_date_format("", unit=timezone)
  }
  let offset_minutes = timezone.initial_offset_minutes()
  match self.tickers.date_locator {
    Some(locator) =>
      self.tickers.date_locator = Some(locator.with_timezone(timezone))
    None => ()
  }
  self.date_offset_minutes = offset_minutes
  self.date_timezone = Some(timezone)
  self.date_timezone_is_default = false
  self.date_timezone_override = true
  self.tickers.automatic_date_locator = self.tickers.automatic_date_locator.map(value => {
      value.with_timezone(timezone)
    },
  )
  self.tickers.date_formatter = self.tickers.date_formatter.map(formatter => {
    formatter.with_timezone(timezone)
  })
  self.tickers.minor_date_locator = self.tickers.minor_date_locator.map(locator => {
    locator.with_timezone(timezone)
  })
  self.tickers.minor_date_formatter = self.tickers.minor_date_formatter.map(formatter => {
    formatter.with_timezone(timezone)
  })
  self.capture_date_units_extension()
}

///|
/// Return the transition-aware timezone used for date labels, if configured.
pub fn Axis::date_timezone(self : Axis) -> @date.DateTimeZone? {
  self.date_timezone
}

///|
/// Use an explicit calendar locator while retaining automatic date labels.
pub fn Axis::set_date_locator(
  self : Axis,
  locator : @date.DateLocator,
) -> Unit raise @core.DataError {
  if self.scale.is_nonlinear() {
    raise @core.DataError::InvalidTicks(
      message="date axis cannot be combined with a non-linear scale",
    )
  }
  match self.date_format {
    Some(_) => ()
    None => self.set_date()
  }
  let effective_locator = if !self.date_timezone_override {
    locator.copy()
  } else {
    match self.date_timezone {
      Some(timezone) => locator.with_timezone(timezone)
      None => locator.copy()
    }
  }
  self.tickers.date_locator = Some(effective_locator)
  self.date_offset_minutes = effective_locator.offset_minutes()
  if self.date_timezone_is_default && effective_locator.timezone() is None {
    // Preserve the legacy explicit fixed-offset locator extension. Ordinary
    // constructors now carry a captured zone, so their labels remain dynamic.
    self.date_timezone = None
    self.date_timezone_is_default = false
    self.date_timezone_override = true
  }
  self.sync_default_date_formatter()
  self.tickers.major_locator_kind = Date
  self.tickers.major_locator_default = false
  self.tickers.locator = None
  self.tickers.fixed_ticks = None
  self.bind_locator_data()
  self.formatter_messages.clear()
  self.capture_date_units_extension()
}

///|
/// Clear date formatting and return to numeric tick labels.
pub fn Axis::clear_date(self : Axis) -> Unit {
  self.clear_date_units_extension()
  if self.tickers.major_locator_kind == Date {
    self.tickers.major_locator_kind = Numeric
  }
  if self.tickers.minor_locator_kind == Date {
    self.tickers.minor_locator_kind = Numeric
  }
  if self.tickers.major_formatter_kind == Date {
    self.tickers.major_formatter_kind = Numeric
  }
  if self.tickers.minor_formatter_kind == Date {
    self.tickers.minor_formatter_kind = Numeric
  }
  self.date_format = None
  self.tickers.date_formatter = None
  self.tickers.automatic_date_locator = None
  self.date_converter = None
  self.tickers.date_formatter_default = false
  self.tickers.minor_date_locator = None
  self.tickers.minor_date_formatter = None
  self.date_timezone = None
  self.date_timezone_is_default = true
  self.date_timezone_override = false
  self.tickers.date_locator = None
  self.date_offset_minutes = 0
}

///|
/// Return the explicit date format, if date mode is enabled.
pub fn Axis::date_format(self : Axis) -> String? {
  self.date_format
}

///|
/// Return the explicit date locator, if configured.
pub fn Axis::date_locator(self : Axis) -> @date.DateLocator? {
  self.tickers.date_locator.map(value => value.copy())
}

///|
/// Configure the numeric formatter used for this axis's tick labels.
pub fn Axis::set_formatter(self : Axis, formatter : @ticker.Formatter) -> Unit {
  self.tickers.major_formatter_default = false
  self.tickers.major_formatter_kind = Numeric
  self.tickers.formatter = Some(formatter.copy())
  self.tickers.named_formatter = None
  self.formatter_messages.clear()
}

///|
/// Return the configured numeric formatter, if any.
pub fn Axis::formatter(self : Axis) -> @ticker.Formatter? {
  match self.tickers.formatter {
    Some(value) => Some(value.copy())
    None => None
  }
}

///|
/// Return the shared text selected by the numeric or date formatter, if any.
pub fn Axis::formatter_offset_label(
  self : Axis,
  values : Array[Double],
) -> String {
  self.formatter_offset_label_with_view(values, self.limits)
}

///|
/// Return the numeric or date formatter's offset label for an explicit viewport.
///
/// Renderers should pass the viewport they used to generate the ticks.  When
/// it is omitted, an explicitly configured axis limit is used and otherwise
/// the formatter falls back to the supplied tick extent.
pub fn Axis::formatter_offset_label_with_view(
  self : Axis,
  values : Array[Double],
  view : @core.Limits?,
) -> String {
  if self.tickers.major_formatter_kind == Numeric &&
    self.tickers.named_formatter is Some(value) {
    return value.get_offset_checked() catch { _ => "" }
  }
  // Explicit labels own their text, and category axes have no shared offset.
  if self.tickers.fixed_labels is Some(_) ||
    self.category_for_labels() is Some(_) {
    return ""
  }
  if self.date_format_for_labels() is Some(_) {
    return match self.tickers.date_formatter {
      Some(formatter) => {
        let (ticks, inverted, _) = self.date_formatter_values(values, view)
        formatter
        .with_locator_unit(self.date_formatter_unit(values, view, false))
        .offset_label(ticks, inverted~)
      }
      None => ""
    }
  }
  let effective_view = match view {
    Some(_) => view
    None => self.limits
  }
  match self.tickers.formatter {
    Some(value) => value.offset_label_with_view(values, effective_view)
    None => ""
  }
}

///|
/// Clear the numeric formatter and restore scale-based labels.
pub fn Axis::clear_formatter(self : Axis) -> Unit {
  self.tickers.major_formatter_default = false
  self.tickers.major_formatter_kind = Numeric
  self.tickers.formatter = None
  self.tickers.named_formatter = None
}

///|
/// Clear fixed tick positions and labels.
pub fn Axis::clear_ticks(self : Axis) -> Unit {
  self.tickers.fixed_ticks = None
  self.tickers.fixed_labels = None
}

///|
/// Configure an axis with an ordered set of string categories.
pub fn Axis::set_categories(
  self : Axis,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.set_category_units(CategoryUnits::new(labels))
}

///|
/// Replace the categorical convenience configuration with a shared live mapping.
/// This explicit replacement extension does not emit a source units event.
pub fn Axis::set_category_units(
  self : Axis,
  units : CategoryUnits,
) -> Unit raise @core.DataError {
  if self.scale.is_nonlinear() {
    raise @core.DataError::InvalidTicks(
      message="category data cannot be combined with a non-linear scale",
    )
  }
  match self.date_format {
    Some(_) =>
      raise @core.DataError::InvalidTicks(
        message="category data cannot be combined with date axis",
      )
    None => ()
  }
  let converter = @category.category().with_labels(units.labels())
  self.category = Some(converter)
  self.replace_category_units_extension(units)
  self.tickers.major_locator_default = true
  self.tickers.major_formatter_default = true
  self.install_category_unit_defaults(units)
  self.formatter_messages.clear()
}

///|
/// Clear category conversion and return to numeric tick generation.
pub fn Axis::clear_categories(self : Axis) -> Unit {
  self.clear_category_units_extension()
  self.category = None
  if self.tickers.major_locator_kind == Category {
    self.tickers.major_locator_kind = Numeric
  }
  if self.tickers.major_formatter_kind == Category {
    self.tickers.major_formatter_kind = Numeric
  }
}

///|
/// Return category labels in first-seen order, if configured.
pub fn Axis::categories(self : Axis) -> Array[String]? {
  match self.get_category_units() {
    Some(units) => Some(units.labels())
    None => self.category.map(converter => converter.labels())
  }
}

///|
/// Convert string values and retain their categories on this axis.
pub fn Axis::category_positions(
  self : Axis,
  values : Array[String],
) -> Array[Double] raise @core.DataError {
  if !self.have_units() {
    ignore(self.update_category_units(values))
  }
  self.convert_category_units(values)
}

///|
/// Set labels for the currently fixed tick positions.
pub fn Axis::set_tick_labels(
  self : Axis,
  labels : Array[String],
) -> Unit raise @core.DataError {
  match self.tickers.fixed_ticks {
    Some(values) =>
      if values.length() != labels.length() {
        raise @core.DataError::InvalidTicks(
          message="tick labels must match tick positions",
        )
      } else {
        self.tickers.major_formatter_default = false
        self.tickers.major_formatter_kind = Numeric
        self.tickers.fixed_labels = Some(labels.copy())
        self.tickers.named_formatter = None
      }
    None =>
      raise @core.DataError::InvalidTicks(
        message="set tick positions before tick labels",
      )
  }
}

///|
/// Return fixed tick positions, if configured.
pub fn Axis::ticks(self : Axis) -> Array[Double]? {
  match self.tickers.fixed_ticks {
    Some(values) => Some(values.copy())
    None => None
  }
}

///|
/// Format labels for a concrete tick list.
pub fn Axis::tick_labels(self : Axis, values : Array[Double]) -> Array[String] {
  self.tick_labels_with_view(values, self.limits)
}

///|
/// Format labels for a concrete tick list and viewport.
pub fn Axis::tick_labels_with_view(
  self : Axis,
  values : Array[Double],
  view : @core.Limits?,
) -> Array[String] {
  if self.tickers.major_formatter_kind == Numeric &&
    self.tickers.named_formatter is Some(value) {
    return value.format_ticks(values) catch { _ => [] }
  }
  match self.tickers.fixed_labels {
    Some(labels) => labels.copy()
    None =>
      match self.category_for_labels() {
        Some(converter) => converter.format_values(values) catch { _ => [] }
        None => {
          let result = Array(capacity=values.length())
          match self.date_format_for_labels() {
            Some(format) => {
              if self.tickers.date_formatter is Some(formatter) {
                let (ticks, inverted, reversed) = self.date_formatter_values(
                  values, view,
                )
                let labels = formatter
                  .with_locator_unit(
                    self.date_formatter_unit(values, view, false),
                  )
                  .format_values(ticks, inverted~)
                return if reversed { labels.rev() } else { labels }
              }
              let timezone = self.date_timezone
              let labels = match timezone {
                Some(timezone) =>
                  @date.format_date_ticks(
                    values,
                    format~,
                    offset_minutes=self.date_offset_minutes,
                    timezone~,
                  )
                None =>
                  @date.format_date_ticks(
                    values,
                    format~,
                    offset_minutes=self.date_offset_minutes,
                  )
              }
              for label in labels {
                result.push(label)
              }
            }
            None =>
              match self.tickers.formatter {
                Some(formatter) => {
                  let effective_view = match view {
                    Some(_) => view
                    None => self.limits
                  }
                  let labels = formatter.format_values_with_view(
                    values, effective_view,
                  )
                  for label in labels {
                    result.push(label)
                  }
                }
                None =>
                  for value in values {
                    result.push(self.scale.format_tick(value))
                  }
              }
          }
          result
        }
      }
  }
}

///|
/// Generate ticks for explicit or supplied automatic limits.
pub fn Axis::tick_values(
  self : Axis,
  automatic : @core.Limits,
) -> Array[Double] {
  if self.tickers.fixed_ticks is None &&
    (self.category_for_ticks() is None || self.numeric_tickers_active()) &&
    self.tickers.locator
    is Some(
      @ticker.Locator::NamedLogit(_)
      | @ticker.Locator::NamedAsinh(_)
      | @ticker.Locator::NamedSymLog(_)
      | @ticker.Locator::NamedLog(_)
      | @ticker.Locator::Null(_)
      | @ticker.Locator::NamedLinear(_)
      | @ticker.Locator::NamedFixed(_)
      | @ticker.Locator::Index(_)
      | @ticker.Locator::NamedMaxN(_)
      | @ticker.Locator::NamedAuto(_)
    ) {
    return self.tick_values_checked(automatic) catch { _ => [] }
  }
  match self.tickers.fixed_ticks {
    Some(values) => values.copy()
    None =>
      match self.category_for_ticks() {
        Some(converter) => converter.positions()
        None => {
          let limits = match self.limits {
            Some(value) => value
            None => automatic
          }
          let limits = self.date_nonsingular_bounds(
            limits.lower(),
            limits.upper(),
          )
          match self.date_format_for_ticks() {
            Some(_) =>
              match self.tickers.date_locator {
                Some(locator) =>
                  locator.tick_values(limits.lower(), limits.upper())
                None => {
                  if self.tickers.locator is Some(locator) {
                    return locator.tick_values(limits.lower(), limits.upper())
                  }
                  if self.tickers.automatic_date_locator is Some(locator) {
                    return locator.tick_values(limits.lower(), limits.upper()) catch {
                      _ => []
                    }
                  }
                  let timezone = self.date_timezone
                  @date.date_tick_values(
                    limits.lower(),
                    limits.upper(),
                    count=self.tick_count,
                    offset_minutes=self.date_offset_minutes,
                    timezone?,
                  )
                }
              }
            None =>
              match self.tickers.locator {
                Some(locator) =>
                  locator.tick_values(limits.lower(), limits.upper())
                None => self.scale.tick_values(limits, count=self.tick_count)
              }
          }
        }
      }
  }
}

///|
/// Generate minor ticks from the configured minor locator.
pub fn Axis::minor_tick_values(
  self : Axis,
  automatic : @core.Limits,
) -> Array[Double] {
  if self.tickers.minor_locator_kind == Numeric &&
    self.tickers.minor_formatter_kind != Numeric &&
    self.tickers.minor_locator is Some(@ticker.MinorLocator::Fixed(_)) {
    return self.minor_tick_values_checked(automatic) catch { _ => [] }
  }
  if self.tickers.minor_locator_kind == Numeric &&
    self.tickers.minor_locator
    is Some(
      @ticker.MinorLocator::NamedLogit(_)
      | @ticker.MinorLocator::NamedAsinh(_)
      | @ticker.MinorLocator::NamedSymLog(_)
      | @ticker.MinorLocator::NamedLog(_)
      | @ticker.MinorLocator::Null(_)
      | @ticker.MinorLocator::NamedAutoMinor(_)
      | @ticker.MinorLocator::NamedLinear(_)
      | @ticker.MinorLocator::Index(_)
      | @ticker.MinorLocator::NamedFixed(_)
      | @ticker.MinorLocator::NamedMaxN(_)
      | @ticker.MinorLocator::NamedAuto(_)
    ) {
    return self.minor_tick_values_checked(automatic) catch { _ => [] }
  }
  if self.tickers.minor_locator_kind == Date &&
    self.tickers.minor_date_locator is Some(locator) {
    let limits = self.limits.unwrap_or(automatic)
    let limits = self.date_nonsingular_bounds(limits.lower(), limits.upper())
    let ticks = locator.tick_values(limits.lower(), limits.upper())
    return self.filter_date_minor_ticks(
      ticks,
      self.tick_values(automatic),
      limits,
    )
  }
  match self.tickers.minor_locator {
    None => []
    Some(locator) => {
      let limits = match self.limits {
        Some(value) => value
        None => automatic
      }
      let major = self.tick_values(automatic)
      if self.date_format_for_ticks() is Some(_) {
        let ticks = match locator {
          @ticker.MinorLocator::Fixed(_) =>
            locator.tick_values([], limits.lower(), limits.upper())
          _ => locator.tick_values(major, limits.lower(), limits.upper())
        }
        self.filter_date_minor_ticks(ticks, major, limits)
      } else {
        locator.tick_values(major, limits.lower(), limits.upper())
      }
    }
  }
}
