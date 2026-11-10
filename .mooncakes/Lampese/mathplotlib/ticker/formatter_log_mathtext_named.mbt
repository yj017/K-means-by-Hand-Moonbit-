///|
/// A live Mathtext view of the logarithmic formatter family.
pub struct LogFormatterMathtext {
  priv base : BaseFormatter
}

///|
pub fn LogFormatterMathtext::new(
  base~ : LogValue = LogValue::Numeric(ScalarNumber::Number(10.0)),
  label_only_base~ : LogValue = LogValue::Numeric(ScalarNumber::Boolean(false)),
  minor_thresholds~ : LogMinorThresholds? = None,
  linthresh~ : LogValue = LogValue::NoneValue,
) -> LogFormatterMathtext raise @core.DataError {
  {
    base: log_formatter_new(
      LogFormatterStyle::Mathtext,
      base,
      label_only_base,
      minor_thresholds,
      linthresh,
    ),
  }
}

///|
pub fn BaseFormatter::log_formatter_mathtext(
  self : BaseFormatter,
) -> LogFormatterMathtext? {
  match self.kind {
    Log(state) =>
      if state.style is (Mathtext | SciNotation) {
        Some({ base: self, })
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn LogFormatterMathtext::as_log_formatter(
  self : LogFormatterMathtext,
) -> LogFormatter {
  { base: self.base, }
}

///|
pub fn LogFormatterMathtext::as_base_formatter(
  self : LogFormatterMathtext,
) -> BaseFormatter {
  self.base
}

///|
pub fn LogFormatterMathtext::copy(
  self : LogFormatterMathtext,
) -> LogFormatterMathtext {
  { base: self.base.copy(), }
}

///|
pub fn LogFormatterMathtext::base(self : LogFormatterMathtext) -> Double {
  self.as_log_formatter().base()
}

///|
pub fn LogFormatterMathtext::set_base(
  self : LogFormatterMathtext,
  value : LogValue,
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_base(value)
}

///|
pub fn LogFormatterMathtext::label_only_base(
  self : LogFormatterMathtext,
) -> LogValue {
  self.as_log_formatter().label_only_base()
}

///|
pub fn LogFormatterMathtext::set_label_only_base(
  self : LogFormatterMathtext,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_label_only_base(value)
}

///|
pub fn LogFormatterMathtext::set_label_minor(
  self : LogFormatterMathtext,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_label_minor(value)
}

///|
pub fn LogFormatterMathtext::minor_thresholds(
  self : LogFormatterMathtext,
) -> LogMinorThresholds? {
  self.as_log_formatter().minor_thresholds()
}

///|
pub fn LogFormatterMathtext::set_minor_thresholds(
  self : LogFormatterMathtext,
  value : LogMinorThresholds?,
) -> Unit {
  self.as_log_formatter().set_minor_thresholds(value)
}

///|
pub fn LogFormatterMathtext::linthresh(self : LogFormatterMathtext) -> LogValue {
  self.as_log_formatter().linthresh()
}

///|
pub fn LogFormatterMathtext::set_linthresh(
  self : LogFormatterMathtext,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_linthresh(value)
}

///|
pub fn LogFormatterMathtext::sublabels(
  self : LogFormatterMathtext,
) -> Array[Double]? raise @core.DataError {
  self.as_log_formatter().sublabels()
}

///|
pub fn LogFormatterMathtext::locations(
  self : LogFormatterMathtext,
) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn LogFormatterMathtext::set_locs(
  self : LogFormatterMathtext,
  locations? : Array[Double],
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_locs(locations?)
}

///|
pub fn LogFormatterMathtext::set_locs_view(
  self : LogFormatterMathtext,
  locations : TickValues,
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_locs_view(locations)
}

///|
pub fn LogFormatterMathtext::axis(
  self : LogFormatterMathtext,
) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn LogFormatterMathtext::set_axis(
  self : LogFormatterMathtext,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn LogFormatterMathtext::create_dummy_axis(
  self : LogFormatterMathtext,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn LogFormatterMathtext::get_offset(self : LogFormatterMathtext) -> String {
  self.base.get_offset()
}

///|
pub fn LogFormatterMathtext::call(
  self : LogFormatterMathtext,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn LogFormatterMathtext::call_value(
  self : LogFormatterMathtext,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  self.as_log_formatter().call_value(value, pos?)
}

///|
pub fn LogFormatterMathtext::format_data(
  self : LogFormatterMathtext,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn LogFormatterMathtext::format_data_value(
  self : LogFormatterMathtext,
  value : ScalarNumber,
) -> String raise @core.DataError {
  self.as_log_formatter().format_data_value(value)
}

///|
pub fn LogFormatterMathtext::format_data_short(
  self : LogFormatterMathtext,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
pub fn LogFormatterMathtext::format_data_short_value(
  self : LogFormatterMathtext,
  value : ScalarNumber,
) -> String raise @core.DataError {
  ignore(self)
  log_named_short(value)
}

///|
pub fn LogFormatterMathtext::format_ticks(
  self : LogFormatterMathtext,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn LogFormatterMathtext::format_ticks_view(
  self : LogFormatterMathtext,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}
