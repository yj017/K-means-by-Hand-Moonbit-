///|
/// A live formatter with an unvalidated, replaceable format string.
pub struct FormatStrFormatter {
  priv base : BaseFormatter
}

///|
/// Store the format string; syntax and conversion errors are reported on use.
pub fn FormatStrFormatter::new(fmt : String) -> FormatStrFormatter {
  { base: named_formatter_with_kind(FormatterKind::FormatStr({ fmt, })), }
}

///|
pub fn FormatStrFormatter::fmt(self : FormatStrFormatter) -> String {
  match self.base.kind {
    FormatStr(state) => state.fmt
    _ => abort("invalid FormatStrFormatter kind")
  }
}

///|
/// Replace the raw format slot without validating or changing context.
pub fn FormatStrFormatter::set_fmt(
  self : FormatStrFormatter,
  fmt : String,
) -> Unit {
  match self.base.kind {
    FormatStr(state) => state.fmt = fmt
    _ => abort("invalid FormatStrFormatter kind")
  }
}

///|
pub fn FormatStrFormatter::as_base_formatter(
  self : FormatStrFormatter,
) -> BaseFormatter {
  self.base
}

///|
pub fn BaseFormatter::format_str_formatter(
  self : BaseFormatter,
) -> FormatStrFormatter? {
  match self.kind {
    FormatStr(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn FormatStrFormatter::copy(
  self : FormatStrFormatter,
) -> FormatStrFormatter {
  { base: self.base.copy(), }
}

///|
pub fn FormatStrFormatter::locations(
  self : FormatStrFormatter,
) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn FormatStrFormatter::set_locs(
  self : FormatStrFormatter,
  values : Array[Double],
) -> Unit {
  self.base.set_locs(values)
}

///|
pub fn FormatStrFormatter::set_locs_view(
  self : FormatStrFormatter,
  values : TickValues,
) -> Unit {
  self.base.set_locs_view(values)
}

///|
pub fn FormatStrFormatter::axis(
  self : FormatStrFormatter,
) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn FormatStrFormatter::set_axis(
  self : FormatStrFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn FormatStrFormatter::create_dummy_axis(
  self : FormatStrFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn FormatStrFormatter::get_offset(self : FormatStrFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn FormatStrFormatter::call(
  self : FormatStrFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn FormatStrFormatter::format_ticks(
  self : FormatStrFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn FormatStrFormatter::format_ticks_view(
  self : FormatStrFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}

///|
pub fn FormatStrFormatter::format_data(
  self : FormatStrFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn FormatStrFormatter::format_data_short(
  self : FormatStrFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}

///|
/// A live formatter with an unvalidated, replaceable format string.
pub struct StrMethodFormatter {
  priv base : BaseFormatter
}

///|
/// Store the format string; syntax and conversion errors are reported on use.
pub fn StrMethodFormatter::new(fmt : String) -> StrMethodFormatter {
  { base: named_formatter_with_kind(FormatterKind::StrMethod({ fmt, })), }
}

///|
pub fn StrMethodFormatter::fmt(self : StrMethodFormatter) -> String {
  match self.base.kind {
    StrMethod(state) => state.fmt
    _ => abort("invalid StrMethodFormatter kind")
  }
}

///|
/// Replace the raw format slot without validating or changing context.
pub fn StrMethodFormatter::set_fmt(
  self : StrMethodFormatter,
  fmt : String,
) -> Unit {
  match self.base.kind {
    StrMethod(state) => state.fmt = fmt
    _ => abort("invalid StrMethodFormatter kind")
  }
}

///|
pub fn StrMethodFormatter::as_base_formatter(
  self : StrMethodFormatter,
) -> BaseFormatter {
  self.base
}

///|
pub fn BaseFormatter::str_method_formatter(
  self : BaseFormatter,
) -> StrMethodFormatter? {
  match self.kind {
    StrMethod(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn StrMethodFormatter::copy(
  self : StrMethodFormatter,
) -> StrMethodFormatter {
  { base: self.base.copy(), }
}

///|
pub fn StrMethodFormatter::locations(
  self : StrMethodFormatter,
) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn StrMethodFormatter::set_locs(
  self : StrMethodFormatter,
  values : Array[Double],
) -> Unit {
  self.base.set_locs(values)
}

///|
pub fn StrMethodFormatter::set_locs_view(
  self : StrMethodFormatter,
  values : TickValues,
) -> Unit {
  self.base.set_locs_view(values)
}

///|
pub fn StrMethodFormatter::axis(
  self : StrMethodFormatter,
) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn StrMethodFormatter::set_axis(
  self : StrMethodFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn StrMethodFormatter::create_dummy_axis(
  self : StrMethodFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn StrMethodFormatter::get_offset(self : StrMethodFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn StrMethodFormatter::call(
  self : StrMethodFormatter,
  value : Double,
  pos? : Int32,
) -> String raise @core.DataError {
  self.base.call(value, pos?)
}

///|
pub fn StrMethodFormatter::format_ticks(
  self : StrMethodFormatter,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  self.base.format_ticks(values)
}

///|
pub fn StrMethodFormatter::format_ticks_view(
  self : StrMethodFormatter,
  values : TickValues,
) -> Array[String] raise @core.DataError {
  self.base.format_ticks_view(values)
}

///|
pub fn StrMethodFormatter::format_data(
  self : StrMethodFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data(value)
}

///|
pub fn StrMethodFormatter::format_data_short(
  self : StrMethodFormatter,
  value : Double,
) -> String raise @core.DataError {
  self.base.format_data_short(value)
}
