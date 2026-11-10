///|
/// Raw scalar origins determine Python versus NumPy division behavior.
pub(all) enum PercentXMax {
  Number(Double)
  Integer(@bigint.BigInt)
  Boolean(Bool)
  NumpyFloat64(Double)
  NumpyInt64(Int64)
} derive(Debug, Eq)

///|
pub extend PercentXMax with @debug.Debug::{to_repr}

///|
pub extend PercentXMax with Eq::{equal, not_equal}

///|
/// Preserve the raw precision until its integer conversion during formatting.
pub(all) enum PercentDecimals {
  Automatic
  Number(Double)
  Integer(@bigint.BigInt)
  Text(String)
  Boolean(Bool)
} derive(Debug, Eq)

///|
pub extend PercentDecimals with @debug.Debug::{to_repr}

///|
pub extend PercentDecimals with Eq::{equal, not_equal}

///|
priv struct PercentFormatterState {
  mut xmax : PercentXMax
  mut decimals : PercentDecimals
  mut symbol : String?
  mut is_latex : Bool
}

///|
/// A live percentage formatter with raw mutable parameters and axis context.
pub struct PercentFormatter {
  priv base : BaseFormatter
}

///|
/// Apply only the source constructor's xmax + 0.0 coercion.
pub fn PercentFormatter::new(
  xmax~ : PercentXMax = PercentXMax::Number(100.0),
  decimals~ : PercentDecimals = PercentDecimals::Automatic,
  symbol~ : String? = Some("%"),
  is_latex~ : Bool = false,
) -> PercentFormatter raise @core.DataError {
  let xmax = percent_xmax_normalize(xmax)
  {
    base: named_formatter_with_kind(
      FormatterKind::Percent({ xmax, decimals, symbol, is_latex, }),
    ),
  }
}

///|
fn percent_formatter_state(
  formatter : PercentFormatter,
) -> PercentFormatterState {
  match formatter.base.kind {
    Percent(state) => state
    _ => abort("invalid PercentFormatter kind")
  }
}

///|
/// Read the current symbol without changing its raw slot.
fn percent_symbol(state : PercentFormatterState) -> String {
  match state.symbol {
    None => ""
    Some(symbol) => {
      if symbol.is_empty() || state.is_latex || !@config.text_usetex() {
        return symbol
      }
      let mut symbol = symbol
      for reserved in ["\\", "#", "$", "%", "&", "~", "_", "^", "{", "}"] {
        symbol = symbol.replace_all(old=reserved, new="\\" + reserved)
      }
      symbol
    }
  }
}

///|
pub fn PercentFormatter::xmax(self : PercentFormatter) -> PercentXMax {
  percent_formatter_state(self).xmax
}

///|
/// Replace the raw slot; unlike construction this does not add 0.0.
pub fn PercentFormatter::set_xmax(
  self : PercentFormatter,
  xmax : PercentXMax,
) -> Unit {
  percent_formatter_state(self).xmax = xmax
}

///|
pub fn PercentFormatter::decimals(self : PercentFormatter) -> PercentDecimals {
  percent_formatter_state(self).decimals
}

///|
pub fn PercentFormatter::set_decimals(
  self : PercentFormatter,
  decimals : PercentDecimals,
) -> Unit {
  percent_formatter_state(self).decimals = decimals
}

///|
pub fn PercentFormatter::raw_symbol(self : PercentFormatter) -> String? {
  percent_formatter_state(self).symbol
}

///|
pub fn PercentFormatter::symbol(self : PercentFormatter) -> String {
  percent_symbol(percent_formatter_state(self))
}

///|
pub fn PercentFormatter::set_symbol(
  self : PercentFormatter,
  symbol : String?,
) -> Unit {
  percent_formatter_state(self).symbol = symbol
}

///|
pub fn PercentFormatter::is_latex(self : PercentFormatter) -> Bool {
  percent_formatter_state(self).is_latex
}

///|
pub fn PercentFormatter::set_is_latex(
  self : PercentFormatter,
  is_latex : Bool,
) -> Unit {
  percent_formatter_state(self).is_latex = is_latex
}

///|
pub fn PercentFormatter::as_base_formatter(
  self : PercentFormatter,
) -> BaseFormatter {
  self.base
}

///|
pub fn BaseFormatter::percent_formatter(
  self : BaseFormatter,
) -> PercentFormatter? {
  match self.kind {
    Percent(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn PercentFormatter::copy(self : PercentFormatter) -> PercentFormatter {
  { base: self.base.copy(), }
}

///|
pub fn PercentFormatter::locations(
  self : PercentFormatter,
) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn PercentFormatter::set_locs(
  self : PercentFormatter,
  values : Array[Double],
) -> Unit {
  self.base.set_locs(values)
}

///|
pub fn PercentFormatter::set_locs_view(
  self : PercentFormatter,
  values : TickValues,
) -> Unit {
  self.base.set_locs_view(values)
}

///|
pub fn PercentFormatter::axis(self : PercentFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn PercentFormatter::set_axis(
  self : PercentFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn PercentFormatter::create_dummy_axis(
  self : PercentFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn PercentFormatter::get_offset(self : PercentFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn PercentFormatter::convert_to_pct(
  self : PercentFormatter,
  value : Double,
) -> Double raise @core.DataError {
  percent_convert_to_pct(self.xmax(), NamedFormatValue::PythonFloat(value))
}

///|
pub fn PercentFormatter::format_pct(
  self : PercentFormatter,
  value : Double,
  display_range : Double,
) -> String raise @core.DataError {
  percent_format_pct(
    percent_formatter_state(self),
    NamedFormatValue::PythonFloat(value),
    NamedFormatValue::PythonFloat(display_range),
  )
}

///|
pub fn PercentFormatter::call(
  self : PercentFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn PercentFormatter::format_ticks(
  self : PercentFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn PercentFormatter::format_ticks_view(
  self : PercentFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}

///|
pub fn PercentFormatter::format_data(
  self : PercentFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn PercentFormatter::format_data_short(
  self : PercentFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}
