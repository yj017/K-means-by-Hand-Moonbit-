// Strict, allocation-light ISO-8601 adapters for public local-time APIs.

///|
let minimum_numeric_offset : Int = -89_999

///|
let maximum_numeric_offset : Int = 93_599

///|
fn invalid_iso(message : String) -> @types.TzifResult[Int] {
  Err(InvalidIso8601(message))
}

///|
fn parse_decimal(
  input : String,
  start : Int,
  width : Int,
  field : String,
) -> @types.TzifResult[Int] {
  let end = start + width
  if start < 0 || width <= 0 || end > input.length() {
    return invalid_iso("missing ISO-8601 \{field} field")
  }
  let mut value = 0
  for index in start..<end {
    let code = input[index].to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return invalid_iso("ISO-8601 \{field} must contain decimal digits")
    }
    value = value * 10 + code - '0'.to_int()
  }
  Ok(value)
}

///|
fn expect_separator(
  input : String,
  index : Int,
  expected : Int,
) -> @types.TzifResult[Unit] {
  if index >= input.length() || input[index].to_int() != expected {
    Err(
      InvalidIso8601(
        "ISO-8601 timestamp has an invalid separator at position \{index}",
      ),
    )
  } else {
    Ok(())
  }
}

///|
/// Parse the numeric suffix of an ISO-8601 offset timestamp.  The canonical
/// zero-offset spelling is `Z`; numeric offsets accept `+HH:MM` and the
/// seconds-preserving `+HH:MM:SS` form needed by historical TZif data.
fn parse_offset_suffix(input : String, start : Int) -> @types.TzifResult[Int] {
  if start >= input.length() {
    return Err(InvalidIso8601("missing ISO-8601 UTC offset"))
  }
  if input[start].to_int() == 'Z'.to_int() && start + 1 == input.length() {
    return Ok(0)
  }
  let code = input[start].to_int()
  if code != '+'.to_int() && code != '-'.to_int() {
    return Err(InvalidIso8601("ISO-8601 UTC offset must begin with Z, +, or -"))
  }
  let suffix_length = input.length() - start
  if suffix_length != 6 && suffix_length != 9 {
    return Err(
      InvalidIso8601("ISO-8601 UTC offset must use +HH:MM or +HH:MM:SS"),
    )
  }
  match expect_separator(input, start + 3, ':'.to_int()) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  if suffix_length == 9 {
    match expect_separator(input, start + 6, ':'.to_int()) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  let hour = match parse_decimal(input, start + 1, 2, "offset hour") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let minute = match parse_decimal(input, start + 4, 2, "offset minute") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let second = if suffix_length == 9 {
    match parse_decimal(input, start + 7, 2, "offset second") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  } else {
    0
  }
  if hour > 25 || minute > 59 || second > 59 {
    return Err(InvalidIso8601("numeric UTC offset field is out of range"))
  }
  let total = hour * 3600 + minute * 60 + second
  let offset = if code == '-'.to_int() { -total } else { total }
  if offset < minimum_numeric_offset || offset > maximum_numeric_offset {
    Err(
      InvalidIso8601(
        "numeric UTC offset is outside the supported TZif range -24:59:59..+25:59:59",
      ),
    )
  } else {
    Ok(offset)
  }
}

///|
/// Parse a strict local civil timestamp in `YYYY-MM-DDTHH:MM:SS` form.
///
/// The text deliberately has no numeric UTC offset: it identifies wall time
/// which must be resolved with `local_to_utc` and an explicit timezone. The
/// returned offset metadata is intentionally neutral (`utoff = 0`, no DST,
/// empty abbreviation) because this function represents wall time only.
pub fn parse_iso_local(
  input : String,
) -> @types.TzifResult[@types.LocalDateTime] {
  if input.length() != 19 {
    return Err(InvalidIso8601("expected YYYY-MM-DDTHH:MM:SS"))
  }
  for
    pair in [
      (4, '-'.to_int()),
      (7, '-'.to_int()),
      (10, 'T'.to_int()),
      (13, ':'.to_int()),
      (16, ':'.to_int()),
    ] {
    let position = pair.0
    let expected = pair.1
    match expect_separator(input, position, expected) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  let year = match parse_decimal(input, 0, 4, "year") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let month = match parse_decimal(input, 5, 2, "month") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let day = match parse_decimal(input, 8, 2, "day") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let hour = match parse_decimal(input, 11, 2, "hour") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let minute = match parse_decimal(input, 14, 2, "minute") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let second = match parse_decimal(input, 17, 2, "second") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !@posix.is_valid_date(year, month, day) {
    return Err(
      InvalidIso8601(
        "ISO-8601 date is outside the proleptic Gregorian calendar",
      ),
    )
  }
  if !@posix.is_valid_civil_time(hour, minute, second) {
    return Err(
      InvalidIso8601("ISO-8601 time must use hour 00..23 and second 00..59"),
    )
  }
  Ok({
    year,
    month,
    day,
    hour,
    minute,
    second,
    utoff: 0,
    is_dst: false,
    abbr: "",
  })
}

///|
/// Parse an ISO-8601 timestamp with a numeric UTC offset.
///
/// Accepted forms are `YYYY-MM-DDTHH:MM:SSZ`, `...+HH:MM`, and
/// `...+HH:MM:SS` (with either numeric sign).  The latter retains second-level
/// offsets used by several historical IANA zones.
pub fn parse_iso_offset(
  input : String,
) -> @types.TzifResult[@types.OffsetDateTime] {
  if input.length() < 20 {
    return Err(
      InvalidIso8601(
        "ISO-8601 offset timestamp is shorter than a local timestamp plus Z",
      ),
    )
  }
  let civil_time = match parse_iso_local(input[0:19].to_owned()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let offset = match parse_offset_suffix(input, 19) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let local_epoch = match
    @posix.compose_epoch(
      civil_time.year,
      civil_time.month,
      civil_time.day,
      civil_time.hour,
      civil_time.minute,
      civil_time.second,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let utc_time = match
    @posix.checked_sub_epoch_seconds(local_epoch, offset.to_int64()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let local_time = @types.LocalDateTime::{
    year: civil_time.year,
    month: civil_time.month,
    day: civil_time.day,
    hour: civil_time.hour,
    minute: civil_time.minute,
    second: civil_time.second,
    utoff: offset,
    is_dst: false,
    abbr: "",
  }
  Ok({ local_time, utc_time, offset })
}

///|
/// Parse exactly the UTC `YYYY-MM-DDTHH:MM:SSZ` ISO-8601 form into POSIX
/// seconds.  Use `parse_iso_offset` when an explicit non-zero offset is also
/// acceptable.
pub fn parse_iso_utc(input : String) -> @types.TzifResult[Int64] {
  if input.length() != 20 || input[19].to_int() != 'Z'.to_int() {
    return Err(
      InvalidIso8601("expected UTC ISO-8601 form YYYY-MM-DDTHH:MM:SSZ"),
    )
  }
  match parse_iso_offset(input) {
    Ok(value) => Ok(value.utc_time)
    Err(error) => Err(error)
  }
}

///|
fn pad_unsigned(value : Int, width : Int) -> String {
  let text = value.to_string()
  let mut prefix = ""
  for _ in text.length()..<width {
    prefix = prefix + "0"
  }
  prefix + text
}

///|
/// Format a numeric ISO-8601 offset.  Seconds are emitted only when non-zero,
/// preserving minute-oriented modern offsets while remaining lossless for
/// historical offsets such as `+00:19:32`.
fn format_offset_suffix(offset : Int) -> String {
  let sign = if offset >= 0 { "+" } else { "-" }
  let absolute_offset = if offset >= 0 { offset } else { -offset }
  let hour = absolute_offset / 3600
  let minute = absolute_offset % 3600 / 60
  let second = absolute_offset % 60
  let base = sign + pad_unsigned(hour, 2) + ":" + pad_unsigned(minute, 2)
  if second == 0 {
    base
  } else {
    base + ":" + pad_unsigned(second, 2)
  }
}

///|
/// Format a numeric offset without losing historical second precision.
///
/// The supported range follows the interoperable TZif recommendation:
/// `-24:59:59..+25:59:59`.
pub fn format_numeric_offset(offset : Int) -> @types.TzifResult[String] {
  if offset < minimum_numeric_offset || offset > maximum_numeric_offset {
    Err(TimestampOutOfRange(offset.to_int64()))
  } else {
    Ok(format_offset_suffix(offset))
  }
}

///|
/// Format only the civil fields of a local date-time as ISO-8601.
///
/// This adapter intentionally supports the four-digit year domain 0000..9999.
pub fn format_iso_local(
  local_time : @types.LocalDateTime,
) -> @types.TzifResult[String] {
  if local_time.year < 0 || local_time.year > 9999 {
    return Err(InvalidIso8601("ISO-8601 formatter year must be in 0000..9999"))
  }
  if !@posix.is_valid_date(local_time.year, local_time.month, local_time.day) ||
    !@posix.is_valid_civil_time(
      local_time.hour,
      local_time.minute,
      local_time.second,
    ) {
    return Err(
      InvalidIso8601("ISO-8601 formatter received invalid civil fields"),
    )
  }
  Ok(
    "\{pad_unsigned(local_time.year, 4)}-\{pad_unsigned(local_time.month, 2)}-\{pad_unsigned(local_time.day, 2)}T\{pad_unsigned(local_time.hour, 2)}:\{pad_unsigned(local_time.minute, 2)}:\{pad_unsigned(local_time.second, 2)}",
  )
}

///|
/// Format a resolved local time with its numeric UTC offset in ISO-8601 form.
pub fn format_iso_zoned(
  local_time : @types.LocalDateTime,
) -> @types.TzifResult[String] {
  let civil = match format_iso_local(local_time) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let suffix = match format_numeric_offset(local_time.utoff) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(civil + suffix)
}

///|
/// Format a UTC instant at an explicit numeric offset.
///
/// This is useful when displaying data not associated with a named timezone.
/// The supported offset range is the interoperable TZif recommendation
/// `-24:59:59..+25:59:59`. The result uses seconds only when needed.
pub fn format_iso_offset(
  utc_time : Int64,
  offset : Int,
) -> @types.TzifResult[String] {
  let suffix = match format_numeric_offset(offset) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let local_epoch = match
    @posix.checked_add_epoch_seconds(utc_time, offset.to_int64()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (year, month, day, hour, minute, second) = match
    @posix.decompose_epoch(local_epoch) {
    Ok(value) => value
    Err(_) => return Err(TimestampOutOfRange(utc_time))
  }
  if year < 0 || year > 9999 {
    return Err(TimestampOutOfRange(utc_time))
  }
  let local_time = @types.LocalDateTime::{
    year,
    month,
    day,
    hour,
    minute,
    second,
    utoff: offset,
    is_dst: false,
    abbr: "",
  }
  let civil = match format_iso_local(local_time) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(civil + suffix)
}

///|
/// Format a POSIX UTC timestamp as `YYYY-MM-DDTHH:MM:SSZ`.
///
/// Timestamps outside the four-digit year domain return a checked range error.
pub fn format_iso_utc(utc_time : Int64) -> @types.TzifResult[String] {
  let (year, month, day, hour, minute, second) = match
    @posix.decompose_epoch(utc_time) {
    Ok(value) => value
    Err(_) => return Err(TimestampOutOfRange(utc_time))
  }
  if year < 0 || year > 9999 {
    return Err(TimestampOutOfRange(utc_time))
  }
  Ok(
    "\{pad_unsigned(year, 4)}-\{pad_unsigned(month, 2)}-\{pad_unsigned(day, 2)}T\{pad_unsigned(hour, 2)}:\{pad_unsigned(minute, 2)}:\{pad_unsigned(second, 2)}Z",
  )
}
