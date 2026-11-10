///|
priv struct ConciseSettings {
  formats : Array[String]
  zero_formats : Array[String]
  offset_formats : Array[String]
  show_offset : Bool
}

///|
/// A batch date formatter with Matplotlib's six-level concise label rules.
/// `format_ticks` updates the last offset; configuration copies are independent.
pub struct ConciseDateFormatter {
  priv formatter : DateFormatter
  priv mut offset_string : String
}

///|
fn concise_formats(
  values : Array[String]?,
  defaults : Array[String],
  name : String,
) -> Array[String] raise DateError {
  match values {
    None | Some([]) => defaults.copy()
    Some(values) if values.length() == 6 => values.copy()
    _ =>
      raise DateError::InvalidFormat(
        message=name + " must contain six date formats",
      )
  }
}

///|
/// Construct a concise formatter. tz is resolved when formatting; an omitted
/// tz follows the current timezone rc. The optional format arrays have six entries
/// (years through seconds); empty arrays select defaults. Inputs are copied.
/// `usetex` returns upstream TeX strings; rendering TeX requires backend support.
///
/// ```mbt check
/// test {
///   let formatter = @date.concise_date_formatter()
///   let ticks = [
///     @date.datetime(2024, 1, 1).to_ordinal(),
///     @date.datetime(2024, 1, 2).to_ordinal(),
///   ]
///   assert_eq(formatter.format_ticks(ticks), ["Jan", "02"])
///   assert_eq(formatter.get_offset(), "2024-Jan")
/// }
/// ```
pub fn concise_date_formatter(
  tz? : String,
  timezone? : DateTimeZone,
  formats? : Array[String],
  zero_formats? : Array[String],
  offset_formats? : Array[String],
  show_offset~ : Bool = true,
  usetex~ : Bool = false,
) -> ConciseDateFormatter raise DateError {
  let timezone_source = formatter_timezone_source(tz, timezone)
  let selected_formats = concise_formats(
    formats,
    ["%Y", "%b", "%d", "%H:%M", "%H:%M", "%S.%f"],
    "formats",
  )
  let default_zeros = [
    "",
    selected_formats[0],
    selected_formats[1],
    selected_formats[2],
    selected_formats[3],
    selected_formats[4],
  ]
  if formats is None || formats is Some([]) {
    default_zeros[3] = "%b-%d"
  }
  let settings = {
    formats: selected_formats,
    zero_formats: concise_formats(zero_formats, default_zeros, "zero_formats"),
    offset_formats: concise_formats(
      offset_formats,
      ["", "%Y", "%Y-%b", "%Y-%b-%d", "%Y-%b-%d", "%Y-%b-%d %H:%M"],
      "offset_formats",
    ),
    show_offset,
  }
  {
    formatter: {
      format: "%Y",
      offset_minutes: timezone
      .map(zone => zone.initial_offset_minutes())
      .unwrap_or(0),
      timezone,
      timezone_source,
      mode: Concise(settings),
      usetex,
    },
    offset_string: "",
  }
}

///|
/// Return a standalone date formatter suitable for Axis::set_date_formatter.
pub fn ConciseDateFormatter::as_formatter(
  self : ConciseDateFormatter,
) -> DateFormatter {
  self.formatter.copy()
}

///|
/// Return the last successful batch's shared date text, initially empty.
pub fn ConciseDateFormatter::get_offset(self : ConciseDateFormatter) -> String {
  self.offset_string
}

///|
/// Format a batch and update its shared date text. `inverted` selects the first
/// supplied tick for the offset instead of the last, matching an inverted axis.
/// Empty batches clear the offset; invalid dates raise without changing it.
pub fn ConciseDateFormatter::format_ticks(
  self : ConciseDateFormatter,
  values : Array[Double],
  inverted~ : Bool = false,
) -> Array[String] raise DateError {
  let (labels, offset) = self.formatter.tick_layout(values, inverted)
  self.offset_string = offset
  labels
}

///|
/// Format one value using the default year format, as upstream __call__ does.
pub fn ConciseDateFormatter::format_value(
  self : ConciseDateFormatter,
  value : Double,
) -> String {
  self.formatter.format_value(value)
}

///|
/// Return the format used for individual values (upstream defaultfmt).
pub fn ConciseDateFormatter::default_format(
  self : ConciseDateFormatter,
) -> String {
  self.formatter.format
}

///|
/// Return a copy with a different individual-value format. Batch labels and
/// format_data_short retain their own formats.
pub fn ConciseDateFormatter::with_default_format(
  self : ConciseDateFormatter,
  format : String,
) -> ConciseDateFormatter {
  { formatter: { ..self.formatter.copy(), format, }, offset_string: "", }
}

///|
/// Return a configuration copy controlling upstream TeX string output.
pub fn ConciseDateFormatter::with_usetex(
  self : ConciseDateFormatter,
  usetex : Bool,
) -> ConciseDateFormatter {
  { formatter: self.formatter.with_usetex(usetex), offset_string: "", }
}

///|
/// Format a cursor/status value with a complete date and second-resolution time.
pub fn ConciseDateFormatter::format_data_short(
  self : ConciseDateFormatter,
  value : Double,
) -> String raise DateError {
  format_date(self.formatter.converted_date(value), "%Y-%m-%d %H:%M:%S")
}

///|
/// Return a configuration copy using a fixed label offset, with no prior batch.
pub fn ConciseDateFormatter::with_offset(
  self : ConciseDateFormatter,
  offset_minutes : Int32,
) -> ConciseDateFormatter raise DateError {
  { formatter: self.formatter.with_offset(offset_minutes), offset_string: "", }
}

///|
/// Return a configuration copy using exact transition-aware label conversion.
pub fn ConciseDateFormatter::with_timezone(
  self : ConciseDateFormatter,
  timezone : DateTimeZone,
) -> ConciseDateFormatter {
  { formatter: self.formatter.with_timezone(timezone), offset_string: "", }
}

///|
/// Return a configuration copy controlling shared date text visibility.
pub fn ConciseDateFormatter::with_show_offset(
  self : ConciseDateFormatter,
  show_offset : Bool,
) -> ConciseDateFormatter {
  let formatter = self.formatter.copy()
  let settings = formatter.concise_settings()
  {
    formatter: { ..formatter, mode: Concise({ ..settings, show_offset, }), },
    offset_string: "",
  }
}

///|
pub fn ConciseDateFormatter::formats(
  self : ConciseDateFormatter,
) -> Array[String] {
  self.formatter.concise_settings().formats.copy()
}

///|
pub fn ConciseDateFormatter::zero_formats(
  self : ConciseDateFormatter,
) -> Array[String] {
  self.formatter.concise_settings().zero_formats.copy()
}

///|
pub fn ConciseDateFormatter::offset_formats(
  self : ConciseDateFormatter,
) -> Array[String] {
  self.formatter.concise_settings().offset_formats.copy()
}

///|
pub fn ConciseDateFormatter::show_offset(self : ConciseDateFormatter) -> Bool {
  self.formatter.concise_settings().show_offset
}
