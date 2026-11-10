///|
/// Retained locations support live lists, fixed-shape views and numeric snapshots.
pub(all) enum FormatterLocations {
  Sequence(Array[Double])
  Integers(Array[@bigint.BigInt])
  NdArray(TickValues)
  Typed(NumericArray)
}

///|
pub fn FormatterLocations::length(self : FormatterLocations) -> Int32 {
  match self {
    Sequence(values) => values.length()
    Integers(values) => values.length()
    NdArray(values) => values.length()
    Typed(values) => values.length()
  }
}

///|
/// Return the ndarray dtype, or None for a retained Python-style sequence.
pub fn FormatterLocations::dtype(self : FormatterLocations) -> String? {
  match self {
    Sequence(_) | Integers(_) => None
    NdArray(values) => Some(if values.is_int64() { "int64" } else { "float64" })
    Typed(values) => Some(values.dtype())
  }
}

///|
pub fn FormatterLocations::get(
  self : FormatterLocations,
  index : Int32,
) -> Double raise @core.DataError {
  match self {
    Sequence(values) => {
      let index = if index < 0 {
        Int64::from_int(values.length()) + Int64::from_int(index)
      } else {
        Int64::from_int(index)
      }
      if index < 0L || index >= Int64::from_int(values.length()) {
        raise @core.DataError::InvalidTicks(
          message="formatter location index is out of bounds",
        )
      }
      values[index.to_int()]
    }
    Integers(values) => {
      let normalized = if index < 0 {
        Int64::from_int(values.length()) + Int64::from_int(index)
      } else {
        Int64::from_int(index)
      }
      if normalized < 0L || normalized >= Int64::from_int(values.length()) {
        raise @core.DataError::InvalidTicks(
          message="formatter location index is out of bounds",
        )
      }
      percent_python_integer_double(values[normalized.to_int()])
    }
    NdArray(values) => values.get(index)
    Typed(values) => values.get(index)
  }
}

///|
/// Read a stored numeric value without rounding integer storage through Double.
/// Unsigned storage projects its exact value to Integer in the six-origin carrier.
pub fn FormatterLocations::get_value(
  self : FormatterLocations,
  index : Int32,
) -> ScalarNumber raise @core.DataError {
  match self {
    Sequence(_) => ScalarNumber::Number(self.get(index))
    Integers(values) => {
      let normalized = if index < 0 {
        Int64::from_int(values.length()) + Int64::from_int(index)
      } else {
        Int64::from_int(index)
      }
      if normalized < 0L || normalized >= Int64::from_int(values.length()) {
        raise @core.DataError::InvalidTicks(
          message="formatter location index is out of bounds",
        )
      }
      ScalarNumber::Integer(values[normalized.to_int()])
    }
    NdArray(values) =>
      if values.is_int64() {
        ScalarNumber::NumpyInt64(values.get_int64(index))
      } else {
        ScalarNumber::NumpyFloat64(values.get(index))
      }
    Typed(values) => values.get_value(index)
  }
}

///|
/// Scalar domains returned by a live axis view, separate from tick locations.
pub(all) enum FormatterViewInterval {
  Sequence(Array[Double])
  Integers(Array[@bigint.BigInt])
  NdArray(TickValues)
}

///|
pub fn FormatterViewInterval::length(self : FormatterViewInterval) -> Int32 {
  match self {
    Sequence(values) => values.length()
    Integers(values) => values.length()
    NdArray(values) => values.length()
  }
}

///|
/// Stable typed axis identity; dummy metadata does not expose a dynamic Axis.
pub struct FormatterAxisBinding {
  priv minpos : Double?
  priv mut view_provider : (() -> FormatterViewInterval raise @core.DataError)?
  priv mut stored_view : FormatterViewInterval?
  priv mut short_delta_provider : ((Double) -> Double raise @core.DataError)?
  priv mut transform_linthresh_provider : (() -> ScalarNumber? raise @core.DataError)?
}

///|
pub impl @debug.Debug for FormatterAxisBinding with fn to_repr(self) {
  @debug.Repr::Repr(("FormatterAxisBinding", self.minpos))
}

///|
pub extend FormatterAxisBinding with @debug.Debug::{to_repr}

///|
pub impl Eq for FormatterAxisBinding with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub extend FormatterAxisBinding with Eq::{equal, not_equal}

///|
pub fn FormatterAxisBinding::new() -> FormatterAxisBinding {
  {
    minpos: None,
    view_provider: None,
    stored_view: None,
    short_delta_provider: None,
    transform_linthresh_provider: None,
  }
}

///|
/// Bind the data distance to the two neighboring display pixels.
pub fn FormatterAxisBinding::bind_short_format_delta(
  self : FormatterAxisBinding,
  provider : (Double) -> Double raise @core.DataError,
) -> Unit {
  self.short_delta_provider = Some(provider)
}

///|
pub fn FormatterAxisBinding::clear_short_format_delta(
  self : FormatterAxisBinding,
) -> Unit {
  self.short_delta_provider = None
}

///|
/// None selects the formatter's ordinary unnamed-axis fallback.
pub fn FormatterAxisBinding::short_format_delta(
  self : FormatterAxisBinding,
  value : Double,
) -> Double? raise @core.DataError {
  match self.short_delta_provider {
    Some(provider) => Some(provider(value))
    None => None
  }
}

///|
/// Read the current interval once on each formatter call.
pub fn FormatterAxisBinding::view_interval(
  self : FormatterAxisBinding,
) -> FormatterViewInterval raise @core.DataError {
  match self.view_provider {
    Some(provider) => provider()
    None =>
      match self.stored_view {
        Some(view) => view
        None =>
          raise @core.DataError::InvalidTicks(
            message="AttributeError: axis binding has no get_view_interval provider",
          )
      }
  }
}

///|
/// Bind a live view source to this stable axis identity.
pub fn FormatterAxisBinding::bind_view_interval(
  self : FormatterAxisBinding,
  provider : () -> FormatterViewInterval raise @core.DataError,
) -> Unit {
  self.view_provider = Some(provider)
}

///|
/// Retain the supplied interval object, replacing a callback if present.
pub fn FormatterAxisBinding::set_view_interval(
  self : FormatterAxisBinding,
  view : FormatterViewInterval,
) -> Unit {
  self.view_provider = None
  self.stored_view = Some(view)
}

///|
pub fn FormatterAxisBinding::is_dummy(self : FormatterAxisBinding) -> Bool {
  self.minpos is Some(_)
}

///|
pub fn FormatterAxisBinding::dummy_minpos(
  self : FormatterAxisBinding,
) -> Double? {
  self.minpos
}

///|
priv struct FixedFormatterState {
  mut seq : Array[String]
  mut offset : String
}

///|
priv struct FuncFormatterState {
  mut callback : (Double, Int32?) -> String raise @core.DataError
  mut offset : String
}

///|
priv struct StringFormatterState {
  mut fmt : String
}

///|
priv enum FormatterKind {
  Abstract
  Null
  Fixed(FixedFormatterState)
  Func(FuncFormatterState)
  FormatStr(StringFormatterState)
  StrMethod(StringFormatterState)
  Percent(PercentFormatterState)
  Scalar(ScalarFormatterState)
  Eng(EngFormatterState)
  Log(LogFormatterState)
  Logit(LogitFormatterState)
}

///|
/// A live formatter object. Copies share buffers and retain independent slots.
pub struct BaseFormatter {
  priv kind : FormatterKind
  priv mut locations : FormatterLocations
  priv mut axis : FormatterAxisBinding?
}

///|
let formatter_default_locations : Array[Double] = []

///|
fn named_formatter_with_kind(kind : FormatterKind) -> BaseFormatter {
  {
    kind,
    locations: FormatterLocations::Sequence(formatter_default_locations),
    axis: None,
  }
}

///|
/// Construct the base object; its formatting primitive remains unimplemented.
pub fn BaseFormatter::new() -> BaseFormatter {
  named_formatter_with_kind(FormatterKind::Abstract)
}

///|
pub fn BaseFormatter::locations(self : BaseFormatter) -> FormatterLocations {
  self.locations
}

///|
/// Borrow a numeric list with its live mutable length.
pub fn BaseFormatter::set_locs(
  self : BaseFormatter,
  locations : Array[Double],
) -> Unit {
  try! self.set_locs_checked(locations)
}

///|
/// Retain the input before performing a derived formatter's preparation.
pub fn BaseFormatter::set_locs_checked(
  self : BaseFormatter,
  locations : Array[Double],
) -> Unit raise @core.DataError {
  if self.kind is Log(state) {
    log_named_prepare(self, state)
    return
  }
  if self.kind is Logit(state) {
    logit_named_prepare(self, state, LogitInput::from_array(locations))
    return
  }
  self.locations = FormatterLocations::Sequence(locations)
  match self.kind {
    Scalar(state) => scalar_named_prepare(self, state)
    Eng(state) => eng_named_prepare(self, state)
    _ => ()
  }
}

///|
/// Retain a numeric view and its original shape, dtype, buffer, and stride.
pub fn BaseFormatter::set_locs_view(
  self : BaseFormatter,
  locations : TickValues,
) -> Unit {
  try! self.set_locs_view_checked(locations)
}

///|
pub fn BaseFormatter::set_locs_view_checked(
  self : BaseFormatter,
  locations : TickValues,
) -> Unit raise @core.DataError {
  if self.kind is Log(state) {
    log_named_prepare(self, state)
    return
  }
  if self.kind is Logit(state) {
    logit_named_prepare(self, state, LogitInput::from_view(locations))
    return
  }
  self.locations = FormatterLocations::NdArray(locations)
  match self.kind {
    Scalar(state) => scalar_named_prepare(self, state)
    Eng(state) => eng_named_prepare(self, state)
    _ => ()
  }
}

///|
pub fn BaseFormatter::axis(self : BaseFormatter) -> FormatterAxisBinding? {
  self.axis
}

///|
pub fn BaseFormatter::set_axis(
  self : BaseFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.axis = axis
}

///|
/// Allocate a dummy identity only while unbound, retaining arbitrary minpos.
pub fn BaseFormatter::create_dummy_axis(
  self : BaseFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  if self.axis is None {
    self.axis = Some({
      minpos: Some(minpos),
      view_provider: None,
      short_delta_provider: None,
      transform_linthresh_provider: None,
      stored_view: Some(
        FormatterViewInterval::Integers([
          @bigint.BigInt::from_int(0),
          @bigint.BigInt::from_int(1),
        ]),
      ),
    })
  }
}

///|
pub fn BaseFormatter::get_offset(self : BaseFormatter) -> String {
  try! self.get_offset_checked()
}

///|
/// Preserve deferred errors from derived offset formatting.
pub fn BaseFormatter::get_offset_checked(
  self : BaseFormatter,
) -> String raise @core.DataError {
  match self.kind {
    Abstract
    | Null
    | FormatStr(_)
    | StrMethod(_)
    | Percent(_)
    | Log(_)
    | Logit(_) => ""
    Fixed(state) => state.offset
    Func(state) => state.offset
    Scalar(state) => scalar_named_offset(self, state)
    Eng(state) => eng_named_offset(self, state)
  }
}

///|
pub fn BaseFormatter::copy(self : BaseFormatter) -> BaseFormatter {
  let kind = match self.kind {
    Abstract => FormatterKind::Abstract
    Null => FormatterKind::Null
    Fixed(state) =>
      FormatterKind::Fixed({ seq: state.seq, offset: state.offset, })
    Func(state) =>
      FormatterKind::Func({ callback: state.callback, offset: state.offset, })
    FormatStr(state) => FormatterKind::FormatStr({ fmt: state.fmt, })
    StrMethod(state) => FormatterKind::StrMethod({ fmt: state.fmt, })
    Percent(state) =>
      FormatterKind::Percent({
        xmax: state.xmax,
        decimals: state.decimals,
        symbol: state.symbol,
        is_latex: state.is_latex,
      })
    Scalar(state) => FormatterKind::Scalar(scalar_formatter_copy_state(state))
    Eng(state) =>
      FormatterKind::Eng({
        scalar: scalar_formatter_copy_state(state.scalar),
        unit: state.unit,
        places: state.places,
        sep: state.sep,
        prefixes: state.prefixes,
      })
    Log(state) =>
      FormatterKind::Log({
        style: state.style,
        base: state.base,
        label_only_base: state.label_only_base,
        minor_thresholds: state.minor_thresholds,
        linthresh: state.linthresh,
        sublabels: state.sublabels,
      })
    Logit(state) =>
      FormatterKind::Logit({
        use_overline: state.use_overline,
        one_half: state.one_half,
        minor: state.minor,
        minor_threshold: state.minor_threshold,
        minor_number: state.minor_number,
        labelled: state.labelled,
      })
  }
  { kind, locations: self.locations, axis: self.axis, }
}

///|
/// Retain a Python integer list without converting its scalar origins to NumPy.
pub fn BaseFormatter::set_locs_integers_checked(
  self : BaseFormatter,
  locations : Array[@bigint.BigInt],
) -> Unit raise @core.DataError {
  if self.kind is Log(state) {
    log_named_prepare(self, state)
    return
  }
  if self.kind is Logit(state) {
    logit_named_prepare(
      self,
      state,
      LogitInput::from_keys(
        locations.map(value => LogitKey::new(ScalarNumber::Integer(value))),
      ),
    )
    return
  }
  self.locations = FormatterLocations::Integers(locations)
  match self.kind {
    Scalar(state) => scalar_named_prepare(self, state)
    Eng(state) => eng_named_prepare(self, state)
    _ => ()
  }
}
