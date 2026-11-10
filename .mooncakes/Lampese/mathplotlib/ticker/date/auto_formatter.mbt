///|
/// String or callable entries in AutoDateFormatter.scaled. Scalar callbacks
/// receive the original numeric value and optional position; they own TeX output.
/// Array callbacks are used by the explicit format_array/format_dates methods.
pub(all) enum DateScaleFormat {
  Text(String)
  Func((Double, Int32?) -> String)
  ValuesFunc((Array[Double], Int32?) -> Array[String])
  DatesFunc((Array[DateTime], Int32?) -> Array[String])
}

///|
priv struct AutoSettings {
  scaled : Array[(Double, DateScaleFormat)]
  unit : Double
  locator : DateLocator?
}

///|
pub struct AutoDateFormatter {
  priv formatter : DateFormatter
}

///|
/// Construct a locator-unit formatter and capture the rc format table. Text
/// entries resolve the original tz argument at each call (the current timezone
/// rc if omitted); custom callbacks receive original inputs without resolution.
/// The first scaled key >= the base unit wins, regardless of locator interval.
/// An omitted locator uses the upstream missing-unit fallback of one day.
///
/// ```mbt check
/// test {
///   let formatter = @date.AutoDateFormatter::new(
///     locator=@date.minute_locator(interval=30),
///   )
///   assert_eq(formatter.unit_scale(), 1.0 / 1440.0)
///   assert_eq(formatter.format_value(0.0), "01 00:00")
/// }
/// ```
pub fn AutoDateFormatter::new(
  locator? : DateLocator,
  tz? : String,
  timezone? : DateTimeZone,
  default_format~ : String = "%Y-%m-%d",
  usetex~ : Bool = false,
) -> AutoDateFormatter raise DateError {
  let zone = selected_timezone(tz, timezone)
  let timezone_source = formatter_timezone_source(tz, timezone)
  let formats = @config.date_autoformats()
  let units = [
    365.0,
    30.0,
    1.0,
    1.0 / 24.0,
    1.0 / 1440.0,
    1.0 / 86400.0,
    1.0 / 86_400_000_000.0,
  ]
  let scaled : Array[(Double, DateScaleFormat)] = []
  for index in 0..<units.length() {
    scaled.push((units[index], Text(formats[index])))
  }
  scaled.sort_by_key(entry => entry.0)
  {
    formatter: {
      format: default_format,
      offset_minutes: zone.initial_offset_minutes(),
      timezone: Some(zone),
      timezone_source,
      mode: Auto({
        scaled,
        unit: locator.map(value => value.unit_scale()).unwrap_or(1.0),
        locator,
      }),
      usetex,
    },
  }
}

///|
fn DateFormatter::auto_settings(self : DateFormatter) -> AutoSettings {
  match self.mode {
    Auto(settings) => settings
    _ => abort("automatic formatter invariant")
  }
}

///|
fn AutoSettings::selected(
  self : AutoSettings,
  default_format : String,
) -> DateScaleFormat {
  for entry in self.scaled {
    if entry.0 >=
      self.locator.map(value => value.unit_scale()).unwrap_or(self.unit) {
      return entry.1
    }
  }
  Text(default_format)
}

///|
pub fn AutoDateFormatter::as_formatter(
  self : AutoDateFormatter,
) -> DateFormatter {
  self.formatter.copy()
}

///|
pub fn AutoDateFormatter::unit_scale(self : AutoDateFormatter) -> Double {
  let settings = self.formatter.auto_settings()
  settings.locator.map(value => value.unit_scale()).unwrap_or(settings.unit)
}

///|
pub fn AutoDateFormatter::default_format(self : AutoDateFormatter) -> String {
  self.formatter.format
}

///|
pub fn AutoDateFormatter::scaled(
  self : AutoDateFormatter,
) -> Array[(Double, DateScaleFormat)] {
  self.formatter.auto_settings().scaled.copy()
}

///|
/// Replace the scale dictionary. Repeated keys take the last value. Negative
/// and infinite keys are supported; NaN keys are rejected as unordered.
pub fn AutoDateFormatter::with_scaled(
  self : AutoDateFormatter,
  entries : Array[(Double, DateScaleFormat)],
) -> AutoDateFormatter raise DateError {
  let scaled : Array[(Double, DateScaleFormat)] = []
  for entry in entries {
    if entry.0.is_nan() {
      raise DateError::InvalidFormat(message="date scaled keys must not be NaN")
    }
    let mut replaced = false
    for index in 0..<scaled.length() {
      if scaled[index].0 == entry.0 {
        scaled[index] = entry
        replaced = true
        break
      }
    }
    if !replaced {
      scaled.push(entry)
    }
  }
  scaled.sort_by_key(entry => entry.0)
  let settings = self.formatter.auto_settings()
  {
    formatter: { ..self.formatter.copy(), mode: Auto({ ..settings, scaled, }), },
  }
}

///|
/// Set one scale entry while retaining the remaining dictionary.
pub fn AutoDateFormatter::with_scale(
  self : AutoDateFormatter,
  scale : Double,
  format : DateScaleFormat,
) -> AutoDateFormatter raise DateError {
  let entries = self.scaled()
  entries.push((scale, format))
  self.with_scaled(entries)
}

///|
/// Copy the formatter for a new concrete locator.
pub fn AutoDateFormatter::with_locator(
  self : AutoDateFormatter,
  locator : DateLocator,
) -> AutoDateFormatter {
  let settings = self.formatter.auto_settings()
  {
    formatter: {
      ..self.formatter.copy(),
      mode: Auto({
        ..settings,
        scaled: settings.scaled.copy(),
        locator: Some(locator),
      }),
    },
  }
}

///|
/// Bind a custom locator's base unit. Standard axes derive this automatically
/// from the actual major/minor locator, including after replacement or zoom.
pub fn AutoDateFormatter::with_locator_unit(
  self : AutoDateFormatter,
  unit : Double,
) -> AutoDateFormatter {
  { formatter: self.formatter.with_locator_unit(unit), }
}

///|
pub fn AutoDateFormatter::with_default_format(
  self : AutoDateFormatter,
  format : String,
) -> AutoDateFormatter {
  { formatter: { ..self.formatter.copy(), format, }, }
}

///|
pub fn AutoDateFormatter::with_offset(
  self : AutoDateFormatter,
  offset_minutes : Int32,
) -> AutoDateFormatter raise DateError {
  { formatter: self.formatter.with_offset(offset_minutes), }
}

///|
pub fn AutoDateFormatter::with_timezone(
  self : AutoDateFormatter,
  timezone : DateTimeZone,
) -> AutoDateFormatter {
  { formatter: self.formatter.with_timezone(timezone), }
}

///|
pub fn AutoDateFormatter::with_usetex(
  self : AutoDateFormatter,
  usetex : Bool,
) -> AutoDateFormatter {
  { formatter: self.formatter.with_usetex(usetex), }
}

///|
pub fn AutoDateFormatter::format_value(
  self : AutoDateFormatter,
  value : Double,
  pos? : Int32,
) -> String raise DateError {
  self.formatter.auto_value(value, pos)
}

///|
/// Standard Formatter.format_ticks semantics: call each scalar with its index.
pub fn AutoDateFormatter::format_ticks(
  self : AutoDateFormatter,
  values : Array[Double],
) -> Array[String] raise DateError {
  let (labels, _) = self.formatter.tick_layout(values, false)
  labels
}

///|
/// Pass an entire numeric array unchanged to the selected ValuesFunc callback.
pub fn AutoDateFormatter::format_array(
  self : AutoDateFormatter,
  values : Array[Double],
  pos? : Int32,
) -> Array[String] raise DateError {
  match self.formatter.auto_settings().selected(self.formatter.format) {
    ValuesFunc(function) => function(values, pos)
    _ =>
      raise DateError::InvalidFormat(
        message="array date input requires a ValuesFunc scale entry",
      )
  }
}

///|
/// Pass original date objects to a DatesFunc callback without numeric conversion.
pub fn AutoDateFormatter::format_dates(
  self : AutoDateFormatter,
  values : Array[DateTime],
  pos? : Int32,
) -> Array[String] raise DateError {
  match self.formatter.auto_settings().selected(self.formatter.format) {
    DatesFunc(function) => function(values, pos)
    _ =>
      raise DateError::InvalidFormat(
        message="date-array input requires a DatesFunc scale entry",
      )
  }
}
