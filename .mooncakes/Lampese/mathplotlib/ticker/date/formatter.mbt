///|
/// A date formatter that converts numeric UTC day values to strings in a fixed
/// offset or a rule zone. `%z` emits `+HHMM[SS]`; `%Z` uses the TZif
/// designation when available, otherwise `UTC` or `UTC+HH:MM[:SS]`.
pub struct DateFormatter {
  format : String
  offset_minutes : Int32
  timezone : DateTimeZone?
  priv timezone_source : FormatterTimezone
  priv mode : DateFormatMode
  priv usetex : Bool
}

///|
/// Construct a DateFormatter, capturing tz or the current timezone rc. Invalid
/// names raise here. Supply either a string tz or a typed timezone, not both.
///
/// ```mbt check
/// test {
///   let formatter = @date.date_formatter("%H:%M %Z", tz="XST-5:45")
///   assert_eq(formatter.format_value(0.0), "05:45 XST")
/// }
/// ```
pub fn date_formatter(
  format : String,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateFormatter raise DateError {
  let zone = selected_timezone(tz, timezone)
  {
    format,
    offset_minutes: zone.initial_offset_minutes(),
    timezone: Some(zone),
    timezone_source: Captured,
    mode: Fixed,
    usetex: false,
  }
}

///|
/// Return a copy that formats instants in a fixed offset east of UTC.
/// Reject offsets outside `-1439..1439` minutes.
///
/// ```mbt check
/// test {
///   let formatter = @date.date_formatter("%H:%M %z %Z").with_offset(345)
///   assert_eq(formatter.offset_minutes(), 345)
///   assert_eq(formatter.format_value(0.0), "05:45 +0545 UTC+05:45")
/// }
/// ```
pub fn DateFormatter::with_offset(
  self : DateFormatter,
  offset_minutes : Int32,
) -> DateFormatter raise DateError {
  validate_offset(offset_minutes)
  { ..self.copy(), offset_minutes, timezone: None, timezone_source: Captured, }
}

///|
/// Return a copy that formats UTC instants using a transition/TZif zone.
/// Label conversion retains historical seconds and future footer rules.
pub fn DateFormatter::with_timezone(
  self : DateFormatter,
  timezone : DateTimeZone,
) -> DateFormatter {
  {
    ..self.copy(),
    offset_minutes: timezone.initial_offset_minutes(),
    timezone: Some(timezone),
    timezone_source: Captured,
  }
}

///|
pub fn DateFormatter::format(self : DateFormatter) -> String {
  self.format
}

///|
/// Return whole offset minutes (truncated toward zero for TZif history).
/// When a zone is configured, use `timezone` for exact instant-dependent offsets.
pub fn DateFormatter::offset_minutes(self : DateFormatter) -> Int32 {
  self.offset_minutes
}

///|
/// Return the initially configured zone, if any. Auto/Concise with omitted or
/// named tz re-resolve it while formatting; use with_timezone for a fixed binding.
pub fn DateFormatter::timezone(self : DateFormatter) -> DateTimeZone? {
  self.timezone
}

///|
pub fn DateFormatter::format_value(
  self : DateFormatter,
  value : Double,
) -> String {
  try {
    if self.mode is Auto(_) {
      return self.auto_value(value, None)
    }
    let text = format_date(self.converted_date(value), self.format)
    if self.usetex {
      wrap_date_in_tex(text)
    } else {
      text
    }
  } catch {
    _ => Double::to_string(value)
  }
}

///|
fn choose_format(span : Double) -> String {
  if span < 1.0 / 86400.0 {
    "%H:%M:%S.%f"
  } else if span < 1.0 / 24.0 {
    "%H:%M:%S"
  } else if span < 1.0 {
    "%H:%M"
  } else if span < 60.0 {
    "%Y-%m-%d"
  } else if span < 365.0 * 2.0 {
    "%Y-%m"
  } else {
    "%Y"
  }
}

///|
/// Legacy UTC helper choosing a readable format for a numeric date range.
pub fn auto_date_formatter(lower : Double, upper : Double) -> DateFormatter {
  {
    format: choose_format(Double::abs(upper - lower)),
    offset_minutes: 0,
    timezone: None,
    timezone_source: Captured,
    mode: Fixed,
    usetex: false,
  }
}

///|
/// Legacy UTC/fixed-offset helper formatting an explicitly supplied tick list.
/// An invalid offset returns an empty list, as with `date_tick_values`.
pub fn format_date_ticks(
  values : Array[Double],
  format~ : String = "",
  offset_minutes~ : Int32 = 0,
  timezone? : DateTimeZone,
) -> Array[String] {
  let selected_offset = try {
    validate_offset(offset_minutes)
    offset_minutes
  } catch {
    _ => return []
  }
  let selected = if format == "" {
    if values.length() < 2 {
      "%Y-%m-%d"
    } else {
      choose_format(Double::abs(values[values.length() - 1] - values[0]))
    }
  } else {
    format
  }
  let formatter = {
    format: selected,
    offset_minutes: selected_offset,
    timezone,
    timezone_source: Captured,
    mode: Fixed,
    usetex: false,
  }
  let result = Array(capacity=values.length())
  for value in values {
    result.push(formatter.format_value(value))
  }
  result
}
