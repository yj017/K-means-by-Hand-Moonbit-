///|
/// A live SciNotation view of the logarithmic formatter family.
pub struct LogFormatterSciNotation {
  priv base : BaseFormatter
}

///|
pub fn LogFormatterSciNotation::new(
  base~ : LogValue = LogValue::Numeric(ScalarNumber::Number(10.0)),
  label_only_base~ : LogValue = LogValue::Numeric(ScalarNumber::Boolean(false)),
  minor_thresholds~ : LogMinorThresholds? = None,
  linthresh~ : LogValue = LogValue::NoneValue,
) -> LogFormatterSciNotation raise @core.DataError {
  {
    base: log_formatter_new(
      LogFormatterStyle::SciNotation,
      base,
      label_only_base,
      minor_thresholds,
      linthresh,
    ),
  }
}

///|
pub fn BaseFormatter::log_formatter_sci_notation(
  self : BaseFormatter,
) -> LogFormatterSciNotation? {
  match self.kind {
    Log(state) =>
      if state.style is SciNotation {
        Some({ base: self, })
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn LogFormatterSciNotation::as_log_formatter(
  self : LogFormatterSciNotation,
) -> LogFormatter {
  { base: self.base, }
}

///|
pub fn LogFormatterSciNotation::as_base_formatter(
  self : LogFormatterSciNotation,
) -> BaseFormatter {
  self.base
}

///|
pub fn LogFormatterSciNotation::copy(
  self : LogFormatterSciNotation,
) -> LogFormatterSciNotation {
  { base: self.base.copy(), }
}

///|
pub fn LogFormatterSciNotation::as_mathtext_formatter(
  self : LogFormatterSciNotation,
) -> LogFormatterMathtext {
  { base: self.base, }
}

///|
pub fn LogFormatterSciNotation::base(self : LogFormatterSciNotation) -> Double {
  self.as_log_formatter().base()
}

///|
pub fn LogFormatterSciNotation::set_base(
  self : LogFormatterSciNotation,
  value : LogValue,
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_base(value)
}

///|
pub fn LogFormatterSciNotation::label_only_base(
  self : LogFormatterSciNotation,
) -> LogValue {
  self.as_log_formatter().label_only_base()
}

///|
pub fn LogFormatterSciNotation::set_label_only_base(
  self : LogFormatterSciNotation,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_label_only_base(value)
}

///|
pub fn LogFormatterSciNotation::set_label_minor(
  self : LogFormatterSciNotation,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_label_minor(value)
}

///|
pub fn LogFormatterSciNotation::minor_thresholds(
  self : LogFormatterSciNotation,
) -> LogMinorThresholds? {
  self.as_log_formatter().minor_thresholds()
}

///|
pub fn LogFormatterSciNotation::set_minor_thresholds(
  self : LogFormatterSciNotation,
  value : LogMinorThresholds?,
) -> Unit {
  self.as_log_formatter().set_minor_thresholds(value)
}

///|
pub fn LogFormatterSciNotation::linthresh(
  self : LogFormatterSciNotation,
) -> LogValue {
  self.as_log_formatter().linthresh()
}

///|
pub fn LogFormatterSciNotation::set_linthresh(
  self : LogFormatterSciNotation,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_linthresh(value)
}

///|
pub fn LogFormatterSciNotation::sublabels(
  self : LogFormatterSciNotation,
) -> Array[Double]? raise @core.DataError {
  self.as_log_formatter().sublabels()
}

///|
pub fn LogFormatterSciNotation::locations(
  self : LogFormatterSciNotation,
) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn LogFormatterSciNotation::set_locs(
  self : LogFormatterSciNotation,
  locations? : Array[Double],
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_locs(locations?)
}

///|
pub fn LogFormatterSciNotation::set_locs_view(
  self : LogFormatterSciNotation,
  locations : TickValues,
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_locs_view(locations)
}

///|
pub fn LogFormatterSciNotation::axis(
  self : LogFormatterSciNotation,
) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn LogFormatterSciNotation::set_axis(
  self : LogFormatterSciNotation,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn LogFormatterSciNotation::create_dummy_axis(
  self : LogFormatterSciNotation,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn LogFormatterSciNotation::get_offset(
  self : LogFormatterSciNotation,
) -> String {
  self.base.get_offset()
}

///|
pub fn LogFormatterSciNotation::call(
  self : LogFormatterSciNotation,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn LogFormatterSciNotation::call_value(
  self : LogFormatterSciNotation,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  self.as_log_formatter().call_value(value, pos?)
}

///|
pub fn LogFormatterSciNotation::format_data(
  self : LogFormatterSciNotation,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn LogFormatterSciNotation::format_data_value(
  self : LogFormatterSciNotation,
  value : ScalarNumber,
) -> String raise @core.DataError {
  self.as_log_formatter().format_data_value(value)
}

///|
pub fn LogFormatterSciNotation::format_data_short(
  self : LogFormatterSciNotation,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
pub fn LogFormatterSciNotation::format_data_short_value(
  self : LogFormatterSciNotation,
  value : ScalarNumber,
) -> String raise @core.DataError {
  ignore(self)
  log_named_short(value)
}

///|
pub fn LogFormatterSciNotation::format_ticks(
  self : LogFormatterSciNotation,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn LogFormatterSciNotation::format_ticks_view(
  self : LogFormatterSciNotation,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}
