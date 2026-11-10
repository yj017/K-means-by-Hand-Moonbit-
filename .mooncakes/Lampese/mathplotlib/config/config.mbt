///|
/// Mutable defaults shared by newly created figures and axes.
pub struct RcParams {
  priv mut formatter_min_exponent : @bigint.BigInt
  priv mut formatter_use_offset : Bool
  priv mut formatter_use_math_text : Bool
  priv mut formatter_use_locale : Bool
  priv mut formatter_offset_threshold : @bigint.BigInt
  priv mut formatter_limits : Array[@bigint.BigInt]
  priv mut text_usetex : Bool
  priv mut unicode_minus : Bool
  priv mut x_minor_ticks_visible : Bool
  priv mut y_minor_ticks_visible : Bool
  priv mut x_minor_tick_divisions : MinorTickDivisions
  priv mut y_minor_tick_divisions : MinorTickDivisions
  priv mut classic_mode : Bool
  priv mut axes_autolimit_mode : String
  priv mut timezone : String
  priv mut date_converter : String
  priv mut date_interval_multiples : Bool
  priv mut lines_scale_dashes : Bool
  priv mut lines_dashed_pattern : Array[Double]
  priv mut lines_dashdot_pattern : Array[Double]
  priv mut lines_dotted_pattern : Array[Double]
  priv date_autoformats : Array[String]
  mut date_epoch : String
  color_cycle : Array[String]
  mut x_margin : Double
  mut y_margin : Double
  mut grid_visible : Bool
  mut grid_color : String
  mut grid_linewidth : Double
}

///|
fn tab10() -> Array[String] {
  [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b", "#e377c2",
    "#7f7f7f", "#bcbd22", "#17becf",
  ]
}

///|
fn default_rc_params() -> RcParams {
  {
    formatter_min_exponent: @bigint.BigInt::from_int(0),
    formatter_use_offset: true,
    formatter_use_math_text: false,
    formatter_use_locale: false,
    formatter_offset_threshold: @bigint.BigInt::from_int(4),
    formatter_limits: [
      @bigint.BigInt::from_int(-5),
      @bigint.BigInt::from_int(6),
    ],
    text_usetex: false,
    unicode_minus: true,
    x_minor_ticks_visible: false,
    y_minor_ticks_visible: false,
    x_minor_tick_divisions: Text("auto"),
    y_minor_tick_divisions: Text("auto"),
    classic_mode: false,
    axes_autolimit_mode: "data",
    timezone: "UTC",
    date_converter: "auto",
    date_interval_multiples: true,
    lines_scale_dashes: true,
    lines_dashed_pattern: [3.7, 1.6],
    lines_dashdot_pattern: [6.4, 1.6, 1.0, 1.6],
    lines_dotted_pattern: [1.0, 1.65],
    date_autoformats: [
      "%Y", "%Y-%m", "%Y-%m-%d", "%m-%d %H", "%d %H:%M", "%H:%M:%S", "%M:%S.%f",
    ],
    date_epoch: "1970-01-01T00:00:00",
    color_cycle: tab10(),
    x_margin: 0.05,
    y_margin: 0.05,
    grid_visible: false,
    grid_color: "#e5e7eb",
    grid_linewidth: 1.0,
  }
}

///|
let current : @ref.Ref[RcParams] = @ref.new(default_rc_params())

///|
fn validate_margin(value : Double) -> Unit raise @core.DataError {
  if value.is_nan() || value.is_inf() || value <= -0.5 {
    raise @core.DataError::InvalidTicks(
      message="axes margins must be finite and greater than -0.5",
    )
  }
}

///|
fn validate_color_cycle(colors : Array[String]) -> Unit raise @core.DataError {
  if colors.length() == 0 {
    raise @core.DataError::InvalidTicks(
      message="color cycle must contain at least one color",
    )
  }
  for color in colors {
    if color.length() == 0 {
      raise @core.DataError::InvalidTicks(
        message="color cycle entries must not be empty",
      )
    }
  }
}

///|
/// Return a copy of the current defaults.
pub fn rc_params() -> RcParams {
  let value = current.val
  {
    formatter_min_exponent: value.formatter_min_exponent,
    formatter_use_offset: value.formatter_use_offset,
    formatter_use_math_text: value.formatter_use_math_text,
    formatter_use_locale: value.formatter_use_locale,
    formatter_offset_threshold: value.formatter_offset_threshold,
    formatter_limits: value.formatter_limits,
    text_usetex: value.text_usetex,
    unicode_minus: value.unicode_minus,
    x_minor_ticks_visible: value.x_minor_ticks_visible,
    y_minor_ticks_visible: value.y_minor_ticks_visible,
    x_minor_tick_divisions: value.x_minor_tick_divisions,
    y_minor_tick_divisions: value.y_minor_tick_divisions,
    classic_mode: value.classic_mode,
    axes_autolimit_mode: value.axes_autolimit_mode,
    timezone: value.timezone,
    date_converter: value.date_converter,
    date_interval_multiples: value.date_interval_multiples,
    lines_scale_dashes: value.lines_scale_dashes,
    lines_dashed_pattern: value.lines_dashed_pattern.copy(),
    lines_dashdot_pattern: value.lines_dashdot_pattern.copy(),
    lines_dotted_pattern: value.lines_dotted_pattern.copy(),
    date_autoformats: value.date_autoformats.copy(),
    date_epoch: value.date_epoch,
    color_cycle: value.color_cycle.copy(),
    x_margin: value.x_margin,
    y_margin: value.y_margin,
    grid_visible: value.grid_visible,
    grid_color: value.grid_color,
    grid_linewidth: value.grid_linewidth,
  }
}

///|
/// Restore the default tab10 cycle and 5% automatic margins.
pub fn reset() -> Unit {
  current.val = default_rc_params()
}

///|
/// Return the configured default color cycle.
pub fn color_cycle() -> Array[String] {
  current.val.color_cycle.copy()
}

///|
/// Replace the configured default color cycle.
pub fn set_color_cycle(colors : Array[String]) -> Unit raise @core.DataError {
  validate_color_cycle(colors)
  current.val.color_cycle.clear()
  for color in colors {
    current.val.color_cycle.push(color)
  }
}

///|
/// Return the configured default x-axis margin.
pub fn x_margin() -> Double {
  current.val.x_margin
}

///|
/// Replace the configured default x-axis margin.
pub fn set_x_margin(value : Double) -> Unit raise @core.DataError {
  validate_margin(value)
  current.val.x_margin = value
}

///|
/// Return the configured default y-axis margin.
pub fn y_margin() -> Double {
  current.val.y_margin
}

///|
/// Replace the configured default y-axis margin.
pub fn set_y_margin(value : Double) -> Unit raise @core.DataError {
  validate_margin(value)
  current.val.y_margin = value
}

///|
/// Return whether newly created axes show major grid lines.
pub fn grid_visible() -> Bool {
  current.val.grid_visible
}

///|
/// Return the default major grid color.
pub fn grid_color() -> String {
  current.val.grid_color
}

///|
/// Return the default major grid linewidth.
pub fn grid_linewidth() -> Double {
  current.val.grid_linewidth
}

///|
/// Replace the defaults used by newly created axes for major grid lines.
pub fn set_grid(
  visible : Bool,
  color : String,
  linewidth : Double,
) -> Unit raise @core.DataError {
  if color.length() == 0 {
    raise @core.DataError::InvalidTicks(message="grid color must not be empty")
  }
  if linewidth.is_nan() || linewidth.is_inf() || linewidth <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="grid linewidth must be finite and positive",
    )
  }
  current.val.grid_visible = visible
  current.val.grid_color = color
  current.val.grid_linewidth = linewidth
}

///|
/// Return a copy of the configured color cycle.
pub fn RcParams::color_cycle(self : RcParams) -> Array[String] {
  self.color_cycle.copy()
}

///|
pub fn RcParams::x_margin(self : RcParams) -> Double {
  self.x_margin
}

///|
pub fn RcParams::y_margin(self : RcParams) -> Double {
  self.y_margin
}

///|
pub fn RcParams::grid_visible(self : RcParams) -> Bool {
  self.grid_visible
}

///|
pub fn RcParams::grid_color(self : RcParams) -> String {
  self.grid_color
}

///|
pub fn RcParams::grid_linewidth(self : RcParams) -> Double {
  self.grid_linewidth
}

///|
/// Return the fallback origin used when the date package first selects an epoch.
pub fn date_epoch() -> String {
  current.val.date_epoch
}

///|
/// Configure a validated UTC ISO fallback. An already selected date epoch is
/// unaffected, including when other configuration defaults are reset.
pub fn set_date_epoch(value : String) -> Unit raise @core.DataError {
  match @date_epoch.parse(value) {
    Ok(_) => current.val.date_epoch = value
    Err(message) => raise @core.DataError::InvalidTicks(message~)
  }
}

///|
pub fn RcParams::date_epoch(self : RcParams) -> String {
  self.date_epoch
}

///|
/// Default behavior of MultipleLocator.view_limits: data or round_numbers.
pub fn axes_autolimit_mode() -> String {
  current.val.axes_autolimit_mode
}

///|
pub fn set_axes_autolimit_mode(value : String) -> Unit raise @core.DataError {
  if value != "data" && value != "round_numbers" {
    raise @core.DataError::InvalidTicks(
      message="axes.autolimit_mode must be data or round_numbers",
    )
  }
  current.val.axes_autolimit_mode = value
}

///|
pub fn RcParams::axes_autolimit_mode(self : RcParams) -> String {
  self.axes_autolimit_mode
}
