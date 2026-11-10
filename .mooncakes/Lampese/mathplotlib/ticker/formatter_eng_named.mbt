///|
priv struct EngFormatterState {
  scalar : ScalarFormatterState
  mut unit : String
  mut places : ScalarNumber?
  mut sep : String
  mut prefixes : EngPrefixes?
}

///|
/// A live engineering formatter, sharing its inherited ScalarFormatter state.
pub struct EngFormatter {
  priv base : BaseFormatter
}

///|
priv struct EngPrefixesClassSlot {
  mut value : EngPrefixes
}

///|
let eng_formatter_class_prefixes : EngPrefixesClassSlot = {
  value: EngPrefixes::si(),
}

///|
fn eng_state_prefixes(state : EngFormatterState) -> EngPrefixes {
  match state.prefixes {
    Some(prefixes) => prefixes
    None => eng_formatter_class_prefixes.value
  }
}

///|
pub fn EngFormatter::new(
  unit~ : String = "",
  places~ : ScalarNumber? = None,
  sep~ : String = " ",
  usetex~ : Bool? = None,
  use_math_text~ : Bool? = None,
  use_offset~ : ScalarNumber? = Some(ScalarNumber::Boolean(false)),
) -> EngFormatter {
  let scalar = scalar_formatter_state(
    ScalarFormatter::new(
      use_offset~,
      use_math_text~,
      use_locale=Some(false),
      usetex~,
    ),
  )
  {
    base: named_formatter_with_kind(
      FormatterKind::Eng({ scalar, unit, places, sep, prefixes: None, }),
    ),
  }
}

///|
fn eng_formatter_state(formatter : EngFormatter) -> EngFormatterState {
  match formatter.base.kind {
    Eng(state) => state
    _ => abort("invalid EngFormatter kind")
  }
}

///|
pub fn EngFormatter::unit(self : EngFormatter) -> String {
  eng_formatter_state(self).unit
}

///|
pub fn EngFormatter::set_unit(self : EngFormatter, unit : String) -> Unit {
  eng_formatter_state(self).unit = unit
}

///|
pub fn EngFormatter::places(self : EngFormatter) -> ScalarNumber? {
  eng_formatter_state(self).places
}

///|
pub fn EngFormatter::set_places(
  self : EngFormatter,
  places : ScalarNumber?,
) -> Unit {
  eng_formatter_state(self).places = places
}

///|
pub fn EngFormatter::sep(self : EngFormatter) -> String {
  eng_formatter_state(self).sep
}

///|
pub fn EngFormatter::set_sep(self : EngFormatter, sep : String) -> Unit {
  eng_formatter_state(self).sep = sep
}

///|
pub fn EngFormatter::prefixes(self : EngFormatter) -> EngPrefixes {
  eng_state_prefixes(eng_formatter_state(self))
}

///|
pub fn EngFormatter::set_prefixes(
  self : EngFormatter,
  prefixes : EngPrefixes,
) -> Unit {
  eng_formatter_state(self).prefixes = Some(prefixes)
}

///|
pub fn EngFormatter::clear_prefixes(self : EngFormatter) -> Unit {
  eng_formatter_state(self).prefixes = None
}

///|
pub fn EngFormatter::class_prefixes() -> EngPrefixes {
  eng_formatter_class_prefixes.value
}

///|
pub fn EngFormatter::set_class_prefixes(prefixes : EngPrefixes) -> Unit {
  eng_formatter_class_prefixes.value = prefixes
}

///|
pub fn EngFormatter::as_base_formatter(self : EngFormatter) -> BaseFormatter {
  self.base
}

///|
pub fn EngFormatter::as_scalar_formatter(
  self : EngFormatter,
) -> ScalarFormatter {
  { base: self.base, }
}

///|
pub fn BaseFormatter::eng_formatter(self : BaseFormatter) -> EngFormatter? {
  match self.kind {
    Eng(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn EngFormatter::copy(self : EngFormatter) -> EngFormatter {
  { base: self.base.copy(), }
}

///|
pub fn EngFormatter::locations(self : EngFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn EngFormatter::set_locs(
  self : EngFormatter,
  values : Array[Double],
) -> Unit raise @core.DataError {
  self.base.set_locs_checked(values)
}

///|
pub fn EngFormatter::set_locs_view(
  self : EngFormatter,
  values : TickValues,
) -> Unit raise @core.DataError {
  self.base.set_locs_view_checked(values)
}

///|
pub fn EngFormatter::axis(self : EngFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn EngFormatter::set_axis(
  self : EngFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn EngFormatter::create_dummy_axis(
  self : EngFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn EngFormatter::get_offset(
  self : EngFormatter,
) -> String raise @core.DataError {
  self.base.get_offset_checked()
}

///|
pub fn EngFormatter::call(
  self : EngFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn EngFormatter::call_value(
  self : EngFormatter,
  value : ScalarNumber,
  pos? : Int32,
) -> String raise @core.DataError {
  eng_named_call(self.base, eng_formatter_state(self), value, pos)
}

///|
pub fn EngFormatter::format_ticks(
  self : EngFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn EngFormatter::format_ticks_view(
  self : EngFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}

///|
pub fn EngFormatter::format_data(
  self : EngFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn EngFormatter::format_data_value(
  self : EngFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  eng_named_format_data(eng_formatter_state(self), value)
}

///|
pub fn EngFormatter::format_eng(
  self : EngFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.format_data(value)
}

///|
pub fn EngFormatter::format_eng_value(
  self : EngFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  self.format_data_value(value)
}

///|
pub fn EngFormatter::format_data_short(
  self : EngFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
pub fn EngFormatter::format_data_short_value(
  self : EngFormatter,
  value : ScalarNumber,
) -> String raise @core.DataError {
  scalar_named_short(self.base, eng_formatter_state(self).scalar, value)
}

///|
pub fn EngFormatter::format_data_short_masked(self : EngFormatter) -> String {
  ignore(self)
  ""
}
