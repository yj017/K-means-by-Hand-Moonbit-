///|
/// Date conversion with configurable six-level concise axis labels.
pub struct ConciseDateConverter {
  priv converter : DateConverter
}

///|
/// Copy optional format arrays. As in the pinned upstream constructor, its
/// superclass initialization resets interval_multiples to true. Format-array
/// validation occurs in axisinfo when the formatter is constructed.
pub fn ConciseDateConverter::new(
  formats? : Array[String],
  zero_formats? : Array[String],
  offset_formats? : Array[String],
  show_offset~ : Bool = true,
  interval_multiples~ : Bool = true,
) -> ConciseDateConverter {
  ignore(interval_multiples)
  {
    converter: {
      mode: ConciseConverter(
        formats.map(values => values.copy()),
        zero_formats.map(values => values.copy()),
        offset_formats.map(values => values.copy()),
        show_offset,
      ),
      multiples: true,
    },
  }
}

///|
pub fn ConciseDateConverter::as_converter(
  self : ConciseDateConverter,
) -> DateConverter {
  self.converter.copy()
}

///|
pub fn ConciseDateConverter::axisinfo(
  self : ConciseDateConverter,
  unit? : DateTimeZone,
) -> DateAxisInfo raise DateError {
  self.converter.axisinfo(unit?)
}

///|
pub fn ConciseDateConverter::convert(
  self : ConciseDateConverter,
  values : Array[DateTime],
) -> Array[Double] {
  self.converter.convert(values)
}

///|
pub fn ConciseDateConverter::convert_value(
  self : ConciseDateConverter,
  value : DateTime,
) -> Double {
  self.converter.convert_value(value)
}

///|
pub fn ConciseDateConverter::default_unit(
  self : ConciseDateConverter,
  value : DateTime,
) -> DateTimeZone {
  self.converter.default_unit(value)
}

///|
pub fn ConciseDateConverter::default_units(
  self : ConciseDateConverter,
  values : Array[DateTime],
) -> DateTimeZone? {
  self.converter.default_units(values)
}
