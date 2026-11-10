///|
/// Load caller-supplied IANA TZif v2/v3 bytes, retaining historical seconds,
/// designations and POSIX footer rules. The library does not search a system
/// database. TZif v1/v4, leap-second tables and offsets outside one day raise
/// `DateError`. With an empty footer, the final explicit type is retained.
fn date_tzif_data(data : Bytes) -> @tztypes.TzifData raise DateError {
  let parsed = match @tzif.load(data) {
    Ok(value) => value
    Err(_) =>
      raise DateError::InvalidDate(
        message="invalid or unsupported TZif v2/v3 data",
      )
  }
  if !parsed.leap_seconds.is_empty() {
    raise DateError::InvalidDate(
      message="TZif leap-second tables are unsupported for POSIX date ordinals",
    )
  }
  for time_type in parsed.time_types {
    validate_offset_seconds(time_type.utoff)
  }
  match parsed.posix_rule {
    Some(rule) => {
      validate_offset_seconds(rule.std_offset)
      match rule.dst_offset {
        Some(offset) => validate_offset_seconds(offset)
        None => ()
      }
    }
    None => ()
  }
  parsed
}

///|
/// Load caller-supplied TZif v2/v3 data into a transition-aware date zone.
pub fn tzif_timezone(data : Bytes) -> DateTimeZone raise DateError {
  let parsed = date_tzif_data(data)
  let mut initial_offset_seconds = parsed.time_types[0].utoff
  let mut initial_abbreviation = Some(parsed.time_types[0].abbr)
  let transitions : Array[TimeZoneTransition] = []
  for transition in parsed.transitions {
    let time_type = parsed.time_types[transition.type_index]
    // Discard out-of-calendar entries without losing the type active at year 1.
    if transition.utc_time < -62_135_596_800L {
      initial_offset_seconds = time_type.utoff
      initial_abbreviation = Some(time_type.abbr)
    } else if transition.utc_time < 253_402_300_800L {
      transitions.push({
        at_microseconds: transition.utc_time * 1_000_000L,
        offset_seconds: time_type.utoff,
        abbreviation: Some(time_type.abbr),
      })
    }
  }
  {
    initial_offset_seconds,
    initial_abbreviation,
    transitions,
    footer: parsed.posix_rule,
    dateutil_footer: false,
    footer_start_seconds: if parsed.transitions.is_empty() {
      None
    } else {
      Some(parsed.transitions[parsed.transitions.length() - 1].utc_time)
    },
  }
}
