///|
priv struct LogitFormatterState {
  mut use_overline : LogValue
  mut one_half : LogValue
  minor : LogValue
  mut minor_threshold : LogValue
  mut minor_number : LogValue
  labelled : LogitLabelled
}

///|
fn logit_formatter_state(formatter : BaseFormatter) -> LogitFormatterState {
  match formatter.kind {
    Logit(state) => state
    _ => abort("invalid LogitFormatter kind")
  }
}

///|
/// A live probability formatter with raw parameters and a shared label set.
pub struct LogitFormatter {
  priv base : BaseFormatter
}

///|
pub fn LogitFormatter::new(
  use_overline~ : LogValue = LogValue::Numeric(ScalarNumber::Boolean(false)),
  one_half~ : LogValue = LogValue::Text("\\frac{1}{2}"),
  minor~ : LogValue = LogValue::Numeric(ScalarNumber::Boolean(false)),
  minor_threshold~ : LogValue = LogValue::Numeric(
    ScalarNumber::Integer(@bigint.BigInt::from_int(25)),
  ),
  minor_number~ : LogValue = LogValue::Numeric(
    ScalarNumber::Integer(@bigint.BigInt::from_int(6)),
  ),
) -> LogitFormatter {
  {
    base: named_formatter_with_kind(
      FormatterKind::Logit({
        use_overline,
        one_half,
        minor,
        minor_threshold,
        minor_number,
        labelled: LogitLabelled::new(),
      }),
    ),
  }
}

///|
pub fn BaseFormatter::logit_formatter(self : BaseFormatter) -> LogitFormatter? {
  match self.kind {
    Logit(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn LogitFormatter::overline(self : LogitFormatter) -> LogValue {
  logit_formatter_state(self.base).use_overline
}

///|
pub fn LogitFormatter::use_overline(
  self : LogitFormatter,
  value : LogValue,
) -> Unit {
  logit_formatter_state(self.base).use_overline = value
}

///|
pub fn LogitFormatter::one_half(self : LogitFormatter) -> LogValue {
  logit_formatter_state(self.base).one_half
}

///|
pub fn LogitFormatter::set_one_half(
  self : LogitFormatter,
  value : LogValue,
) -> Unit {
  logit_formatter_state(self.base).one_half = value
}

///|
pub fn LogitFormatter::minor(self : LogitFormatter) -> LogValue {
  logit_formatter_state(self.base).minor
}

///|
pub fn LogitFormatter::minor_threshold(self : LogitFormatter) -> LogValue {
  logit_formatter_state(self.base).minor_threshold
}

///|
pub fn LogitFormatter::set_minor_threshold(
  self : LogitFormatter,
  value : LogValue,
) -> Unit {
  logit_formatter_state(self.base).minor_threshold = value
}

///|
pub fn LogitFormatter::minor_number(self : LogitFormatter) -> LogValue {
  logit_formatter_state(self.base).minor_number
}

///|
pub fn LogitFormatter::set_minor_number(
  self : LogitFormatter,
  value : LogValue,
) -> Unit {
  logit_formatter_state(self.base).minor_number = value
}

///|
/// Read a snapshot of the shared set's key handles.
pub fn LogitFormatter::labelled(self : LogitFormatter) -> Array[LogitKey] {
  logit_formatter_state(self.base).labelled.keys()
}

///|
pub fn LogitFormatter::as_base_formatter(
  self : LogitFormatter,
) -> BaseFormatter {
  self.base
}

///|
pub fn LogitFormatter::copy(self : LogitFormatter) -> LogitFormatter {
  { base: self.base.copy(), }
}

///|
pub fn LogitFormatter::locations(self : LogitFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn LogitFormatter::set_locs(
  self : LogitFormatter,
  values : Array[Double],
) -> Unit raise @core.DataError {
  logit_named_prepare(
    self.base,
    logit_formatter_state(self.base),
    LogitInput::from_array(values),
  )
}

///|
pub fn LogitFormatter::set_locs_view(
  self : LogitFormatter,
  values : TickValues,
) -> Unit raise @core.DataError {
  logit_named_prepare(
    self.base,
    logit_formatter_state(self.base),
    LogitInput::from_view(values),
  )
}

///|
/// Borrow explicit scalar identities while preparing an independent snapshot.
pub fn LogitFormatter::set_locs_keys(
  self : LogitFormatter,
  values : Array[LogitKey],
) -> Unit raise @core.DataError {
  logit_named_prepare(
    self.base,
    logit_formatter_state(self.base),
    LogitInput::from_keys(values),
  )
}

///|
pub fn LogitFormatter::axis(self : LogitFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn LogitFormatter::set_axis(
  self : LogitFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn LogitFormatter::create_dummy_axis(
  self : LogitFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn LogitFormatter::get_offset(self : LogitFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn LogitFormatter::call(
  self : LogitFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.call_value(ScalarNumber::Number(value), pos?)
}

///|
pub fn LogitFormatter::call_value(
  self : LogitFormatter,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  self.call_key(LogitKey::new(value), pos?)
}

///|
pub fn LogitFormatter::call_key(
  self : LogitFormatter,
  key : LogitKey,
  pos? : Int32,
) -> String raise @core.DataError {
  logit_named_call(self.base, logit_formatter_state(self.base), key, pos)
}

///|
pub fn LogitFormatter::format_data(
  self : LogitFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.call(value)
}

///|
pub fn LogitFormatter::format_data_value(
  self : LogitFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  self.call_value(value)
}

///|
pub fn LogitFormatter::format_data_key(
  self : LogitFormatter,
  key : LogitKey,
) -> String raise @core.DataError {
  self.call_key(key)
}

///|
pub fn LogitFormatter::format_data_short(
  self : LogitFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.format_data_short_value(ScalarNumber::Number(value))
}

///|
pub fn LogitFormatter::format_data_short_value(
  self : LogitFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  ignore(self)
  logit_named_short(value)
}

///|
pub fn LogitFormatter::format_ticks(
  self : LogitFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn LogitFormatter::format_ticks_view(
  self : LogitFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}

///|
pub fn LogitFormatter::format_ticks_keys(
  self : LogitFormatter,
  values : Array[LogitKey],
) -> Array[String] raise @core.DataError {
  logit_format_ticks_keys(self.base, values)
}
