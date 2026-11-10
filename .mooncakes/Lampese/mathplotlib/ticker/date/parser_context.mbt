///|
priv enum ParserZoneSource {
  Tzif(@tztypes.TzifData)
  Posix(@tztypes.PosixTzRule)
}

///|
/// Clock and host-local rules for date-string parsing. Explicit contexts avoid
/// system files and use the same TZif/POSIX engine as ordinary date axes.
pub struct DateParserContext {
  priv source : ParserZoneSource
  priv clock : () -> Int64
  priv local_override : ParserLocalSnapshot?
}

///|
fn parser_clock() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
/// Supply raw TZif bytes and, optionally, a Unix-millisecond clock. Construction
/// does not read the clock or lock the numeric date epoch.
pub fn DateParserContext::from_tzif(
  data : Bytes,
  clock? : () -> Int64,
) -> DateParserContext raise DateError {
  {
    source: Tzif(date_tzif_data(data)),
    clock: clock.unwrap_or(parser_clock),
    local_override: None,
  }
}

///|
/// Supply a POSIX TZ specification, including standard/daylight names and rules.
pub fn DateParserContext::from_posix(
  spec : String,
  clock? : () -> Int64,
) -> DateParserContext raise DateError {
  let data = @utf8.encode("\n" + spec + "\n")
  let rule = match @tzparser.parse_footer(data, offset=0, version=b'3') {
    Ok(Some(rule)) => rule
    _ => raise DateError::InvalidDate(message="invalid parser POSIX timezone")
  }
  validate_offset_seconds(rule.std_offset)
  if rule.dst_offset is Some(offset) {
    validate_offset_seconds(offset)
  }
  {
    source: Posix(rule),
    clock: clock.unwrap_or(parser_clock),
    local_override: None,
  }
}

///|
pub fn DateParserContext::utc(clock? : () -> Int64) -> DateParserContext {
  try! DateParserContext::from_posix("UTC0", clock?)
}

///|
/// Resolve TZ/TZDIR or /etc/localtime using the runtime's file capability.
/// Unavailable host-local rules require an explicit context; no UTC fallback.
pub fn DateParserContext::system(
  clock? : () -> Int64,
) -> DateParserContext raise DateError {
  match @env.get_env_var("TZ") {
    Some(raw) => {
      let spec = if raw.has_prefix(":") { raw[1:].to_owned() } else { raw }
      if spec == "" {
        return DateParserContext::utc(clock?)
      }
      let paths = if spec.has_prefix("/") {
        [spec]
      } else {
        [
          @env.get_env_var("TZDIR").unwrap_or("/usr/share/zoneinfo") +
          "/" +
          spec,
          "/usr/share/lib/zoneinfo/" + spec,
          "/usr/lib/zoneinfo/" + spec,
        ]
      }
      for path in paths {
        if @date_host.read_zone_file(path) is Some(data) {
          return DateParserContext::from_tzif(data, clock?)
        }
      }
      return DateParserContext::from_posix(spec, clock?)
    }
    None => {
      if @date_host.read_zone_file("/etc/localtime") is Some(data) {
        return DateParserContext::from_tzif(data, clock?)
      }
      raise DateError::InvalidDate(
        message="host local timezone is unavailable; supply DateParserContext",
      )
    }
  }
}

///|
fn DateParserContext::info(
  self : DateParserContext,
  seconds : Int64,
) -> (Int32, Bool, String) raise DateError {
  match self.source {
    Tzif(data) =>
      match @tzif.active_offset(data, seconds) {
        Ok(info) => (info.utoff, info.is_dst, info.abbr)
        Err(_) =>
          raise DateError::InvalidDate(
            message="parser timezone query is outside its supported range",
          )
      }
    Posix(rule) => {
      if rule.dst_offset is None {
        return (rule.std_offset, false, rule.std_abbr)
      }
      match @tzposix.apply_posix_rule(rule, seconds) {
        Ok(info) => info
        Err(_) =>
          raise DateError::InvalidDate(
            message="parser POSIX timezone query failed",
          )
      }
    }
  }
}

///|
fn DateParserContext::local_now(
  self : DateParserContext,
  millis : Int64,
) -> DateTime raise DateError {
  if millis < -62135683200000L || millis >= 253402387200000L {
    raise DateError::InvalidDate(
      message="parser clock is outside years 1..9999",
    )
  }
  let seconds = locator_floor_div64(millis, 1000L)
  let (offset, _, _) = self.info(seconds)
  let wall_microseconds = millis * 1000L + Int64::from_int(offset) * 1_000_000L
  if wall_microseconds < -62135596800000000L ||
    wall_microseconds >= 253402300800000000L {
    raise DateError::InvalidDate(
      message="parser local clock is outside years 1..9999",
    )
  }
  locator_datetime_microseconds(wall_microseconds, 0)
}

///|
priv struct ParserLocalSnapshot {
  standard : Int32
  daylight : Int32
  standard_name : String
  daylight_name : String
}

///|
fn parser_short_name(name : String) -> String {
  let chars = name.to_array()
  String::from_array(chars[:Int32::min(9, chars.length())])
}

///|
fn DateParserContext::snapshot(
  self : DateParserContext,
  millis : Int64,
) -> ParserLocalSnapshot raise DateError {
  if self.local_override is Some(snapshot) {
    return snapshot
  }
  let seconds = locator_floor_div64(millis, 1000L)
  let january = locator_floor_div64(seconds, 31_557_600L) * 31_557_600L
  let (jan, _, jan_name) = self.info(january)
  let (july, _, july_name) = self.info(january + 15_778_800L)
  if jan > july {
    {
      standard: july,
      daylight: jan,
      standard_name: parser_short_name(july_name),
      daylight_name: parser_short_name(jan_name),
    }
  } else {
    {
      standard: jan,
      daylight: july,
      standard_name: parser_short_name(jan_name),
      daylight_name: parser_short_name(july_name),
    }
  }
}

///|
/// Supply a host's explicit standard/daylight descriptor instead of the pinned
/// CPython sampling profile. Rules still provide actual clock and DST queries.
/// The two names are copied at construction; no clock or epoch is read.
pub fn DateParserContext::with_local_info(
  self : DateParserContext,
  standard_seconds : Int32,
  daylight_seconds : Int32,
  names : Array[String],
) -> DateParserContext raise DateError {
  validate_offset_seconds(standard_seconds)
  validate_offset_seconds(daylight_seconds)
  if names.length() != 2 {
    raise DateError::InvalidDate(
      message="parser local names must contain standard and daylight entries",
    )
  }
  {
    ..self,
    local_override: Some({
      standard: standard_seconds,
      daylight: daylight_seconds,
      standard_name: names[0],
      daylight_name: names[1],
    }),
  }
}
