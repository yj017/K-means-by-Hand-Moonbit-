// ISO-8601 offset timestamp regression tests, including historical seconds.

///|
fn offset_timestamp_ok(input : String) -> @types.OffsetDateTime raise {
  match @tzif.parse_iso_offset(input) {
    Ok(value) => value
    Err(_) => fail("expected ISO-8601 offset timestamp to parse")
  }
}

///|
fn assert_offset_timestamp_error(input : String) -> Unit raise {
  match @tzif.parse_iso_offset(input) {
    Err(InvalidIso8601(_)) => ()
    Err(_) => fail("expected InvalidIso8601")
    Ok(_) => fail("expected ISO-8601 offset timestamp to fail")
  }
}

///|
test "offset parser accepts UTC minute offset and historical second offset" {
  let utc = offset_timestamp_ok("2026-01-01T00:00:00Z")
  assert_eq(utc.utc_time, 1_767_225_600L)
  assert_eq(utc.offset, 0)

  let india = offset_timestamp_ok("2026-01-01T05:30:00+05:30")
  assert_eq(india.utc_time, 1_767_225_600L)
  assert_eq(india.offset, 19_800)
  assert_eq(india.local_time.utoff, 19_800)

  let historical = offset_timestamp_ok("1970-01-01T00:19:32+00:19:32")
  assert_eq(historical.utc_time, 0L)
  assert_eq(historical.offset, 1172)
}

///|
test "offset formatting retains seconds only where they are meaningful" {
  match @tzif.format_iso_offset(0L, 19_800) {
    Ok(text) => assert_eq(text, "1970-01-01T05:30:00+05:30")
    Err(_) => fail("expected minute ISO offset formatting")
  }
  match @tzif.format_iso_offset(0L, 1172) {
    Ok(text) => assert_eq(text, "1970-01-01T00:19:32+00:19:32")
    Err(_) => fail("expected second ISO offset formatting")
  }
  let historical_local = @types.LocalDateTime::{
    year: 1970,
    month: 1,
    day: 1,
    hour: 0,
    minute: 19,
    second: 32,
    utoff: 1172,
    is_dst: false,
    abbr: "LMT",
  }
  assert_eq(
    format_iso_zoned_ok(historical_local),
    "1970-01-01T00:19:32+00:19:32",
  )
}

///|
test "UTC parser accepts only canonical Z form" {
  match @tzif.parse_iso_utc("2026-01-01T00:00:00Z") {
    Ok(value) => assert_eq(value, 1_767_225_600L)
    Err(_) => fail("expected canonical UTC ISO timestamp")
  }
  for
    input in [
      "2026-01-01T00:00:00+00:00", "2026-01-01T00:00:00z", "2026-01-01T00:00:00",
    ] {
    match @tzif.parse_iso_utc(input) {
      Err(InvalidIso8601(_)) => ()
      _ => fail("expected non-Z UTC form to be rejected")
    }
  }
}

///|
test "offset parser rejects malformed suffixes and range violations" {
  for
    input in [
      "2026-01-01T00:00:00+05", "2026-01-01T00:00:00+05-30", "2026-01-01T00:00:00+26:00",
      "2026-01-01T00:00:00-25:00", "2026-01-01T00:00:00+00:60", "2026-01-01T00:00:00+00:00:60",
      "2026-01-01T00:00:00+05:30extra", "2026-01-01T00:00:00ZZ",
    ] {
    assert_offset_timestamp_error(input)
  }
}

///|
test "offset parser and formatter preserve the full TZif offset range" {
  let maximum = offset_timestamp_ok("2026-01-02T01:59:59+25:59:59")
  assert_eq(maximum.utc_time, 1_767_225_600L)
  assert_eq(maximum.offset, 93_599)
  let minimum = offset_timestamp_ok("2025-12-30T23:00:01-24:59:59")
  assert_eq(minimum.utc_time, 1_767_225_600L)
  assert_eq(minimum.offset, -89_999)

  match @tzif.format_numeric_offset(93_599) {
    Ok(value) => assert_eq(value, "+25:59:59")
    Err(_) => fail("expected maximum TZif offset to format")
  }
  match @tzif.format_numeric_offset(-89_999) {
    Ok(value) => assert_eq(value, "-24:59:59")
    Err(_) => fail("expected minimum TZif offset to format")
  }
  for offset in [93_600, -90_000] {
    match @tzif.format_numeric_offset(offset) {
      Err(TimestampOutOfRange(value)) => assert_eq(value, offset.to_int64())
      _ => fail("expected numeric offset range error")
    }
  }
}

///|
test "offset formatter reports arithmetic overflow without wrapping" {
  for
    pair in [(9_223_372_036_854_775_807L, 1), (-9_223_372_036_854_775_808L, -1)] {
    match @tzif.format_iso_offset(pair.0, pair.1) {
      Err(TimestampOutOfRange(value)) => assert_eq(value, pair.0)
      _ => fail("expected offset formatting range error")
    }
  }
}
