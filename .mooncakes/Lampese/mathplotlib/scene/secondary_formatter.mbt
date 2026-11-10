///|
pub fn SecondaryAxis::formatter_axis_binding(
  self : SecondaryAxis,
) -> @ticker.FormatterAxisBinding {
  self.numeric_axis.formatter_axis_binding()
}

///|
pub fn SecondaryAxis::formatter_warnings(self : SecondaryAxis) -> Array[String] {
  self.numeric_axis.formatter_warnings()
}

///|
pub fn SecondaryAxis::tick_group_is_null(
  self : SecondaryAxis,
  minor~ : Bool = false,
) -> Bool {
  self.numeric_axis.tick_group_is_null(minor~)
}

///|
pub fn SecondaryAxis::set_named_formatter(
  self : SecondaryAxis,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.numeric_axis.set_named_formatter(formatter)
}

///|
pub fn SecondaryAxis::named_formatter(
  self : SecondaryAxis,
) -> @ticker.BaseFormatter? {
  self.numeric_axis.named_formatter()
}

///|
pub fn SecondaryAxis::set_minor_named_formatter(
  self : SecondaryAxis,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.numeric_axis.set_minor_named_formatter(formatter)
}

///|
pub fn SecondaryAxis::minor_named_formatter(
  self : SecondaryAxis,
) -> @ticker.BaseFormatter? {
  self.numeric_axis.minor_named_formatter()
}

///|
pub fn SecondaryAxis::clear_named_formatter(self : SecondaryAxis) -> Unit {
  self.numeric_axis.clear_named_formatter()
}

///|
pub fn SecondaryAxis::clear_minor_named_formatter(self : SecondaryAxis) -> Unit {
  self.numeric_axis.clear_minor_named_formatter()
}

///|
pub fn SecondaryAxis::formatter_tick_locations_checked(
  self : SecondaryAxis,
  minor~ : Bool = false,
) -> @ticker.FormatterLocations raise @core.DataError {
  if !minor && self.legacy_sampling {
    return @ticker.FormatterLocations::NdArray(self.major_tick_view_checked())
  }
  self.numeric_axis.formatter_tick_locations_checked(
    self.numeric_axis.stored_view_limits(),
    minor~,
  )
}

///|
pub fn SecondaryAxis::tick_labels_checked(
  self : SecondaryAxis,
  values : Array[Double],
  view? : @core.Limits,
) -> Array[String] raise @core.DataError {
  match self.named_formatter() {
    Some(formatter) => formatter.format_ticks(values)
    None =>
      match self.formatter() {
        Some(formatter) => formatter.format_values_with_view(values, view)
        None => values.map(value => value.to_string())
      }
  }
}

///|
pub fn SecondaryAxis::minor_tick_labels_checked(
  self : SecondaryAxis,
  values : Array[Double],
  view? : @core.Limits,
) -> Array[String] raise @core.DataError {
  ignore(view)
  match self.minor_named_formatter() {
    Some(formatter) => formatter.format_ticks(values)
    None => Array::make(values.length(), "")
  }
}

///|
pub fn SecondaryAxis::formatter_offset_label_checked(
  self : SecondaryAxis,
  values : Array[Double],
  view? : @core.Limits,
) -> String raise @core.DataError {
  match self.named_formatter() {
    Some(formatter) => formatter.get_offset_checked()
    None =>
      match self.formatter() {
        Some(formatter) => formatter.offset_label_with_view(values, view)
        None => ""
      }
  }
}
