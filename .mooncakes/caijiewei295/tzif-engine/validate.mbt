// Validation for publicly constructible TZif data values.

///|
fn invalid_data(message : String) -> @types.TzifResult[Unit] {
  Err(InvalidTransitionTable(message))
}

///|
fn validate_abbreviation(
  abbr : String,
  label : String,
) -> @types.TzifResult[Unit] {
  for index in 0..<abbr.length() {
    let code = abbr[index].to_int()
    if code < ' '.to_int() || code > '~'.to_int() {
      return invalid_data("\{label} must contain printable ASCII only")
    }
  }
  Ok(())
}

///|
fn validate_posix_abbreviation(
  abbr : String,
  label : String,
) -> @types.TzifResult[Unit] {
  if abbr.length() < 3 || abbr.length() > 255 {
    return invalid_data("\{label} length must be in 3..255 bytes")
  }
  for index in 0..<abbr.length() {
    let code = abbr[index].to_int()
    let is_letter = (code >= 'a'.to_int() && code <= 'z'.to_int()) ||
      (code >= 'A'.to_int() && code <= 'Z'.to_int())
    let is_digit = code >= '0'.to_int() && code <= '9'.to_int()
    if !is_letter && !is_digit && code != '+'.to_int() && code != '-'.to_int() {
      return invalid_data(
        "\{label} must contain only ASCII alphanumeric, '+' or '-'",
      )
    }
  }
  Ok(())
}

///|
fn validate_posix_date_rule(
  date_rule : @types.PosixDateRule,
) -> @types.TzifResult[Unit] {
  match date_rule {
    JulianNoLeap(day) =>
      if day < 1 || day > 365 {
        invalid_data("POSIX Julian date rule must be in 1..365")
      } else {
        Ok(())
      }
    DayOfYear(day) =>
      if day < 0 || day > 365 {
        invalid_data("POSIX day-of-year rule must be in 0..365")
      } else {
        Ok(())
      }
    MonthWeekDay(month, week, weekday) =>
      if month < 1 ||
        month > 12 ||
        week < 1 ||
        week > 5 ||
        weekday < 0 ||
        weekday > 6 {
        invalid_data("POSIX M rule contains an out-of-range calendar field")
      } else {
        Ok(())
      }
  }
}

///|
fn validate_posix_transition_rule(
  rule : @types.PosixTransitionRule,
  _version : Byte,
) -> @types.TzifResult[Unit] {
  match validate_posix_date_rule(rule.date_rule) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let maximum = 167 * 3600 + 59 * 60 + 59
  let minimum = -maximum
  if rule.time_of_day < minimum || rule.time_of_day > maximum {
    return invalid_data(
      "POSIX transition clock is outside this TZif version range",
    )
  }
  Ok(())
}

///|
fn validate_posix_rule(
  rule : @types.PosixTzRule,
  version : Byte,
) -> @types.TzifResult[Unit] {
  match
    validate_posix_abbreviation(rule.std_abbr, "POSIX standard abbreviation") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if rule.std_offset < -89_999 || rule.std_offset > 89_999 {
    return invalid_data("POSIX standard offset is outside the supported range")
  }
  match rule.dst_abbr {
    None =>
      if rule.dst_offset is Some(_) ||
        rule.start_rule is Some(_) ||
        rule.end_rule is Some(_) {
        return invalid_data("POSIX non-DST rule must not contain DST fields")
      }
    Some(dst_abbr) => {
      match
        validate_posix_abbreviation(dst_abbr, "POSIX daylight abbreviation") {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      let dst_offset = match rule.dst_offset {
        None =>
          return invalid_data("POSIX DST abbreviation requires a DST offset")
        Some(value) => value
      }
      if dst_offset < -89_999 || dst_offset > 89_999 {
        return invalid_data(
          "POSIX daylight offset is outside the supported range",
        )
      }
      let start_rule = match rule.start_rule {
        None =>
          return invalid_data("POSIX DST abbreviation requires a start rule")
        Some(value) => value
      }
      let end_rule = match rule.end_rule {
        None =>
          return invalid_data("POSIX DST abbreviation requires an end rule")
        Some(value) => value
      }
      match validate_posix_transition_rule(start_rule, version) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      match validate_posix_transition_rule(end_rule, version) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
    }
  }
  Ok(())
}

///|
fn leap_posix_boundary(occurrence : Int64, previous_correction : Int) -> Int64? {
  let correction = previous_correction.to_int64()
  if correction < 0L && occurrence > 9_223_372_036_854_775_807L + correction {
    return None
  }
  let boundary = occurrence - correction
  if boundary < 0L {
    None
  } else {
    Some(boundary)
  }
}

///|
fn is_utc_month_boundary(timestamp : Int64) -> Bool {
  if timestamp % 86_400L != 0L {
    return false
  }
  let days = timestamp / 86_400L
  let shifted = days + 719_468L
  let era = shifted / 146_097L
  let day_of_era = shifted - era * 146_097L
  let year_of_era = (
      day_of_era -
      day_of_era / 1_460L +
      day_of_era / 36_524L -
      day_of_era / 146_096L
    ) /
    365L
  let day_of_year = day_of_era -
    (365L * year_of_era + year_of_era / 4L - year_of_era / 100L)
  let month_prime = (5L * day_of_year + 2L) / 153L
  let day = day_of_year - (153L * month_prime + 2L) / 5L + 1L
  day == 1L
}

///|
fn validate_leap_seconds(
  leap_seconds : Array[@types.LeapSecond],
) -> @types.TzifResult[Unit] {
  let mut previous_occurrence = 0L
  let mut previous_correction = 0
  for index in 0..<leap_seconds.length() {
    let leap = leap_seconds[index]
    if index == 0 && leap.transition_time < 0L {
      return invalid_data("first leap-second occurrence must be nonnegative")
    }
    if index > 0 &&
      (
        leap.transition_time <= previous_occurrence ||
        leap.transition_time - previous_occurrence < 2_419_199L
      ) {
      return invalid_data(
        "adjacent leap-second occurrences must be at least 2419199 seconds apart",
      )
    }
    match leap_posix_boundary(leap.transition_time, previous_correction) {
      Some(boundary) =>
        if !is_utc_month_boundary(boundary) {
          return invalid_data(
            "leap-second occurrence must be at the end of a UTC month",
          )
        }
      None =>
        return invalid_data(
          "leap-second occurrence cannot be represented as a POSIX UTC boundary",
        )
    }
    if index == 0 && leap.correction != 1 && leap.correction != -1 {
      return invalid_data("first leap-second correction must be either 1 or -1")
    }
    if index > 0 {
      let correction_delta = leap.correction.to_int64() -
        previous_correction.to_int64()
      if correction_delta != 1L && correction_delta != -1L {
        return invalid_data(
          "adjacent leap-second corrections must differ by exactly 1",
        )
      }
    }
    previous_occurrence = leap.transition_time
    previous_correction = leap.correction
  }
  Ok(())
}

///|
fn validate_indicators(tz : @types.TzifData) -> @types.TzifResult[Unit] {
  match tz.standard_indicators {
    None => ()
    Some(values) =>
      if values.length() != tz.time_types.length() {
        return invalid_data(
          "ttisstd indicator count must equal time type count",
        )
      }
  }
  match tz.utc_indicators {
    None => ()
    Some(values) =>
      if values.length() != tz.time_types.length() {
        return invalid_data("ttisut indicator count must equal time type count")
      }
  }
  match tz.utc_indicators {
    None => ()
    Some(utc_values) =>
      for index in 0..<utc_values.length() {
        if utc_values[index] {
          match tz.standard_indicators {
            Some(standard_values) =>
              if !standard_values[index] {
                return invalid_data(
                  "ttisut=1 requires the corresponding ttisstd indicator to be 1",
                )
              }
            None =>
              return invalid_data(
                "ttisut=1 requires an explicit corresponding ttisstd=1 indicator",
              )
          }
        }
      }
  }
  Ok(())
}

///|
fn validate_footer_consistency(tz : @types.TzifData) -> @types.TzifResult[Unit] {
  if tz.transitions.length() == 0 || tz.posix_rule is None {
    return Ok(())
  }
  let last_transition = tz.transitions[tz.transitions.length() - 1]
  let explicit_type = tz.time_types[last_transition.type_index]
  let footer_type = match
    @converter.active_offset(tz, last_transition.utc_time) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if footer_type.utoff != explicit_type.utoff ||
    footer_type.is_dst != explicit_type.is_dst ||
    footer_type.abbr != explicit_type.abbr {
    return invalid_data(
      "POSIX footer is inconsistent with the final explicit transition type",
    )
  }
  Ok(())
}

///|
/// Validate a user-constructed `TzifData` before caching, serializing, or
/// passing it across a trust boundary.
///
/// `load` already applies equivalent structural checks to file input.  This
/// function exists because every field of `TzifData` is intentionally public
/// for inspection and fixture construction, so callers can also create an
/// invalid in-memory value without parsing bytes first.
pub fn validate(tz : @types.TzifData) -> @types.TzifResult[Unit] {
  if tz.version != b'2' && tz.version != b'3' {
    return Err(UnsupportedVersion(tz.version))
  }
  if tz.time_types.length() == 0 {
    return invalid_data("TZif must contain at least one local time type")
  }
  if tz.transitions.length() > 1_000_000 {
    return Err(
      ResourceLimitExceeded(
        "TZif transition count exceeds the default limit of 1000000",
      ),
    )
  }
  if tz.time_types.length() > 256 {
    return Err(
      ResourceLimitExceeded(
        "TZif time type count exceeds the default limit of 256",
      ),
    )
  }
  if tz.leap_seconds.length() > 10_000 {
    return Err(
      ResourceLimitExceeded(
        "TZif leap-second count exceeds the default limit of 10000",
      ),
    )
  }
  let mut designation_bytes = 0
  for index in 0..<tz.time_types.length() {
    let time_type = tz.time_types[index]
    if time_type.utoff == -2_147_483_647 - 1 {
      return invalid_data(
        "time type offset at index \{index} must not be -2147483648",
      )
    }
    if designation_bytes > 1_048_576 - time_type.abbr.length() - 1 {
      return Err(
        ResourceLimitExceeded(
          "TZif designation data exceeds the default limit of 1048576 bytes",
        ),
      )
    }
    designation_bytes = designation_bytes + time_type.abbr.length() + 1
    match validate_abbreviation(time_type.abbr, "time type abbreviation") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  let mut previous_transition = 0L
  for index in 0..<tz.transitions.length() {
    let transition = tz.transitions[index]
    if index > 0 && transition.utc_time <= previous_transition {
      return invalid_data("transition times must be strictly increasing")
    }
    if transition.type_index < 0 ||
      transition.type_index >= tz.time_types.length() {
      return invalid_data(
        "transition type index \{transition.type_index} is out of range",
      )
    }
    previous_transition = transition.utc_time
  }
  match validate_leap_seconds(tz.leap_seconds) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match validate_indicators(tz) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match tz.posix_rule {
    None => ()
    Some(rule) =>
      match validate_posix_rule(rule, tz.version) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
  }
  validate_footer_consistency(tz)
}
