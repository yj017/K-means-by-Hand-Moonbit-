///|
/// Return the effective legend entries for the current axes.
pub fn get_legend_handles_labels() -> Array[@scene.LegendEntry] {
  require_axes().get_legend_handles_labels()
}

///|
/// Set the current figure title.
pub fn title(value : String) -> Unit {
  require_axes().set_title(value)
}

///|
/// Set the current x-axis label.
pub fn xlabel(value : String) -> Unit {
  require_axes().set_x_label(value)
}

///|
/// Set the current y-axis label.
pub fn ylabel(value : String) -> Unit {
  require_axes().set_y_label(value)
}

///|
/// Toggle common axes display modes.
///
/// Supported modes are `"on"`, `"off"`, `"equal"`, `"auto"`, and
/// `"tight"`.
/// equal restores automatic ranges and uses datalim adjustment; it rejects
/// panels sharing both x and y before resetting their view.
pub fn axis(mode~ : String = "on") -> Unit raise @core.DataError {
  match mode {
    "on" => require_axes().set_axis_on()
    "off" => require_axes().set_axis_off()
    "equal" => {
      require_axes().set_aspect(1.0, adjustable="datalim")
      try! require_axes().autoscale()
    }
    "auto" => {
      require_axes().set_aspect_auto()
      try! require_axes().autoscale()
    }
    "tight" => try! require_axes().autoscale(tight=true)
    _ =>
      raise @core.DataError::InvalidTicks(
        message="axis mode must be 'on', 'off', 'equal', 'auto', or 'tight'",
      )
  }
}

///|
/// Hide the current axes decorations.
pub fn axis_off() -> Unit {
  require_axes().set_axis_off()
}

///|
/// Show the current axes decorations.
pub fn axis_on() -> Unit {
  require_axes().set_axis_on()
}

///|
/// Configure major or minor grid lines on the current axes.
pub fn grid(
  visible~ : Bool = true,
  which~ : String = "both",
  color~ : String = "#e5e7eb",
  linewidth~ : Double = 1.0,
  axis~ : String = "both",
) -> Unit raise @core.DataError {
  require_axes().grid(visible~, which~, color~, linewidth~, axis~)
}

///|
/// Set explicit legend entries on the current axes.
pub fn legend(entries : Array[@scene.LegendEntry]) -> Unit {
  require_axes().set_legend(entries)
}

///|
/// Set x-axis limits on the current figure.
pub fn xlim(lower : Double, upper : Double) -> Unit raise @core.DataError {
  require_axes().set_x_limits(lower, upper)
}

///|
/// Set y-axis limits on the current figure.
pub fn ylim(lower : Double, upper : Double) -> Unit raise @core.DataError {
  require_axes().set_y_limits(lower, upper)
}

///|
/// Return the automatic `(x, y)` margins around the current axes data.
pub fn margins() -> (Double, Double) {
  require_axes().margins()
}

///|
/// Set both automatic margins around the current axes data.
pub fn set_margins(x : Double, y : Double) -> Unit raise @core.DataError {
  require_axes().set_margins(x, y)
}

///|
/// Set the automatic x-axis margin on the current axes.
pub fn set_xmargin(value : Double) -> Unit raise @core.DataError {
  require_axes().set_x_margin(value)
}

///|
/// Set the automatic y-axis margin on the current axes.
pub fn set_ymargin(value : Double) -> Unit raise @core.DataError {
  require_axes().set_y_margin(value)
}

///|
/// Toggle automatic view updates on the current axes and schedule selected views.
/// enable=None retains the switches and requests both coordinates.
pub fn autoscale(
  axis~ : String = "both",
  enable~ : Bool? = Some(true),
  tight? : Bool,
) -> Unit raise @core.DataError {
  require_axes().autoscale(axis~, enable~, tight?)
}

///|
/// Recompute selected automatic views without enabling their autoscale switches.
pub fn autoscale_view(
  tight? : Bool,
  scalex~ : Bool = true,
  scaley~ : Bool = true,
  axis~ : String = "both",
) -> Unit raise @core.DataError {
  require_axes().autoscale_view(tight?, scalex~, scaley~, axis~)
}

///|
/// Set the current x-axis scale.
pub fn xscale(value : @scale.Scale) -> Unit raise @core.DataError {
  require_axes().set_x_scale(value)
}

///|
/// Set the current y-axis scale.
pub fn yscale(value : @scale.Scale) -> Unit raise @core.DataError {
  require_axes().set_y_scale(value)
}

///|
/// Set fixed x-axis ticks and optional labels on the current axes.
pub fn xticks(
  values : Array[Double],
  labels~ : Array[String] = [],
) -> Unit raise @core.DataError {
  let axes = require_axes()
  axes.set_x_ticks(values)
  if labels.length() > 0 {
    axes.set_x_tick_labels(labels)
  }
}

///|
/// Set fixed y-axis ticks and optional labels on the current axes.
pub fn yticks(
  values : Array[Double],
  labels~ : Array[String] = [],
) -> Unit raise @core.DataError {
  let axes = require_axes()
  axes.set_y_ticks(values)
  if labels.length() > 0 {
    axes.set_y_tick_labels(labels)
  }
}

///|
/// Configure a numeric major locator on the current x axis.
pub fn xaxis_locator(locator : @ticker.Locator) -> Unit raise @core.DataError {
  require_axes().set_x_locator(locator)
}

///|
/// Configure a numeric major locator on the current y axis.
pub fn yaxis_locator(locator : @ticker.Locator) -> Unit raise @core.DataError {
  require_axes().set_y_locator(locator)
}

///|
/// Configure a numeric formatter on the current x axis.
pub fn xaxis_formatter(formatter : @ticker.Formatter) -> Unit {
  require_axes().set_x_formatter(formatter)
}

///|
/// Configure a numeric formatter on the current y axis.
pub fn yaxis_formatter(formatter : @ticker.Formatter) -> Unit {
  require_axes().set_y_formatter(formatter)
}

///|
/// Configure a minor locator on the current x axis.
pub fn xaxis_minor_locator(
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  require_axes().set_x_minor_locator(locator)
}

///|
/// Configure a minor locator on the current y axis.
pub fn yaxis_minor_locator(
  locator : @ticker.MinorLocator,
) -> Unit raise @core.DataError {
  require_axes().set_y_minor_locator(locator)
}

///|
/// Add a secondary x axis derived from the primary x coordinate.
pub fn secondary_xaxis(
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  location~ : @scene.SecondaryAxisLocation = @scene.SecondaryAxisLocation::Top,
  transform~ : @transforms.Affine2D? = None,
) -> @scene.SecondaryAxis raise @core.DataError {
  require_axes().secondary_xaxis(forward, inverse, location~, transform~)
}

///|
/// Add a secondary y axis derived from the primary y coordinate.
pub fn secondary_yaxis(
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  location~ : @scene.SecondaryAxisLocation = @scene.SecondaryAxisLocation::Right,
  transform~ : @transforms.Affine2D? = None,
) -> @scene.SecondaryAxis raise @core.DataError {
  require_axes().secondary_yaxis(forward, inverse, location~, transform~)
}
