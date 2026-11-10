// Oracle values were generated with Python's stdlib zoneinfo for
// America/New_York.  The fixture uses the equivalent POSIX footer so the test
// remains portable and does not make /usr/share/zoneinfo a runtime dependency.

///|
fn new_york_fixture() -> @fixtures.FixtureFile {
  @fixtures.fixed_offset_v3(0, "UTC", footer="EST5EDT,M3.2.0,M11.1.0")
}

///|
fn zoneinfo_load_ok(data : Bytes) -> @types.TzifData raise {
  match @tzif.load(data) {
    Ok(tz) => tz
    Err(_) => fail("expected New York oracle fixture to load")
  }
}

///|
fn zoneinfo_local_ok(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.LocalDateTime raise {
  match @tzif.utc_to_local(tz, utc_time) {
    Ok(local_time) => local_time
    Err(_) => fail("expected New York UTC conversion to succeed")
  }
}

///|
test "interop Python zoneinfo New York spring transition instant" {
  let tz = zoneinfo_load_ok(new_york_fixture().bytes)
  // Python zoneinfo: 2026-03-08T07:00:00Z = 03:00 EDT.
  let local_time = zoneinfo_local_ok(tz, 1_772_953_200L)
  assert_eq(local_time.year, 2026)
  assert_eq(local_time.month, 3)
  assert_eq(local_time.day, 8)
  assert_eq(local_time.hour, 3)
  assert_eq(local_time.minute, 0)
  assert_eq(local_time.second, 0)
  assert_eq(local_time.utoff, -4 * 3600)
  assert_true(local_time.is_dst)
  assert_eq(local_time.abbr, "EDT")
}

///|
test "interop Python zoneinfo New York fall transition instant" {
  let tz = zoneinfo_load_ok(new_york_fixture().bytes)
  // Python zoneinfo: 2026-11-01T06:00:00Z = 01:00 EST.
  let local_time = zoneinfo_local_ok(tz, 1_793_512_800L)
  assert_eq(local_time.year, 2026)
  assert_eq(local_time.month, 11)
  assert_eq(local_time.day, 1)
  assert_eq(local_time.hour, 1)
  assert_eq(local_time.minute, 0)
  assert_eq(local_time.second, 0)
  assert_eq(local_time.utoff, -5 * 3600)
  assert_true(!local_time.is_dst)
  assert_eq(local_time.abbr, "EST")
}
