// tzif-engine: IANA TZif timezone conversion engine.
// Public API — load TZif data, convert between UTC and local time.

// Parse raw TZif bytes (v2 or v3) into a TzifData structure.

///|
pub fn load(data : Bytes) -> @types.TzifResult[@types.TzifData] {
  let result1 = @parser.parse_header(data, 0)
  let (v1_header, offset) = match result1 {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if v1_header.version != b'2' && v1_header.version != b'3' {
    return Err(UnsupportedVersion(v1_header.version))
  }
  // Skip the compatibility block with its four-byte timestamps and eight-byte
  // leap records (timestamp plus correction).
  let v2_offset = match @parser.data_block_end(data, v1_header, offset, 4) {
    Ok(value) => value
    Err(error) => return Err(error)
  }

  let result2 = @parser.parse_header(data, v2_offset)
  let (v2_header, offset) = match result2 {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  if v2_header.version != v1_header.version {
    return Err(InvalidTransitionTable("TZif header versions do not match"))
  }
  let result3 = @parser.parse_body(data, v2_header, offset)
  let body = match result3 {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  // Both TZif v2 and v3 carry a newline-framed POSIX footer immediately after
  // the second data block. The parser owns framing and grammar validation.
  let posix = match
    @parser.parse_footer(
      data,
      offset=body.end_offset,
      version=v2_header.version,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let timezone = @types.TzifData::{
    version: v2_header.version,
    time_types: body.time_types,
    transitions: body.transitions,
    leap_seconds: body.leap_seconds,
    standard_indicators: body.standard_indicators,
    utc_indicators: body.utc_indicators,
    posix_rule: posix,
  }
  match validate(timezone) {
    Ok(_) => Ok(timezone)
    Err(error) => Err(error)
  }
}

// Convert a UTC timestamp to local time in the given timezone.

///|
pub fn utc_to_local(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.TzifResult[@types.LocalDateTime] {
  @converter.utc_to_local(tz, utc_time)
}

///|
/// Return offset metadata effective at a UTC instant without decomposing the
/// timestamp into calendar fields.
pub fn active_offset(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.TzifResult[@types.OffsetInfo] {
  @converter.active_offset(tz, utc_time)
}

///|
/// Return every UTC candidate for a local civil time in ascending order.
pub fn local_time_candidates(
  tz : @types.TzifData,
  ldt : @types.LocalDateTime,
) -> @types.TzifResult[Array[Int64]] {
  @converter.local_time_candidates(tz, ldt)
}

///|
/// Classify a local time as unique, ambiguous, or a gap without selecting a
/// candidate automatically.
pub fn resolve_local(
  tz : @types.TzifData,
  ldt : @types.LocalDateTime,
) -> @types.TzifResult[@types.LocalTimeResolution] {
  @converter.resolve_local(tz, ldt)
}

// Convert a local date-time to a UTC timestamp in the given timezone.

///|
pub fn local_to_utc(
  tz : @types.TzifData,
  ldt : @types.LocalDateTime,
  strategy : @types.AmbiguityStrategy,
) -> @types.TzifResult[Int64] {
  @converter.local_to_utc(tz, ldt, strategy)
}

///|
/// Parse a local civil timestamp in strict `YYYY-MM-DDTHH:MM:SS` form.
pub fn parse_iso_local(
  input : String,
) -> @types.TzifResult[@types.LocalDateTime] {
  @text.parse_iso_local(input)
}

///|
/// Parse an ISO-8601 date-time carrying `Z`, `+HH:MM`, or `+HH:MM:SS`.
pub fn parse_iso_offset(
  input : String,
) -> @types.TzifResult[@types.OffsetDateTime] {
  @text.parse_iso_offset(input)
}

///|
/// Parse exactly `YYYY-MM-DDTHH:MM:SSZ` into POSIX UTC seconds.
pub fn parse_iso_utc(input : String) -> @types.TzifResult[Int64] {
  @text.parse_iso_utc(input)
}

///|
/// Format civil fields as `YYYY-MM-DDTHH:MM:SS`.
pub fn format_iso_local(
  local_time : @types.LocalDateTime,
) -> @types.TzifResult[String] {
  @text.format_iso_local(local_time)
}

///|
/// Format a resolved local time with its numeric UTC offset.
pub fn format_iso_zoned(
  local_time : @types.LocalDateTime,
) -> @types.TzifResult[String] {
  @text.format_iso_zoned(local_time)
}

///|
/// Format a numeric UTC offset without losing historical seconds.
pub fn format_numeric_offset(offset : Int) -> @types.TzifResult[String] {
  @text.format_numeric_offset(offset)
}

///|
/// Format a UTC instant at an explicit ISO-8601 numeric offset.
pub fn format_iso_offset(
  utc_time : Int64,
  offset : Int,
) -> @types.TzifResult[String] {
  @text.format_iso_offset(utc_time, offset)
}

///|
/// Format a POSIX UTC timestamp in ISO-8601 UTC form.
pub fn format_iso_utc(utc_time : Int64) -> @types.TzifResult[String] {
  @text.format_iso_utc(utc_time)
}

// Return a human-readable summary of the timezone data.

///|
pub fn info(tz : @types.TzifData) -> String {
  match validate(tz) {
    Err(_) => return "Invalid in-memory TZif data"
    Ok(_) => ()
  }
  let summary = diagnostics(tz)
  let n = tz.transitions.length()
  let version = if tz.version == b'2' { "2" } else { "3" }
  let metadata = "  Metadata: \{summary.leap_second_count} leap records, \{summary.standard_indicator_count} ttisstd flags, \{summary.utc_indicator_count} ttisut flags\n" +
    "  Post-transition: " +
    (if summary.has_posix_footer {
      "POSIX footer extrapolation"
    } else {
      "last explicit type"
    })
  if n == 0 {
    let initial = tz.time_types[0]
    return "TZif v\{version} — 0 transitions\n" +
      "  Initial: \{initial.abbr} (UTC\{format_offset(initial.utoff)})\n" +
      metadata
  }
  let first = tz.transitions[0]
  let last = tz.transitions[n - 1]
  let first_type = tz.time_types[first.type_index]
  let last_type = tz.time_types[last.type_index]
  "\{n} transitions, TZif v\{version} format\n" +
  "  First: \{first_type.abbr} (UTC\{format_offset(first_type.utoff)}) at \{first.utc_time}\n" +
  "  Last:  \{last_type.abbr} (UTC\{format_offset(last_type.utoff)}) at \{last.utc_time}\n" +
  metadata
}

///|
fn format_offset(utoff : Int) -> String {
  match @text.format_numeric_offset(utoff) {
    Ok(value) => value
    Err(_) =>
      if utoff >= 0 {
        "+" + utoff.to_string() + "s"
      } else {
        utoff.to_string() + "s"
      }
  }
}
