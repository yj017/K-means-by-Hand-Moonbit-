// Public ISO-8601 text adapter tests.

///|
fn parse_iso_ok(input : String) -> @types.LocalDateTime raise {
  match @tzif.parse_iso_local(input) {
    Ok(value) => value
    Err(_) => fail("expected ISO-8601 local timestamp to parse")
  }
}

///|
fn assert_iso_error(input : String) -> Unit raise {
  match @tzif.parse_iso_local(input) {
    Err(InvalidIso8601(_)) => ()
    Err(_) => fail("expected InvalidIso8601")
    Ok(_) => fail("expected ISO-8601 input to fail")
  }
}

///|
fn format_iso_local_ok(local_time : @types.LocalDateTime) -> String raise {
  match @tzif.format_iso_local(local_time) {
    Ok(value) => value
    Err(_) => fail("expected local ISO-8601 timestamp to format")
  }
}

///|
fn format_iso_zoned_ok(local_time : @types.LocalDateTime) -> String raise {
  match @tzif.format_iso_zoned(local_time) {
    Ok(value) => value
    Err(_) => fail("expected zoned ISO-8601 timestamp to format")
  }
}

///|
fn format_iso_utc_ok(utc_time : Int64) -> String raise {
  match @tzif.format_iso_utc(utc_time) {
    Ok(value) => value
    Err(_) => fail("expected UTC ISO-8601 timestamp to format")
  }
}

///|
test "ISO parser accepts leap-day local time and formatter round-trips civil fields" {
  let local_time = parse_iso_ok("2024-02-29T23:59:59")
  assert_eq(local_time.year, 2024)
  assert_eq(local_time.month, 2)
  assert_eq(local_time.day, 29)
  assert_eq(local_time.hour, 23)
  assert_eq(local_time.minute, 59)
  assert_eq(local_time.second, 59)
  assert_eq(format_iso_local_ok(local_time), "2024-02-29T23:59:59")
}

///|
test "ISO parser rejects malformed shape and impossible civil values" {
  for
    input in [
      "2024-02-29 23:59:59", "2024-02-29T23:59", "2024-13-01T00:00:00", "2023-02-29T00:00:00",
      "2024-01-01T24:00:00", "2024-01-01T00:00:60", "20a4-01-01T00:00:00", "-001-01-01T00:00:00",
      "10000-01-01T00:00:00",
    ] {
    assert_iso_error(input)
  }
}

///|
test "ISO formatters reject invalid civil fields and non-four-digit years" {
  for
    local_time in [
      civil(-1, 1, 1, 0, 0, 0),
      civil(10_000, 1, 1, 0, 0, 0),
      civil(2026, 2, 29, 0, 0, 0),
      civil(2026, 1, 1, 24, 0, 0),
    ] {
    match @tzif.format_iso_local(local_time) {
      Err(InvalidIso8601(_)) => ()
      _ => fail("expected invalid civil fields to be rejected")
    }
  }
}

///|
test "UTC formatter reports timestamps outside its four-digit year domain" {
  for instant in [-62_167_219_201L, 253_402_300_800L] {
    match @tzif.format_iso_utc(instant) {
      Err(TimestampOutOfRange(value)) => assert_eq(value, instant)
      _ => fail("expected UTC timestamp range error")
    }
  }
}

///|
test "ISO adapters integrate local-to-UTC and zoned UTC formatting" {
  let timezone = load_ok(
    @fixtures.fixed_offset_v2(5 * 3600 + 30 * 60, "IST").bytes,
  )
  let wall_time = parse_iso_ok("2026-01-01T05:30:00")
  let utc_time = local_to_utc_ok(timezone, wall_time, PreferEarlier)
  assert_eq(utc_time, 1_767_225_600L)
  let local_time = local_ok(timezone, utc_time)
  assert_eq(format_iso_zoned_ok(local_time), "2026-01-01T05:30:00+05:30")
  assert_eq(format_iso_utc_ok(utc_time), "2026-01-01T00:00:00Z")
}
