///|
pub(all) enum DateParseWarning {
  UnknownTimezone(String)
} derive(Debug, Eq)

///|
pub extend DateParseWarning with @debug.Debug::{to_repr}

///|
pub extend DateParseWarning with Eq::{equal, not_equal}

///|
/// Default dateutil grammar with an explicit clock/local-zone context. The
/// reference year and local-name descriptor are captured at construction.
pub struct DateStringParser {
  priv context : DateParserContext
  priv reference : Int32
  priv snapshot : ParserLocalSnapshot
  priv mut diagnostics : Array[DateParseWarning]
}

///|
/// Construct with host-local rules, or provide an explicit portable context.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::from_posix(
///     "EST5EDT,M3.2.0/2,M11.1.0/2",
///     clock=fn() { 1781524800000L },
///   )
///   let parser = @date.DateStringParser::new(context~)
///   let value = @date.datestr2num("Nov 3, 2024 01:30 EST", parser~)
///   assert_eq(@date.num2date(value).hour(), 6)
/// }
/// ```
pub fn DateStringParser::new(
  context? : DateParserContext,
  reference_year? : Int32,
) -> DateStringParser raise DateError {
  let context = context.unwrap_or_else(() => DateParserContext::system())
  let millis = (context.clock)()
  let current = context.local_now(millis)
  let reference = reference_year.unwrap_or(current.year)
  if reference < 1 || reference > 9999 {
    raise DateError::InvalidDate(
      message="parser reference year must be in 1..9999",
    )
  }
  { context, reference, snapshot: context.snapshot(millis), diagnostics: [], }
}

///|
pub fn DateStringParser::copy(self : DateStringParser) -> DateStringParser {
  { ..self, diagnostics: self.diagnostics.copy(), }
}

///|
pub fn DateStringParser::reference_year(self : DateStringParser) -> Int32 {
  self.reference
}

///|
pub fn DateStringParser::local_names(self : DateStringParser) -> Array[String] {
  [self.snapshot.standard_name, self.snapshot.daylight_name]
}

///|
pub fn DateStringParser::local_offsets(
  self : DateStringParser,
) -> (Int32, Int32) {
  (self.snapshot.standard, self.snapshot.daylight)
}

///|
/// Diagnostics from the last operation, including warnings emitted before a
/// later parse/conversion error. Returned arrays do not alias parser state.
pub fn DateStringParser::warnings(
  self : DateStringParser,
) -> Array[DateParseWarning] {
  self.diagnostics.copy()
}

///|
priv struct ParsedStringDate {
  value : DateTime
  aware : Bool
  fold : Bool
}

///|
fn DateStringParser::parse_record(
  self : DateStringParser,
  text : String,
  default_date : DateTime?,
) -> ParsedStringDate raise DateError {
  try {
    let fallback = match default_date {
      Some(value) => value
      None => {
        let now = self.context.local_now((self.context.clock)())
        datetime(now.year, now.month, now.day)
      }
    }
    let fields = parser_select(text, self.reference)
    let naive = parser_build_naive(fields, fallback)
    let fold = if fields.day is None && fields.weekday is Some(_) {
      false
    } else {
      parser_default_fold(fallback)
    }
    let inherited = default_date is Some(_)
    if fields.tzname is Some(name) &&
      [self.snapshot.standard_name, self.snapshot.daylight_name].contains(name) {
      let (offset, actual_name) = self.context.local_info(
        naive,
        self.snapshot,
        fold,
      )
      let (offset, actual_name) = if actual_name != name {
        let (later_offset, later_name) = self.context.local_info(
          naive,
          self.snapshot,
          true,
        )
        if later_name == name {
          (later_offset, later_name)
        } else {
          (offset, actual_name)
        }
      } else {
        (offset, actual_name)
      }
      if actual_name != name && parser_utc(name) {
        return {
          value: parser_set_offset(naive, 0, Some("UTC")),
          aware: true,
          fold,
        }
      }
      return {
        value: parser_set_offset(naive, offset, Some(actual_name)),
        aware: true,
        fold,
      }
    }
    if fields.tzoffset is Some(offset) {
      return {
        value: parser_set_offset(
          naive,
          offset,
          if offset == 0 {
            Some("UTC")
          } else {
            fields.tzname
          },
        ),
        aware: true,
        fold,
      }
    }
    if fields.tzname is Some(name) {
      self.diagnostics.push(UnknownTimezone(name))
    }
    { value: naive, aware: inherited, fold, }
  } catch {
    DateError::InvalidDate(message~) =>
      raise DateError::InvalidDate(message=message + ": " + text)
    DateError::InvalidFormat(message~) =>
      raise DateError::InvalidFormat(message=message + ": " + text)
  }
}

///|
pub fn DateStringParser::parse(
  self : DateStringParser,
  text : String,
  default_date? : DateTime,
) -> DateTime raise DateError {
  self.diagnostics = []
  self.parse_record(text, default_date).value
}

///|
pub fn DateStringParser::parse_many(
  self : DateStringParser,
  texts : Array[String],
  default_date? : DateTime,
) -> Array[DateTime] raise DateError {
  self.diagnostics = []
  texts.map(text => self.parse_record(text, default_date).value)
}

///|
fn parser_check_utc(value : DateTime) -> Unit raise DateError {
  let instant = rruleset_instant(value)
  if instant < -62135596800000000L || instant >= 253402300800000000L {
    raise DateError::InvalidDate(
      message="parsed aware UTC date is outside years 1..9999",
    )
  }
}

///|
fn parser_encode(value : DateTime) -> Double raise DateError {
  parser_check_utc(value)
  ignore(selected_epoch())
  value.to_ordinal()
}

///|
pub fn DateStringParser::to_number(
  self : DateStringParser,
  text : String,
  default_date? : DateTime,
) -> Double raise DateError {
  self.diagnostics = []
  parser_encode(self.parse_record(text, default_date).value)
}

///|
/// Preserve datestr2num's explicit-default scalar loop and no-default NumPy
/// vectorization probe, conversion order, and first-aware mixed-array behavior.
pub fn DateStringParser::to_numbers(
  self : DateStringParser,
  texts : Array[String],
  default_date? : DateTime,
) -> Array[Double] raise DateError {
  self.diagnostics = []
  if texts.is_empty() {
    return []
  }
  if default_date is Some(_) {
    return texts.map(text => {
      parser_encode(self.parse_record(text, default_date).value)
    })
  }
  ignore(self.parse_record(texts[0], None))
  let records = texts.map(text => self.parse_record(text, None))
  let values = if records[0].aware {
    records.map(record => {
      let value = if record.aware {
        record.value
      } else {
        self.context.interpret_naive(record.value, record.fold)
      }
      parser_check_utc(value)
      value
    })
  } else {
    records.map(record => record.value)
  }
  ignore(selected_epoch())
  values.map(value => value.to_ordinal())
}

///|
let default_string_parser : Ref[DateStringParser?] = Ref(None)

///|
/// Diagnostics from the last default free-helper operation. Reading them does
/// not construct a parser or access the clock/epoch. Explicit parser instances
/// expose their independent warnings() arrays.
pub fn date_parse_warnings() -> Array[DateParseWarning] {
  match default_string_parser.val {
    Some(parser) => parser.warnings()
    None => []
  }
}

///|
fn selected_string_parser() -> DateStringParser raise DateError {
  match default_string_parser.val {
    Some(parser) => parser
    None => {
      let parser = DateStringParser::new()
      default_string_parser.val = Some(parser)
      parser
    }
  }
}

///|
/// Convert a general date string through the fixed default dateutil grammar.
pub fn datestr2num(
  text : String,
  default_date? : DateTime,
  parser? : DateStringParser,
) -> Double raise DateError {
  parser.unwrap_or_else(selected_string_parser).to_number(text, default_date?)
}

///|
/// Flat-array counterpart of datestr2num. Empty input does not select the host
/// parser or read/lock the numeric epoch.
pub fn datestrs2num(
  texts : Array[String],
  default_date? : DateTime,
  parser? : DateStringParser,
) -> Array[Double] raise DateError {
  if texts.is_empty() {
    return []
  }
  parser.unwrap_or_else(selected_string_parser).to_numbers(texts, default_date?)
}
