///|
/// A live Exponent view of the logarithmic formatter family.
pub struct LogFormatterExponent {
  priv base : BaseFormatter
}

///|
pub fn LogFormatterExponent::new(
  base~ : LogValue = LogValue::Numeric(ScalarNumber::Number(10.0)),
  label_only_base~ : LogValue = LogValue::Numeric(ScalarNumber::Boolean(false)),
  minor_thresholds~ : LogMinorThresholds? = None,
  linthresh~ : LogValue = LogValue::NoneValue,
) -> LogFormatterExponent raise @core.DataError {
  {
    base: log_formatter_new(
      LogFormatterStyle::Exponent,
      base,
      label_only_base,
      minor_thresholds,
      linthresh,
    ),
  }
}

///|
pub fn BaseFormatter::log_formatter_exponent(
  self : BaseFormatter,
) -> LogFormatterExponent? {
  match self.kind {
    Log(state) =>
      if state.style is Exponent {
        Some({ base: self, })
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn LogFormatterExponent::as_log_formatter(
  self : LogFormatterExponent,
) -> LogFormatter {
  { base: self.base, }
}

///|
pub fn LogFormatterExponent::as_base_formatter(
  self : LogFormatterExponent,
) -> BaseFormatter {
  self.base
}

///|
pub fn LogFormatterExponent::copy(
  self : LogFormatterExponent,
) -> LogFormatterExponent {
  { base: self.base.copy(), }
}

///|
pub fn LogFormatterExponent::base(self : LogFormatterExponent) -> Double {
  self.as_log_formatter().base()
}

///|
pub fn LogFormatterExponent::set_base(
  self : LogFormatterExponent,
  value : LogValue,
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_base(value)
}

///|
pub fn LogFormatterExponent::label_only_base(
  self : LogFormatterExponent,
) -> LogValue {
  self.as_log_formatter().label_only_base()
}

///|
pub fn LogFormatterExponent::set_label_only_base(
  self : LogFormatterExponent,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_label_only_base(value)
}

///|
pub fn LogFormatterExponent::set_label_minor(
  self : LogFormatterExponent,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_label_minor(value)
}

///|
pub fn LogFormatterExponent::minor_thresholds(
  self : LogFormatterExponent,
) -> LogMinorThresholds? {
  self.as_log_formatter().minor_thresholds()
}

///|
pub fn LogFormatterExponent::set_minor_thresholds(
  self : LogFormatterExponent,
  value : LogMinorThresholds?,
) -> Unit {
  self.as_log_formatter().set_minor_thresholds(value)
}

///|
pub fn LogFormatterExponent::linthresh(self : LogFormatterExponent) -> LogValue {
  self.as_log_formatter().linthresh()
}

///|
pub fn LogFormatterExponent::set_linthresh(
  self : LogFormatterExponent,
  value : LogValue,
) -> Unit {
  self.as_log_formatter().set_linthresh(value)
}

///|
pub fn LogFormatterExponent::sublabels(
  self : LogFormatterExponent,
) -> Array[Double]? raise @core.DataError {
  self.as_log_formatter().sublabels()
}

///|
pub fn LogFormatterExponent::locations(
  self : LogFormatterExponent,
) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn LogFormatterExponent::set_locs(
  self : LogFormatterExponent,
  locations? : Array[Double],
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_locs(locations?)
}

///|
pub fn LogFormatterExponent::set_locs_view(
  self : LogFormatterExponent,
  locations : TickValues,
) -> Unit raise @core.DataError {
  self.as_log_formatter().set_locs_view(locations)
}

///|
pub fn LogFormatterExponent::axis(
  self : LogFormatterExponent,
) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn LogFormatterExponent::set_axis(
  self : LogFormatterExponent,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn LogFormatterExponent::create_dummy_axis(
  self : LogFormatterExponent,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn LogFormatterExponent::get_offset(self : LogFormatterExponent) -> String {
  self.base.get_offset()
}

///|
pub fn LogFormatterExponent::call(
  self : LogFormatterExponent,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn LogFormatterExponent::call_value(
  self : LogFormatterExponent,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  self.as_log_formatter().call_value(value, pos?)
}

///|
pub fn LogFormatterExponent::format_data(
  self : LogFormatterExponent,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn LogFormatterExponent::format_data_value(
  self : LogFormatterExponent,
  value : ScalarNumber,
) -> String raise @core.DataError {
  self.as_log_formatter().format_data_value(value)
}

///|
pub fn LogFormatterExponent::format_data_short(
  self : LogFormatterExponent,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
pub fn LogFormatterExponent::format_data_short_value(
  self : LogFormatterExponent,
  value : ScalarNumber,
) -> String raise @core.DataError {
  ignore(self)
  log_named_short(value)
}

///|
pub fn LogFormatterExponent::format_ticks(
  self : LogFormatterExponent,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn LogFormatterExponent::format_ticks_view(
  self : LogFormatterExponent,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}
