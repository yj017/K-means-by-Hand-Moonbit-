///|
/// A formatter which suppresses every label while retaining object context.
pub struct NullFormatter {
  priv base : BaseFormatter
}

///|
pub struct FixedFormatter {
  priv base : BaseFormatter
}

///|
pub struct FuncFormatter {
  priv base : BaseFormatter
}

///|
pub fn NullFormatter::new() -> NullFormatter {
  { base: named_formatter_with_kind(FormatterKind::Null), }
}

///|
/// Borrow the label array; its later element and length mutations remain live.
pub fn FixedFormatter::new(seq : Array[String]) -> FixedFormatter {
  {
    base: named_formatter_with_kind(FormatterKind::Fixed({ seq, offset: "", })),
  }
}

///|
pub fn FuncFormatter::new(
  callback : (Double, Int32?) -> String raise @core.DataError,
) -> FuncFormatter {
  {
    base: named_formatter_with_kind(
      FormatterKind::Func({ callback, offset: "", }),
    ),
  }
}

///|
pub fn NullFormatter::as_base_formatter(self : NullFormatter) -> BaseFormatter {
  self.base
}

///|
pub fn FixedFormatter::as_base_formatter(
  self : FixedFormatter,
) -> BaseFormatter {
  self.base
}

///|
pub fn FuncFormatter::as_base_formatter(self : FuncFormatter) -> BaseFormatter {
  self.base
}

///|
pub fn BaseFormatter::null_formatter(self : BaseFormatter) -> NullFormatter? {
  match self.kind {
    Null => Some({ base: self, })
    _ => None
  }
}

///|
pub fn BaseFormatter::fixed_formatter(self : BaseFormatter) -> FixedFormatter? {
  match self.kind {
    Fixed(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn BaseFormatter::func_formatter(self : BaseFormatter) -> FuncFormatter? {
  match self.kind {
    Func(_) => Some({ base: self, })
    _ => None
  }
}

///|
pub fn NullFormatter::copy(self : NullFormatter) -> NullFormatter {
  { base: self.base.copy(), }
}

///|
pub fn FixedFormatter::copy(self : FixedFormatter) -> FixedFormatter {
  { base: self.base.copy(), }
}

///|
pub fn FuncFormatter::copy(self : FuncFormatter) -> FuncFormatter {
  { base: self.base.copy(), }
}

///|
pub fn FixedFormatter::seq(self : FixedFormatter) -> Array[String] {
  match self.base.kind {
    Fixed(state) => state.seq
    _ => abort("invalid FixedFormatter kind")
  }
}

///|
pub fn FixedFormatter::set_seq(
  self : FixedFormatter,
  seq : Array[String],
) -> Unit {
  match self.base.kind {
    Fixed(state) => state.seq = seq
    _ => abort("invalid FixedFormatter kind")
  }
}

///|
pub fn FuncFormatter::func(
  self : FuncFormatter,
) -> (Double, Int32?) -> String raise @core.DataError {
  match self.base.kind {
    Func(state) => state.callback
    _ => abort("invalid FuncFormatter kind")
  }
}

///|
pub fn FuncFormatter::set_func(
  self : FuncFormatter,
  callback : (Double, Int32?) -> String raise @core.DataError,
) -> Unit {
  match self.base.kind {
    Func(state) => state.callback = callback
    _ => abort("invalid FuncFormatter kind")
  }
}

///|
pub fn FixedFormatter::set_offset_string(
  self : FixedFormatter,
  offset : String,
) -> Unit {
  match self.base.kind {
    Fixed(state) => state.offset = offset
    _ => abort("invalid FixedFormatter kind")
  }
}

///|
pub fn FuncFormatter::set_offset_string(
  self : FuncFormatter,
  offset : String,
) -> Unit {
  match self.base.kind {
    Func(state) => state.offset = offset
    _ => abort("invalid FuncFormatter kind")
  }
}

///|
pub fn NullFormatter::locations(self : NullFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn NullFormatter::set_locs(
  self : NullFormatter,
  locations : Array[Double],
) -> Unit {
  self.base.set_locs(locations)
}

///|
pub fn NullFormatter::set_locs_view(
  self : NullFormatter,
  locations : TickValues,
) -> Unit {
  self.base.set_locs_view(locations)
}

///|
pub fn NullFormatter::axis(self : NullFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn NullFormatter::set_axis(
  self : NullFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn NullFormatter::create_dummy_axis(
  self : NullFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn NullFormatter::get_offset(self : NullFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn FixedFormatter::locations(self : FixedFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn FixedFormatter::set_locs(
  self : FixedFormatter,
  locations : Array[Double],
) -> Unit {
  self.base.set_locs(locations)
}

///|
pub fn FixedFormatter::set_locs_view(
  self : FixedFormatter,
  locations : TickValues,
) -> Unit {
  self.base.set_locs_view(locations)
}

///|
pub fn FixedFormatter::axis(self : FixedFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn FixedFormatter::set_axis(
  self : FixedFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn FixedFormatter::create_dummy_axis(
  self : FixedFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn FixedFormatter::get_offset(self : FixedFormatter) -> String {
  self.base.get_offset()
}

///|
pub fn FuncFormatter::locations(self : FuncFormatter) -> FormatterLocations {
  self.base.locations()
}

///|
pub fn FuncFormatter::set_locs(
  self : FuncFormatter,
  locations : Array[Double],
) -> Unit {
  self.base.set_locs(locations)
}

///|
pub fn FuncFormatter::set_locs_view(
  self : FuncFormatter,
  locations : TickValues,
) -> Unit {
  self.base.set_locs_view(locations)
}

///|
pub fn FuncFormatter::axis(self : FuncFormatter) -> FormatterAxisBinding? {
  self.base.axis()
}

///|
pub fn FuncFormatter::set_axis(
  self : FuncFormatter,
  axis : FormatterAxisBinding?,
) -> Unit {
  self.base.set_axis(axis)
}

///|
pub fn FuncFormatter::create_dummy_axis(
  self : FuncFormatter,
  minpos~ : Double = 0.0,
) -> Unit {
  self.base.create_dummy_axis(minpos~)
}

///|
pub fn FuncFormatter::get_offset(self : FuncFormatter) -> String {
  self.base.get_offset()
}
