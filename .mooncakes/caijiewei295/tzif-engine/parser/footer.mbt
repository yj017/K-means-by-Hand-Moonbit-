// POSIX TZ footer parser (RFC 9636 section 3.3).

///|
let char_a : Int = 97

///|
let char_z : Int = 122

///|
let char_A : Int = 65

///|
let char_Z : Int = 90

///|
let char_0 : Int = 48

///|
let char_9 : Int = 57

///|
let char_lt : Int = 60

///|
let char_gt : Int = 62

///|
let char_minus : Int = 45

///|
let char_plus : Int = 43

///|
let char_dot : Int = 46

///|
let char_slash : Int = 47

///|
let char_comma : Int = 44

///|
let char_colon : Int = 58

///|
let char_J : Int = 74

///|
let char_M : Int = 77

///|
let char_w : Int = 119

///|
let char_s : Int = 115

///|
let char_u : Int = 117

///|
let char_g : Int = 103

///|
let char_zed : Int = 122

///|
/// POSIX leaves TZNAME_MAX implementation-defined. The parser accepts names
/// up to this generous bounded-reader limit.
let max_posix_abbreviation_length : Int = 255

///|
fn char_code(string : String, index : Int) -> Int {
  string[index].to_int()
}

///|
fn is_ascii_letter(code : Int) -> Bool {
  (code >= char_a && code <= char_z) || (code >= char_A && code <= char_Z)
}

///|
fn is_digit(code : Int) -> Bool {
  code >= char_0 && code <= char_9
}

///|
fn is_quoted_abbreviation_char(code : Int) -> Bool {
  is_ascii_letter(code) ||
  is_digit(code) ||
  code == char_plus ||
  code == char_minus
}

///|
fn parse_uint(
  string : String,
  position : Int,
  maximum : Int,
  label : String,
) -> @types.TzifResult[(Int, Int)] {
  let length = string.length()
  if position >= length || !is_digit(char_code(string, position)) {
    return Err(
      PosixParseError("expected decimal \{label} at position \{position}"),
    )
  }
  let mut value = 0
  let mut next = position
  while next < length && is_digit(char_code(string, next)) {
    let digit = char_code(string, next) - char_0
    if value > maximum / 10 || (value == maximum / 10 && digit > maximum % 10) {
      return Err(PosixParseError("POSIX \{label} exceeds its allowed range"))
    }
    value = value * 10 + digit
    next = next + 1
  }
  Ok((value, next))
}

///|
fn parse_abbreviation(
  string : String,
  position : Int,
) -> @types.TzifResult[(String, Int)] {
  let length = string.length()
  if position >= length {
    return Err(PosixParseError("expected POSIX time-zone abbreviation"))
  }
  if char_code(string, position) == char_lt {
    let start = position + 1
    let mut end = start
    while end < length && char_code(string, end) != char_gt {
      let code = char_code(string, end)
      if !is_quoted_abbreviation_char(code) {
        return Err(
          PosixParseError(
            "quoted POSIX abbreviation must contain only ASCII alphanumeric, '+' or '-'",
          ),
        )
      }
      end = end + 1
    }
    if end == length {
      return Err(PosixParseError("quoted POSIX abbreviation must be closed"))
    }
    let abbreviation_length = end - start
    if abbreviation_length < 3 ||
      abbreviation_length > max_posix_abbreviation_length {
      return Err(
        PosixParseError(
          "quoted POSIX abbreviation length must be in 3..255 bytes",
        ),
      )
    }
    return Ok((string[start:end].to_owned(), end + 1))
  }

  if !is_ascii_letter(char_code(string, position)) {
    return Err(
      PosixParseError(
        "expected POSIX time-zone abbreviation at position \{position}",
      ),
    )
  }
  let start = position
  let mut end = start
  while end < length && is_ascii_letter(char_code(string, end)) {
    end = end + 1
  }
  if end - start < 3 || end - start > max_posix_abbreviation_length {
    return Err(
      PosixParseError(
        "unquoted POSIX abbreviation length must be in 3..255 letters",
      ),
    )
  }
  Ok((string[start:end].to_owned(), end))
}

///|
fn parse_clock(
  string : String,
  position : Int,
  allow_sign : Bool,
  max_hour : Int,
  label : String,
) -> @types.TzifResult[(Int, Int)] {
  let length = string.length()
  let mut next = position
  let mut sign = 1
  if next < length {
    let code = char_code(string, next)
    if code == char_minus || code == char_plus {
      if !allow_sign {
        return Err(PosixParseError("signed POSIX \{label} requires TZif v3"))
      }
      sign = if code == char_minus { -1 } else { 1 }
      next = next + 1
    }
  }

  let (hour, after_hour) = match parse_uint(string, next, max_hour, label) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  next = after_hour
  let mut minute = 0
  let mut second = 0
  if next < length && char_code(string, next) == char_colon {
    let parsed = match parse_uint(string, next + 1, 59, "minute") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    minute = parsed.0
    next = parsed.1
    if next < length && char_code(string, next) == char_colon {
      let parsed = match parse_uint(string, next + 1, 59, "second") {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      second = parsed.0
      next = parsed.1
    }
  }
  Ok((sign * (hour * 3600 + minute * 60 + second), next))
}

///|
fn parse_offset(
  string : String,
  position : Int,
) -> @types.TzifResult[(Int, Int)] {
  let length = string.length()
  let mut next = position
  let mut sign = 1
  if next < length {
    let code = char_code(string, next)
    if code == char_minus || code == char_plus {
      sign = if code == char_minus { -1 } else { 1 }
      next = next + 1
    }
  }
  let (seconds, next) = match
    parse_clock(string, next, false, 24, "UTC offset hour") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok((sign * seconds, next))
}

///|
fn parse_transition_time(
  string : String,
  position : Int,
) -> @types.TzifResult[(Int, @types.PosixTimeBasis, Int)] {
  // This project deliberately keeps tzcode-reader compatibility for v2
  // footer strings that use signed/out-of-POSIX-range hours and clock-basis
  // suffixes. That acceptance is compatibility behavior, not RFC 9636 v2
  // conformance; dedicated tests name the distinction explicitly.
  let (seconds, parsed_next) = match
    parse_clock(string, position, true, 167, "transition hour") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut next = parsed_next
  let mut basis = @types.PosixTimeBasis::Wall
  if next < string.length() {
    let code = char_code(string, next)
    if code == char_w {
      basis = Wall
      next = next + 1
    } else if code == char_s {
      basis = Standard
      next = next + 1
    } else if code == char_u || code == char_g || code == char_zed {
      basis = Utc
      next = next + 1
    }
  }
  Ok((seconds, basis, next))
}

///|
fn parse_transition_rule(
  string : String,
  position : Int,
) -> @types.TzifResult[(@types.PosixTransitionRule, Int)] {
  if position >= string.length() {
    return Err(PosixParseError("expected POSIX transition date rule"))
  }
  let prefix = char_code(string, position)
  let (date_rule, parsed_next) = if prefix == char_J {
    let (day, after_day) = match
      parse_uint(string, position + 1, 365, "Julian day") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if day == 0 {
      return Err(PosixParseError("POSIX Julian day must be in 1..365"))
    }
    (@types.PosixDateRule::JulianNoLeap(day), after_day)
  } else if prefix == char_M {
    let (month, after_month) = match
      parse_uint(string, position + 1, 12, "month") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if month == 0 ||
      after_month >= string.length() ||
      char_code(string, after_month) != char_dot {
      return Err(
        PosixParseError(
          "POSIX M rule requires a month in 1..12 followed by '.'",
        ),
      )
    }
    let (week, after_week) = match
      parse_uint(string, after_month + 1, 5, "week") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if week == 0 ||
      after_week >= string.length() ||
      char_code(string, after_week) != char_dot {
      return Err(
        PosixParseError("POSIX M rule requires a week in 1..5 followed by '.'"),
      )
    }
    let (weekday, after_weekday) = match
      parse_uint(string, after_week + 1, 6, "weekday") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    (MonthWeekDay(month, week, weekday), after_weekday)
  } else {
    let (day, after_day) = match
      parse_uint(string, position, 365, "day of year") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    (DayOfYear(day), after_day)
  }

  let mut next = parsed_next
  let mut time_of_day = 7200
  let mut time_basis = @types.PosixTimeBasis::Wall
  if next < string.length() && char_code(string, next) == char_slash {
    let parsed = match parse_transition_time(string, next + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    time_of_day = parsed.0
    time_basis = parsed.1
    next = parsed.2
  }
  Ok(({ date_rule, time_of_day, time_basis }, next))
}

///|
fn default_start_rule() -> @types.PosixTransitionRule {
  { date_rule: MonthWeekDay(4, 1, 0), time_of_day: 7200, time_basis: Wall }
}

///|
fn default_end_rule() -> @types.PosixTransitionRule {
  { date_rule: MonthWeekDay(10, 5, 0), time_of_day: 7200, time_basis: Wall }
}

///|
fn parse_posix_tz(string : String) -> @types.TzifResult[@types.PosixTzRule] {
  let length = string.length()
  if length == 0 {
    return Err(PosixParseError("empty POSIX TZ string"))
  }
  let (std_abbr, after_std_abbr) = match parse_abbreviation(string, 0) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (std_posix_offset, parsed_next) = match
    parse_offset(string, after_std_abbr) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut next = parsed_next
  // POSIX offsets have the opposite sign of TZif's UTC offsets.
  let std_offset = -std_posix_offset
  let mut dst_abbr : String? = None
  let mut dst_offset : Int? = None
  let mut start_rule : @types.PosixTransitionRule? = None
  let mut end_rule : @types.PosixTransitionRule? = None

  if next < length &&
    (
      is_ascii_letter(char_code(string, next)) ||
      char_code(string, next) == char_lt
    ) {
    let parsed = match parse_abbreviation(string, next) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let dst = parsed.0
    next = parsed.1
    dst_abbr = Some(dst)
    let effective_dst_offset = if next < length &&
      (
        is_digit(char_code(string, next)) ||
        char_code(string, next) == char_minus ||
        char_code(string, next) == char_plus
      ) {
      let (offset, after_offset) = match parse_offset(string, next) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      next = after_offset
      -offset
    } else {
      std_offset + 3600
    }
    dst_offset = Some(effective_dst_offset)

    if next < length && char_code(string, next) == char_comma {
      let first = match parse_transition_rule(string, next + 1) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      next = first.1
      if next >= length || char_code(string, next) != char_comma {
        return Err(
          PosixParseError(
            "POSIX DST rules require both start and end transition dates",
          ),
        )
      }
      let second = match parse_transition_rule(string, next + 1) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      start_rule = Some(first.0)
      end_rule = Some(second.0)
      next = second.1
    } else {
      // POSIX specifies these historical US rules when a DST abbreviation is
      // present but the two transition rules are omitted.
      start_rule = Some(default_start_rule())
      end_rule = Some(default_end_rule())
    }
  } else if next < length && char_code(string, next) == char_comma {
    return Err(
      PosixParseError("POSIX transition rules require a DST abbreviation"),
    )
  }

  if next != length {
    return Err(
      PosixParseError("unexpected trailing POSIX TZ data at position \{next}"),
    )
  }
  Ok({ std_abbr, std_offset, dst_abbr, dst_offset, start_rule, end_rule })
}

///|
/// Parse the newline-framed POSIX footer following the second TZif data
/// block.  `offset` must be exactly that block's end; the footer is mandatory
/// for TZif v2/v3, although its TZ string may be empty.
pub fn parse_footer(
  data : Bytes,
  offset~ : Int,
  version~ : Byte,
) -> @types.TzifResult[@types.PosixTzRule?] {
  if version != b'2' && version != b'3' {
    return Err(UnsupportedVersion(version))
  }
  match validate_input_size(data) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let length = data.length()
  if offset < 0 || offset >= length || data[offset] != b'\n' {
    return Err(
      InvalidTransitionTable(
        "TZif footer must begin with a newline immediately after the second data block",
      ),
    )
  }
  if length - offset < 2 || data[length - 1] != b'\n' {
    return Err(
      InvalidTransitionTable(
        "TZif footer must end with its framing newline at end of file",
      ),
    )
  }
  let start = offset + 1
  let end = length - 1
  for index in start..<end {
    let byte = data[index]
    if byte < b'!' || byte > b'~' {
      return Err(
        InvalidTransitionTable(
          "TZif footer must contain only printable ASCII and no embedded newlines",
        ),
      )
    }
  }
  if start == end {
    return Ok(None)
  }
  // Bounds and printable ASCII have been checked, so this decode cannot
  // cross the footer frame or replace malformed UTF-8.
  let footer = @utf8.decode_lossy(data[start:end])
  match parse_posix_tz(footer) {
    Ok(rule) => Ok(Some(rule))
    Err(error) => Err(error)
  }
}
