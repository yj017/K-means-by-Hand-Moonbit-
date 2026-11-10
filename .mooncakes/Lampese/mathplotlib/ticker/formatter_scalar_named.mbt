///|
/// Raw Python and NumPy scalar origins remain observable during formatting.
pub(all) enum ScalarNumber {
  Number(Double)
  Integer(@bigint.BigInt)
  Boolean(Bool)
  NumpyFloat64(Double)
  NumpyInt64(Int64)
  NumpyBool(Bool)
} derive(Debug, Eq)

///|
pub extend ScalarNumber with @debug.Debug::{to_repr}

///|
pub extend ScalarNumber with Eq::{equal, not_equal}

///|
/// Power thresholds borrow their original container, shape and scalar domain.
pub(all) enum ScalarPowerLimits {
  Sequence(Array[Double])
  Integers(Array[@bigint.BigInt])
  Values(Array[ScalarNumber])
  NdArray(TickValues)
}

///|
pub impl @debug.Debug for ScalarPowerLimits with fn to_repr(self) {
  match self {
    Sequence(values) => @debug.Repr::Repr(("Sequence", values))
    Integers(values) => @debug.Repr::Repr(("Integers", values))
    Values(values) => @debug.Repr::Repr(("Values", values))
    NdArray(values) => @debug.Repr::Repr(("NdArray length", values.length()))
  }
}

///|
pub extend ScalarPowerLimits with @debug.Debug::{to_repr}

///|
fn scalar_power_limits_length(limits : ScalarPowerLimits) -> Int32 {
  match limits {
    Sequence(values) => values.length()
    Integers(values) => values.length()
    Values(values) => values.length()
    NdArray(values) => values.length()
  }
}

///|
fn scalar_power_limit_at(
  limits : ScalarPowerLimits,
  index : Int32,
) -> ScalarNumber raise @core.DataError {
  let length = scalar_power_limits_length(limits)
  let normalized = if index < 0 {
    Int64::from_int(length) + Int64::from_int(index)
  } else {
    Int64::from_int(index)
  }
  if normalized < 0L || normalized >= Int64::from_int(length) {
    let message = match limits {
      NdArray(_) =>
        "index " +
        index.to_string() +
        " is out of bounds for axis 0 with size " +
        length.to_string()
      _ => "list index out of range"
    }
    raise @core.DataError::InvalidTicks(message="IndexError: " + message)
  }
  let index = normalized.to_int()
  match limits {
    Sequence(values) => ScalarNumber::Number(values[index])
    Integers(values) => ScalarNumber::Integer(values[index])
    Values(values) => values[index]
    NdArray(values) =>
      if values.is_int64() {
        ScalarNumber::NumpyInt64(values.get_int64(index))
      } else {
        ScalarNumber::NumpyFloat64(values.get(index))
      }
  }
}

///|
priv struct ScalarFormatterState {
  mut offset : ScalarNumber?
  mut use_offset : Bool
  offset_threshold : @bigint.BigInt
  mut usetex : Bool
  mut use_math_text : Bool
  mut use_locale : Bool
  mut scientific : Bool
  mut order : ScalarNumber
  mut format_pattern : String
  mut power_limits : ScalarPowerLimits
}

///|
/// A live scalar formatter, retaining raw configuration and prepared state.
pub struct ScalarFormatter {
  priv base : BaseFormatter
}

///|
pub fn ScalarFormatter::new(
  use_offset~ : ScalarNumber? = None,
  use_math_text~ : Bool? = None,
  use_locale~ : Bool? = None,
  usetex~ : Bool? = None,
) -> ScalarFormatter {
  let use_offset = match use_offset {
    Some(value) => value
    None => ScalarNumber::Boolean(@config.formatter_use_offset())
  }
  let offset_threshold = @config.formatter_offset_threshold()
  let (offset, use_offset) = match use_offset {
    Boolean(value) =>
      (Some(ScalarNumber::Integer(@bigint.BigInt::from_int(0))), value)
    value => (Some(value), false)
  }
  let usetex = match usetex {
    Some(value) => value
    None => @config.text_usetex()
  }
  let use_math_text = match use_math_text {
    Some(value) => value
    None => @config.formatter_use_math_text()
  }
  let order = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  let format_pattern = ""
  let scientific = true
  let power_limits = ScalarPowerLimits::Integers(@config.formatter_limits())
  let use_locale = match use_locale {
    Some(value) => value
    None => @config.formatter_use_locale()
  }
  {
    base: named_formatter_with_kind(
      FormatterKind::Scalar({
        offset,
        use_offset,
        offset_threshold,
        usetex,
        use_math_text,
        use_locale,
        scientific,
        order,
        format_pattern,
        power_limits,
      }),
    ),
  }
}

///|
fn scalar_formatter_state(formatter : ScalarFormatter) -> ScalarFormatterState {
  match formatter.base.kind {
    Scalar(state) => state
    Eng(state) => state.scalar
    _ => abort("invalid ScalarFormatter kind")
  }
}

///|
fn scalar_formatter_copy_state(
  state : ScalarFormatterState,
) -> ScalarFormatterState {
  {
    offset: state.offset,
    use_offset: state.use_offset,
    offset_threshold: state.offset_threshold,
    usetex: state.usetex,
    use_math_text: state.use_math_text,
    use_locale: state.use_locale,
    scientific: state.scientific,
    order: state.order,
    format_pattern: state.format_pattern,
    power_limits: state.power_limits,
  }
}

///|
pub fn ScalarFormatter::offset(self : ScalarFormatter) -> ScalarNumber? {
  scalar_formatter_state(self).offset
}

///|
pub fn ScalarFormatter::set_offset(
  self : ScalarFormatter,
  value : ScalarNumber?,
) -> Unit {
  scalar_formatter_state(self).offset = value
}

///|
pub fn ScalarFormatter::get_use_offset(self : ScalarFormatter) -> Bool {
  scalar_formatter_state(self).use_offset
}

///|
pub fn ScalarFormatter::set_use_offset(
  self : ScalarFormatter,
  value : ScalarNumber?,
) -> Unit {
  let state = scalar_formatter_state(self)
  match value {
    Some(ScalarNumber::Boolean(value)) => {
      state.offset = Some(ScalarNumber::Integer(@bigint.BigInt::from_int(0)))
      state.use_offset = value
    }
    value => {
      state.use_offset = false
      state.offset = value
    }
  }
}

///|
pub fn ScalarFormatter::get_usetex(self : ScalarFormatter) -> Bool {
  scalar_formatter_state(self).usetex
}

///|
pub fn ScalarFormatter::set_usetex(
  self : ScalarFormatter,
  value : Bool?,
) -> Unit {
  scalar_formatter_state(self).usetex = match value {
    Some(value) => value
    None => @config.text_usetex()
  }
}

///|
pub fn ScalarFormatter::get_use_math_text(self : ScalarFormatter) -> Bool {
  scalar_formatter_state(self).use_math_text
}

///|
pub fn ScalarFormatter::set_use_math_text(
  self : ScalarFormatter,
  value : Bool?,
) -> Unit {
  scalar_formatter_state(self).use_math_text = match value {
    Some(value) => value
    None => @config.formatter_use_math_text()
  }
}

///|
pub fn ScalarFormatter::get_use_locale(self : ScalarFormatter) -> Bool {
  scalar_formatter_state(self).use_locale
}

///|
pub fn ScalarFormatter::set_use_locale(
  self : ScalarFormatter,
  value : Bool?,
) -> Unit {
  scalar_formatter_state(self).use_locale = match value {
    Some(value) => value
    None => @config.formatter_use_locale()
  }
}

///|
pub fn ScalarFormatter::scientific(self : ScalarFormatter) -> Bool {
  scalar_formatter_state(self).scientific
}

///|
pub fn ScalarFormatter::set_scientific(
  self : ScalarFormatter,
  value : Bool,
) -> Unit {
  scalar_formatter_state(self).scientific = value
}

///|
pub fn ScalarFormatter::offset_threshold(
  self : ScalarFormatter,
) -> @bigint.BigInt {
  scalar_formatter_state(self).offset_threshold
}

///|
pub fn ScalarFormatter::power_limits(
  self : ScalarFormatter,
) -> ScalarPowerLimits {
  scalar_formatter_state(self).power_limits
}

///|
pub fn ScalarFormatter::set_power_limits(
  self : ScalarFormatter,
  value : ScalarPowerLimits,
) -> Unit raise @core.DataError {
  if scalar_power_limits_length(value) != 2 {
    raise @core.DataError::InvalidTicks(
      message="ValueError: 'lims' must be a sequence of length 2",
    )
  }
  scalar_formatter_state(self).power_limits = value
}

///|
pub fn ScalarFormatter::order_of_magnitude(
  self : ScalarFormatter,
) -> ScalarNumber {
  scalar_formatter_state(self).order
}

///|
pub fn ScalarFormatter::set_order_of_magnitude(
  self : ScalarFormatter,
  value : ScalarNumber,
) -> Unit {
  scalar_formatter_state(self).order = value
}

///|
pub fn ScalarFormatter::format_pattern(self : ScalarFormatter) -> String {
  scalar_formatter_state(self).format_pattern
}

///|
pub fn ScalarFormatter::set_format_pattern(
  self : ScalarFormatter,
  value : String,
) -> Unit {
  scalar_formatter_state(self).format_pattern = value
}

///|
pub fn ScalarFormatter::as_base_formatter(
  self : ScalarFormatter,
) -> BaseFormatter {
  self.base
}

///|
pub fn BaseFormatter::scalar_formatter(
  self : BaseFormatter,
) -> ScalarFormatter? {
  match self.kind {
    Scalar(_) | Eng(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn ScalarFormatter::copy(self : ScalarFormatter) -> ScalarFormatter {
  { base: self.base.copy(), }
}

///|
pub fn ScalarFormatter::locations(self : ScalarFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn ScalarFormatter::set_locs(
  self : ScalarFormatter,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.base.set_locs_checked(values)
}

///|
pub fn ScalarFormatter::set_locs_view(
  self : ScalarFormatter,
  values : TickValues,
) -> Unit raise @core.DataError {
  self.base.set_locs_view_checked(values)
}

///|
pub fn ScalarFormatter::axis(self : ScalarFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn ScalarFormatter::set_axis(
  self : ScalarFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn ScalarFormatter::create_dummy_axis(
  self : ScalarFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn ScalarFormatter::get_offset(
  self : ScalarFormatter,
) -> String raise @core.DataError {
  self.base.get_offset_checked()
}

///|
pub fn ScalarFormatter::call(
  self : ScalarFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn ScalarFormatter::call_value(
  self : ScalarFormatter,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  match self.base.kind {
    Eng(state) => eng_named_call(self.base, state, value, pos)
    _ => scalar_named_call(self.base, scalar_formatter_state(self), value, pos)
  }
}

///|
pub fn ScalarFormatter::format_ticks(
  self : ScalarFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn ScalarFormatter::format_ticks_view(
  self : ScalarFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}

///|
pub fn ScalarFormatter::format_data(
  self : ScalarFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn ScalarFormatter::format_data_value(
  self : ScalarFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  match self.base.kind {
    Eng(state) => eng_named_format_data(state, value)
    _ => scalar_named_format_data(scalar_formatter_state(self), value)
  }
}

///|
pub fn ScalarFormatter::format_data_short(
  self : ScalarFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
pub fn ScalarFormatter::format_data_short_value(
  self : ScalarFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  scalar_named_short(self.base, scalar_formatter_state(self), value)
}

///|
pub fn ScalarFormatter::format_data_short_masked(
  self : ScalarFormatter,
) -> String {
  ignore(self)
  ""
}
