// UTC -> local conversion regressions.  These tests intentionally enter only
// through the public facade, so data-model refactors cannot hide a bug.

///|
fn local_ok(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.LocalDateTime raise {
  match @tzif.utc_to_local(tz, utc_time) {
    Ok(local_time) => local_time
    Err(_) => fail("expected UTC timestamp to resolve to local time")
  }
}

///|
fn assert_local(
  actual : @types.LocalDateTime,
  year~ : Int,
  month~ : Int,
  day~ : Int,
  hour~ : Int,
  minute~ : Int,
  second~ : Int,
  utoff~ : Int,
  is_dst~ : Bool,
  abbr~ : String,
) -> Unit raise {
  assert_eq(actual.year, year)
  assert_eq(actual.month, month)
  assert_eq(actual.day, day)
  assert_eq(actual.hour, hour)
  assert_eq(actual.minute, minute)
  assert_eq(actual.second, second)
  assert_eq(actual.utoff, utoff)
  assert_eq(actual.is_dst, is_dst)
  assert_eq(actual.abbr, abbr)
}

///|
fn civil(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> @types.LocalDateTime {
  { year, month, day, hour, minute, second, utoff: 0, is_dst: false, abbr: "" }
}

///|
fn local_to_utc_ok(
  tz : @types.TzifData,
  local_time : @types.LocalDateTime,
  strategy : @types.AmbiguityStrategy,
) -> Int64 raise {
  match @tzif.local_to_utc(tz, local_time, strategy) {
    Ok(utc) => utc
    Err(_) => fail("expected local wall time to resolve")
  }
}

///|
fn assert_local_to_utc_error(
  tz : @types.TzifData,
  local_time : @types.LocalDateTime,
) -> Unit raise {
  match @tzif.local_to_utc(tz, local_time, PreferEarlier) {
    Ok(_) => fail("expected local wall time to be rejected")
    Err(_) => ()
  }
}

///|
fn standard_then_dst_fixture() -> @fixtures.FixtureFile {
  @fixtures.build(
    version=b'2',
    [
      { utoff: 0, is_dst: false, abbr_index: 0 },
      { utoff: 3600, is_dst: true, abbr_index: 4 },
    ],
    [{ utc_time: 100L, type_index: b'\x01' }],
    "STD\u{0000}DST\u{0000}",
  )
}

///|
fn spring_forward_fixture() -> @fixtures.FixtureFile {
  @fixtures.build(
    version=b'2',
    [
      { utoff: 0, is_dst: false, abbr_index: 0 },
      { utoff: 3600, is_dst: true, abbr_index: 4 },
    ],
    [{ utc_time: 7200L, type_index: b'\x01' }],
    "STD\u{0000}DST\u{0000}",
  )
}

///|
fn fall_back_fixture() -> @fixtures.FixtureFile {
  @fixtures.build(
    version=b'2',
    [
      { utoff: 3600, is_dst: true, abbr_index: 0 },
      { utoff: 0, is_dst: false, abbr_index: 4 },
    ],
    [{ utc_time: 7200L, type_index: b'\x01' }],
    "DST\u{0000}STD\u{0000}",
  )
}

///|
test "utc_to_local uses type zero when there are no transitions" {
  let tz = load_ok(@fixtures.fixed_offset_v2(8 * 3600, "CST").bytes)
  assert_local(
    local_ok(tz, 0L),
    year=1970,
    month=1,
    day=1,
    hour=8,
    minute=0,
    second=0,
    utoff=8 * 3600,
    is_dst=false,
    abbr="CST",
  )
}

///|
test "local_to_utc inverts a unique fixed-offset local time" {
  let tz = load_ok(@fixtures.fixed_offset_v2(8 * 3600, "CST").bytes)
  assert_eq(local_to_utc_ok(tz, civil(1970, 1, 1, 8, 0, 0), PreferEarlier), 0L)
}

///|
test "local_to_utc rejects a spring-forward gap" {
  let tz = load_ok(spring_forward_fixture().bytes)
  assert_local_to_utc_error(tz, civil(1970, 1, 1, 2, 30, 0))
}

///|
test "local_to_utc applies earlier and later strategies to a fall overlap" {
  let tz = load_ok(fall_back_fixture().bytes)
  let overlap = civil(1970, 1, 1, 2, 30, 0)
  assert_eq(local_to_utc_ok(tz, overlap, PreferEarlier), 5400L)
  assert_eq(local_to_utc_ok(tz, overlap, PreferLater), 9000L)
}

///|
test "utc_to_local uses type zero before the first transition" {
  let tz = load_ok(standard_then_dst_fixture().bytes)
  assert_local(
    local_ok(tz, 99L),
    year=1970,
    month=1,
    day=1,
    hour=0,
    minute=1,
    second=39,
    utoff=0,
    is_dst=false,
    abbr="STD",
  )
}

///|
test "utc_to_local applies the new type at a transition instant" {
  let tz = load_ok(standard_then_dst_fixture().bytes)
  assert_local(
    local_ok(tz, 100L),
    year=1970,
    month=1,
    day=1,
    hour=1,
    minute=1,
    second=40,
    utoff=3600,
    is_dst=true,
    abbr="DST",
  )
}

///|
test "utc_to_local keeps Int64 epoch calculations beyond 2038" {
  let tz = load_ok(@fixtures.fixed_offset_v2(0, "UTC").bytes)
  assert_local(
    local_ok(tz, 4_102_444_800L),
    year=2100,
    month=1,
    day=1,
    hour=0,
    minute=0,
    second=0,
    utoff=0,
    is_dst=false,
    abbr="UTC",
  )
}

///|
test "utc_to_local decomposes negative epoch seconds correctly" {
  let tz = load_ok(@fixtures.fixed_offset_v2(0, "UTC").bytes)
  assert_local(
    local_ok(tz, -1L),
    year=1969,
    month=12,
    day=31,
    hour=23,
    minute=59,
    second=59,
    utoff=0,
    is_dst=false,
    abbr="UTC",
  )
}

///|
test "utc_to_local reports Int64 calendar and offset overflow exactly" {
  let utc = load_ok(@fixtures.fixed_offset_v2(0, "UTC").bytes)
  for instant in [9_223_372_036_854_775_807L, -9_223_372_036_854_775_808L] {
    match @tzif.utc_to_local(utc, instant) {
      Err(TimestampOutOfRange(value)) => assert_eq(value, instant)
      _ => fail("expected unrepresentable civil year to report range error")
    }
  }

  let east = load_ok(@fixtures.fixed_offset_v2(3600, "EAST").bytes)
  match @tzif.utc_to_local(east, 9_223_372_036_854_775_807L) {
    Err(TimestampOutOfRange(value)) =>
      assert_eq(value, 9_223_372_036_854_775_807L)
    _ => fail("expected positive offset addition to report overflow")
  }
  let west = load_ok(@fixtures.fixed_offset_v2(-3600, "WEST").bytes)
  match @tzif.utc_to_local(west, -9_223_372_036_854_775_808L) {
    Err(TimestampOutOfRange(value)) =>
      assert_eq(value, -9_223_372_036_854_775_808L)
    _ => fail("expected negative offset addition to report overflow")
  }
}
