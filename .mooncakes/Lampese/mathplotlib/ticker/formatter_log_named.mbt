///|
priv enum LogFormatterStyle {
  Plain
  Exponent
  Mathtext
  SciNotation
}

///|
priv struct LogFormatterState {
  style : LogFormatterStyle
  mut base : Double
  mut label_only_base : LogValue
  mut minor_thresholds : LogMinorThresholds?
  mut linthresh : LogValue
  mut sublabels : LogSublabelCache?
}

///|
let log_default_thresholds : LogThresholdTuple = LogThresholdTuple::new([
  LogValue::Numeric(ScalarNumber::Integer(@bigint.BigInt::from_int(1))),
  LogValue::Numeric(ScalarNumber::Number(0.4)),
])

///|
let log_classic_thresholds : LogThresholdTuple = LogThresholdTuple::new([
  LogValue::Numeric(ScalarNumber::Integer(@bigint.BigInt::from_int(0))),
  LogValue::Numeric(ScalarNumber::Integer(@bigint.BigInt::from_int(0))),
])

///|
fn log_formatter_new(
  style : LogFormatterStyle,
  base : LogValue,
  label_only_base : LogValue,
  minor_thresholds : LogMinorThresholds?,
  linthresh : LogValue,
) -> BaseFormatter raise @core.DataError {
  let base = log_base_float(base)
  let minor_thresholds = Some(
    match minor_thresholds {
      Some(value) => value
      None =>
        LogMinorThresholds::Tuple(
          if @config.classic_mode() {
            log_classic_thresholds
          } else {
            log_default_thresholds
          },
        )
    },
  )
  named_formatter_with_kind(
    FormatterKind::Log({
      style,
      base,
      label_only_base,
      minor_thresholds,
      linthresh,
      sublabels: None,
    }),
  )
}

///|
fn log_formatter_state(formatter : BaseFormatter) -> LogFormatterState {
  match formatter.kind {
    Log(state) => state
    _ => abort("invalid LogFormatter kind")
  }
}

///|
/// A live logarithmic formatter, including derived family views.
pub struct LogFormatter {
  priv base : BaseFormatter
}

///|
pub fn LogFormatter::new(
  base~ : LogValue = LogValue::Numeric(ScalarNumber::Number(10.0)),
  label_only_base~ : LogValue = LogValue::Numeric(ScalarNumber::Boolean(false)),
  minor_thresholds~ : LogMinorThresholds? = None,
  linthresh~ : LogValue = LogValue::NoneValue,
) -> LogFormatter raise @core.DataError {
  {
    base: log_formatter_new(
      LogFormatterStyle::Plain,
      base,
      label_only_base,
      minor_thresholds,
      linthresh,
    ),
  }
}

///|
pub fn BaseFormatter::log_formatter(self : BaseFormatter) -> LogFormatter? {
  match self.kind {
    Log(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn LogFormatter::base(self : LogFormatter) -> Double {
  log_formatter_state(self.base).base
}

///|
pub fn LogFormatter::set_base(
  self : LogFormatter,
  value : LogValue,
) -> Unit raise @core.DataError {
  let value = log_base_float(value)
  log_formatter_state(self.base).base = value
}

///|
pub fn LogFormatter::label_only_base(self : LogFormatter) -> LogValue {
  log_formatter_state(self.base).label_only_base
}

///|
pub fn LogFormatter::set_label_only_base(
  self : LogFormatter,
  value : LogValue,
) -> Unit {
  log_formatter_state(self.base).label_only_base = value
}

///|
pub fn LogFormatter::set_label_minor(
  self : LogFormatter,
  value : LogValue,
) -> Unit {
  self.set_label_only_base(value)
}

///|
pub fn LogFormatter::minor_thresholds(
  self : LogFormatter,
) -> LogMinorThresholds? {
  log_formatter_state(self.base).minor_thresholds
}

///|
pub fn LogFormatter::set_minor_thresholds(
  self : LogFormatter,
  value : LogMinorThresholds?,
) -> Unit {
  log_formatter_state(self.base).minor_thresholds = value
}

///|
pub fn LogFormatter::linthresh(self : LogFormatter) -> LogValue {
  log_formatter_state(self.base).linthresh
}

///|
pub fn LogFormatter::set_linthresh(
  self : LogFormatter,
  value : LogValue,
) -> Unit {
  log_formatter_state(self.base).linthresh = value
}

///|
pub fn LogFormatter::sublabels(
  self : LogFormatter,
) -> Array[Double]? raise @core.DataError {
  log_formatter_state(self.base).sublabels.map(fn(cache) raise @core.DataError {
    log_cache_values(cache)
  })
}

///|
pub fn LogFormatter::as_base_formatter(self : LogFormatter) -> BaseFormatter {
  self.base
}

///|
pub fn LogFormatter::copy(self : LogFormatter) -> LogFormatter {
  { base: self.base.copy(), }
}

///|
pub fn LogFormatter::locations(self : LogFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn LogFormatter::set_locs(
  self : LogFormatter,
  locations? : Array[Double],
) -> Unit raise @core.DataError {
  ignore(locations)
  log_named_prepare(self.base, log_formatter_state(self.base))
}

///|
pub fn LogFormatter::set_locs_view(
  self : LogFormatter,
  locations : TickValues,
) -> Unit raise @core.DataError {
  ignore(locations)
  log_named_prepare(self.base, log_formatter_state(self.base))
}

///|
pub fn LogFormatter::axis(self : LogFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn LogFormatter::set_axis(
  self : LogFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn LogFormatter::create_dummy_axis(
  self : LogFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn LogFormatter::get_offset(self : LogFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn LogFormatter::call(
  self : LogFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn LogFormatter::call_value(
  self : LogFormatter,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  log_named_call(self.base, log_formatter_state(self.base), value, pos)
}

///|
pub fn LogFormatter::format_data(
  self : LogFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn LogFormatter::format_data_value(
  self : LogFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  log_named_data(self.base, log_formatter_state(self.base), value)
}

///|
pub fn LogFormatter::format_data_short(
  self : LogFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
pub fn LogFormatter::format_data_short_value(
  self : LogFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  ignore(self)
  log_named_short(value)
}

///|
pub fn LogFormatter::format_ticks(
  self : LogFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn LogFormatter::format_ticks_view(
  self : LogFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}
