///|
let registered_timezones : Map[String, DateTimeZone] = Map([])

///|
let named_timezone_cache : Map[String, DateTimeZone] = Map([])

///|
fn utc_timezone() -> DateTimeZone {
  {
    initial_offset_seconds: 0,
    initial_abbreviation: Some("UTC"),
    transitions: [],
    footer: None,
    dateutil_footer: false,
    footer_start_seconds: None,
  }
}

///|
/// Register supplied TZif bytes for string-based date timezone lookup. This
/// uses dateutil's 32-bit compatibility block, including its historical/future
/// fallback behavior. Use tzif_timezone directly for full 64-bit IANA rules.
/// Registration is explicit and works without host files, including in browsers.
pub fn register_timezone(name : String, data : Bytes) -> Unit raise DateError {
  if name == "" || name == "UTC" || name.has_prefix(":") {
    raise DateError::InvalidDate(
      message="registered timezone needs a non-UTC name",
    )
  }
  let zone = dateutil_tzif_timezone(data)
  registered_timezones[name] = zone
  ignore(named_timezone_cache.remove(name))
}

///|
/// Remove an explicit TZif registration. Previously constructed consumers keep
/// their captured rules; subsequent name lookups resume normal host resolution.
pub fn unregister_timezone(name : String) -> Unit {
  ignore(registered_timezones.remove(name))
  ignore(named_timezone_cache.remove(name))
}

///|
/// Resolve an explicit string, or the current timezone rc when omitted. Exact
/// "UTC" is portable. Other names use registered bytes, host TZif files, then
/// standard POSIX strings. Unavailable/unknown names raise DateError.
/// Construction and resolution do not read the numeric date epoch or clock.
pub fn get_timezone(name? : String) -> DateTimeZone raise DateError {
  let name = name.unwrap_or(@config.timezone())
  if name == "UTC" {
    return utc_timezone()
  }
  if registered_timezones.get(name) is Some(zone) {
    return zone
  }
  if name != "" && name != ":" {
    if named_timezone_cache.get(name) is Some(zone) {
      return zone
    }
  }
  let zone = resolve_timezone_name(name)
  if name != "" && name != ":" {
    named_timezone_cache[name] = zone
  }
  zone
}

///|
fn resolve_timezone_name(raw : String) -> DateTimeZone raise DateError {
  let name = if raw == "" { @env.get_env_var("TZ").unwrap_or("") } else { raw }
  let name = if name.has_prefix(":") { name[1:].to_owned() } else { name }
  if name == "" {
    if @date_host.read_zone_file("/etc/localtime") is Some(data) {
      return dateutil_tzif_timezone(data)
    }
    raise DateError::InvalidDate(message="host local timezone is unavailable")
  }
  if name == "UTC" {
    return utc_timezone()
  }
  if registered_timezones.get(name) is Some(zone) {
    return zone
  }
  if name.has_prefix("/") {
    if @date_host.read_zone_file(name) is Some(data) {
      return dateutil_tzif_timezone(data)
    }
  } else {
    for
      directory in [
        "/usr/share/zoneinfo", "/usr/lib/zoneinfo", "/usr/share/lib/zoneinfo", "/etc/zoneinfo",
      ] {
      let path = directory + "/" + name
      for path in [path, path.replace_all(old=" ", new="_")] {
        if @date_host.read_zone_file(path) is Some(data) {
          let zone = Some(dateutil_tzif_timezone(data)) catch { _ => None }
          if zone is Some(zone) {
            return zone
          }
        }
      }
    }
    if name.to_array().any(c => c >= '0' && c <= '9') {
      let zone = Some(dateutil_posix_timezone(name)) catch { _ => None }
      if zone is Some(zone) {
        return zone
      }
    } else if name == "GMT" {
      return utc_timezone()
    }
  }
  raise DateError::InvalidDate(
    message="invalid or unavailable timezone '\{raw}'",
  )
}

///|
fn selected_timezone(
  tz : String?,
  timezone : DateTimeZone?,
) -> DateTimeZone raise DateError {
  match (tz, timezone) {
    (Some(_), Some(_)) =>
      raise DateError::InvalidDate(message="use either tz or timezone")
    (_, Some(zone)) => zone
    _ => get_timezone(name?=tz)
  }
}

///|
// DateFormatter captures a zone. Auto/Concise retain the original tz argument
// and resolve it when text is formatted; callbacks receive raw values instead.
priv enum FormatterTimezone {
  Captured
  DefaultTimezone
  NamedTimezone(String)
}

///|
fn formatter_timezone_source(
  tz : String?,
  timezone : DateTimeZone?,
) -> FormatterTimezone raise DateError {
  match (tz, timezone) {
    (Some(_), Some(_)) =>
      raise DateError::InvalidDate(message="use either tz or timezone")
    (_, Some(_)) => Captured
    (Some(name), None) => NamedTimezone(name)
    (None, None) => DefaultTimezone
  }
}

///|
fn timezone_digit(char : Int32) -> Bool {
  char >= 48 && char <= 57
}

///|
fn timezone_number(
  spec : String,
  start : Int32,
) -> (Int32, Int32) raise DateError {
  let mut index = start
  let mut value = 0
  while index < spec.length() && timezone_digit(spec[index].to_int()) {
    value = value * 10 + spec[index].to_int() - '0'.to_int()
    if value > 1000000 {
      raise DateError::InvalidDate(message="timezone number out of range")
    }
    index += 1
  }
  if index == start {
    raise DateError::InvalidDate(message="missing timezone number")
  }
  (value, index)
}

///|
fn timezone_abbreviation(spec : String, start : Int32) -> (String, Int32) {
  let mut index = start
  while index < spec.length() &&
        !timezone_digit(spec[index].to_int()) &&
        spec[index] != ':' &&
        spec[index] != ',' &&
        spec[index] != ';' &&
        spec[index] != '-' &&
        spec[index] != '+' {
    index += 1
  }
  (spec[start:index].to_owned(), index)
}

///|
// dateutil accepts H/HH, HHMM or H:MM offsets, but not offset seconds.
// Transition clocks (after '/') additionally accept seconds.
fn timezone_string_offset(
  spec : String,
  start : Int32,
) -> (Int32?, Int32) raise DateError {
  let mut index = start
  if index >= spec.length() ||
    (
      !timezone_digit(spec[index].to_int()) &&
      spec[index] != '+' &&
      spec[index] != '-'
    ) {
    return (None, index)
  }
  let mut sign = -1
  if spec[index] == '+' || spec[index] == '-' {
    if spec[index] == '-' {
      sign = 1
    }
    index += 1
  }
  let digits = index
  let (number, after) = timezone_number(spec, index)
  index = after
  let seconds = if index - digits == 4 {
    number / 100 * 3600 + number % 100 * 60
  } else if index < spec.length() && spec[index] == ':' {
    if number > 24 {
      raise DateError::InvalidDate(message="timezone offset out of range")
    }
    let (minute, after) = timezone_number(spec, index + 1)
    index = after
    number * 3600 + minute * 60
  } else if index - digits <= 2 {
    number * 3600
  } else {
    raise DateError::InvalidDate(message="invalid timezone offset")
  }
  (Some(sign * seconds), index)
}

///|
fn dateutil_posix_timezone(spec : String) -> DateTimeZone raise DateError {
  let (standard_name, index) = timezone_abbreviation(spec, 0)
  if standard_name == "" {
    raise DateError::InvalidDate(message="missing timezone name")
  }
  let (standard, index) = timezone_string_offset(spec, index)
  let mut standard = standard.unwrap_or(0)
  if standard_name == "GMT" || standard_name == "UTC" {
    standard = -standard
  }
  let (daylight_name, index) = timezone_abbreviation(spec, index)
  let (daylight, index) = timezone_string_offset(spec, index)
  if index < spec.length() && spec[index] != ',' && spec[index] != ';' {
    raise DateError::InvalidDate(message="invalid timezone string suffix")
  }
  let rules = normalize_dateutil_rules(
    spec[index:].to_owned().replace_all(old=";", new=","),
  )
  // Use the shared checked engine for GNU calendar rules, not its extra TZif
  // clock-basis suffixes or signed transition-time extensions.
  if rules
    .to_array()
    .any(char => {
      !(timezone_digit(char.to_int()) ||
      char == ',' ||
      char == 'M' ||
      char == 'J' ||
      char == '.' ||
      char == '/' ||
      char == ':' ||
      char == '-')
    }) {
    raise DateError::InvalidDate(
      message="unsupported timezone transition syntax",
    )
  }
  let synthetic = "STD0DST" + rules
  let context = DateParserContext::from_posix(synthetic)
  let template = match context.source {
    Posix(rule) => rule
    _ => abort("POSIX context invariant")
  }
  let has_dst = daylight_name != ""
  let daylight = if has_dst {
    Some(daylight.unwrap_or(standard + 3600))
  } else {
    None
  }
  validate_offset_seconds(standard)
  if daylight is Some(offset) {
    validate_offset_seconds(offset)
  }
  let rule : @tztypes.PosixTzRule = {
    std_abbr: standard_name,
    std_offset: standard,
    dst_abbr: if has_dst {
      Some(daylight_name)
    } else {
      None
    },
    dst_offset: daylight,
    start_rule: if has_dst {
      template.start_rule
    } else {
      None
    },
    end_rule: if has_dst {
      template.end_rule
    } else {
      None
    },
  }
  {
    initial_offset_seconds: standard,
    initial_abbreviation: Some(standard_name),
    transitions: [],
    footer: Some(rule),
    dateutil_footer: true,
    footer_start_seconds: None,
  }
}

///|
fn normalize_dateutil_rules(rules : String) -> String raise DateError {
  if rules == "" {
    return rules
  }
  let result : Array[String] = []
  for part in rules.split(",") {
    let pieces = part
      .to_owned()
      .split("/")
      .map(piece => piece.to_owned())
      .to_array()
    let date = if pieces[0].has_prefix("M") {
      pieces[0].replace_all(old="-", new=".")
    } else {
      pieces[0]
    }
    if pieces.length() == 1 {
      result.push(date)
      continue
    }
    if pieces.length() != 2 {
      raise DateError::InvalidDate(message="invalid timezone transition clock")
    }
    let clock = pieces[1]
    let (number, after) = timezone_number(clock, 0)
    let mut index = after
    let mut seconds = if after == 4 {
      number / 100 * 3600 + number % 100 * 60
    } else {
      if after > 2 && !(after < clock.length() && clock[after] == ':') {
        raise DateError::InvalidDate(
          message="invalid timezone transition clock",
        )
      }
      if number > 167 {
        raise DateError::InvalidDate(message="transition hour out of range")
      }
      number * 3600
    }
    if index < clock.length() && clock[index] == ':' {
      let (minutes, next) = timezone_number(clock, index + 1)
      seconds += minutes * 60
      index = next
      if index < clock.length() && clock[index] == ':' {
        let (fraction, next) = timezone_number(clock, index + 1)
        seconds += fraction
        index = next
      }
    }
    if index != clock.length() || seconds > 604799 {
      raise DateError::InvalidDate(message="invalid timezone transition clock")
    }
    result.push(
      date +
      "/" +
      (seconds / 3600).to_string() +
      ":" +
      (seconds / 60 % 60).to_string() +
      ":" +
      (seconds % 60).to_string(),
    )
  }
  result.join(",")
}
