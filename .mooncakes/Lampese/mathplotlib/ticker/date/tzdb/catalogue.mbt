///|
// Parsed zones are immutable from outside ticker/date. Aliases share the
// content index, so each distinct TZif is parsed only on its first lookup.
let parsed_zones : Map[Int32, @date.DateTimeZone] = Map([])

///|
/// Return the bundled IANA database release.
///
/// ```mbt check
/// test {
///   assert_eq(@tzdb.version(), "2026e")
/// }
/// ```
pub fn version() -> String {
  data_version
}

///|
/// Return a fresh, lexically sorted list of all bundled IANA Zone and Link names.
/// Includes compatibility aliases such as `US/Eastern` and `UTC`.
///
/// ```mbt check
/// test {
///   let names = @tzdb.available_timezones()
///   assert_true(names.contains("Asia/Shanghai"))
///   assert_true(names.contains("US/Eastern"))
/// }
/// ```
pub fn available_timezones() -> Array[String] {
  zone_entries.map(entry => entry.0)
}

///|
fn zone_index(name : String) -> Int32 raise @date.DateError {
  let mut low = 0
  let mut high = zone_entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    let (key, index) = zone_entries[middle]
    if key == name {
      return index
    } else if key.lexical_compare(name) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  raise @date.DateError::InvalidDate(
    message="unknown IANA timezone '\{name}' (database \{data_version})",
  )
}

///|
/// Resolve an exact, case-sensitive IANA name using bundled 2026e data.
/// Historical seconds, designations and POSIX future rules are retained.
/// Unknown names raise `DateError`; no filesystem, environment variable or
/// network is consulted. This optional package must be imported explicitly.
///
/// ```mbt check
/// test {
///   let zone = @tzdb.timezone("Asia/Shanghai")
///   let instant = @date.datetime(2024, 1, 1)
///   let formatter = @date.date_formatter("%H:%M %Z").with_timezone(zone)
///   assert_eq(formatter.format_value(instant.to_ordinal()), "08:00 CST")
/// }
/// ```
pub fn timezone(name : String) -> @date.DateTimeZone raise @date.DateError {
  let index = zone_index(name)
  match parsed_zones.get(index) {
    Some(zone) => zone
    None => {
      let zone = @date.tzif_timezone(embedded_zones[index])
      parsed_zones[index] = zone
      zone
    }
  }
}

///|
/// Build a date-string parser context from the optional bundled database,
/// without host filesystem access. The clock returns signed Unix milliseconds.
///
/// ```mbt check
/// test {
///   let context = @tzdb.parser_context("America/New_York", clock=fn() {
///     1781524800000L
///   })
///   let parser = @date.DateStringParser::new(context~)
///   assert_eq(parser.parse("2024-11-03 01:30 EST").offset_seconds(), -18000)
/// }
/// ```
pub fn parser_context(
  name : String,
  clock? : () -> Int64,
) -> @date.DateParserContext raise @date.DateError {
  @date.DateParserContext::from_tzif(embedded_zones[zone_index(name)], clock?)
}

///|
/// Make one bundled name available to get_timezone/tz-based defaults without
/// host files. Uses dateutil's 32-bit compatibility profile; timezone(name)
/// continues to return the complete IANA 64-bit/footer zone.
pub fn register_timezone(name : String) -> Unit raise @date.DateError {
  if name == "UTC" {
    return
  }
  @date.register_timezone(name, embedded_zones[zone_index(name)])
}
