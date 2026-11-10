///|
priv enum DateConverterMode {
  AutoConverter
  ConciseConverter(Array[String]?, Array[String]?, Array[String]?, Bool)
}

///|
/// Typed date conversion and default axis configuration. DateTime values carry
/// explicit UTC offsets; empty arrays have no inferred unit.
pub struct DateConverter {
  priv mode : DateConverterMode
  priv multiples : Bool
}

///|
/// Configure automatic date labels with the original default interval tables.
///
/// ```mbt check
/// test {
///   let converter = @date.DateConverter::new()
///   let info = converter.axisinfo()
///   let values = converter.convert([
///     @date.datetime(2024, 1, 1),
///     @date.datetime(2024, 1, 2, hour=16),
///   ])
///   let ticks = info.major_locator().tick_values(values[0], values[1])
///   assert_true(!info.major_formatter().format_values(ticks).is_empty())
/// }
/// ```
pub fn DateConverter::new(interval_multiples~ : Bool = true) -> DateConverter {
  { mode: AutoConverter, multiples: interval_multiples, }
}

///|
pub fn DateConverter::copy(self : DateConverter) -> DateConverter {
  let mode = match self.mode {
    AutoConverter => AutoConverter
    ConciseConverter(formats, zeros, offsets, show) =>
      ConciseConverter(
        formats.map(values => values.copy()),
        zeros.map(values => values.copy()),
        offsets.map(values => values.copy()),
        show,
      )
  }
  { mode, multiples: self.multiples, }
}

///|
pub fn DateConverter::interval_multiples(self : DateConverter) -> Bool {
  self.multiples
}

///|
/// Convert flat, typed datetime values through the shared epoch implementation.
/// The inferred label timezone never changes numeric instants.
pub fn DateConverter::convert(
  _self : DateConverter,
  values : Array[DateTime],
) -> Array[Double] {
  values.map(value => value.to_ordinal())
}

///|
pub fn DateConverter::convert_value(
  _self : DateConverter,
  value : DateTime,
) -> Double {
  value.to_ordinal()
}

///|
/// Retain a rule zone, or construct the value's exact fixed-second offset unit.
/// This does not read or lock the numeric epoch.
pub fn DateConverter::default_unit(
  _self : DateConverter,
  value : DateTime,
) -> DateTimeZone {
  match value.timezone {
    Some(zone) => zone
    None => try! fixed_timezone_seconds(value.offset_seconds)
  }
}

///|
/// Infer the first date's unit. There are no missing or heterogeneous entries
/// in Array[DateTime]; an empty array has no unit.
pub fn DateConverter::default_units(
  self : DateConverter,
  values : Array[DateTime],
) -> DateTimeZone? {
  if values.is_empty() {
    None
  } else {
    Some(self.default_unit(values[0]))
  }
}

///|
/// Return fresh default locators and formatter, without converting or locking
/// the epoch. Limits remain Gregorian date values until the axis needs them.
pub fn DateConverter::axisinfo(
  self : DateConverter,
  unit? : DateTimeZone,
) -> DateAxisInfo raise DateError {
  let automatic = AutoDateLocator::new(
    interval_multiples=self.multiples,
    timezone?=unit,
  )
  let automatic = match unit {
    Some(zone) => automatic.with_timezone(zone)
    None => automatic
  }
  let locator = automatic.as_locator()
  let formatter = match self.mode {
    AutoConverter =>
      AutoDateFormatter::new(locator~, timezone?=unit).as_formatter()
    ConciseConverter(formats, zero_formats, offset_formats, show_offset) =>
      concise_date_formatter(
        timezone?=unit,
        formats?,
        zero_formats?,
        offset_formats?,
        show_offset~,
      ).as_formatter()
  }
  let formatter = match unit {
    Some(zone) => formatter.with_timezone(zone)
    None => formatter
  }
  {
    locator,
    formatter,
    label: "",
    default_limits: (datetime(1970, 1, 1), datetime(1970, 1, 2)),
  }
}

///|
/// Dispatch using the current date.converter and date.interval_multiples rc.
/// Already constructed converters and enabled axes retain their snapshots.
pub fn default_date_converter() -> DateConverter {
  let multiples = @config.date_interval_multiples()
  if @config.date_converter() == "concise" {
    ConciseDateConverter::new(interval_multiples=multiples).as_converter()
  } else {
    DateConverter::new(interval_multiples=multiples)
  }
}
