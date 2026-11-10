// POSIX footer conformance through the public TZif loader and converter.

///|
test "v2 footer is parsed after the second data block" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: -18_000, is_dst: false, abbr_index: 0 }],
    [{ utc_time: 0L, type_index: b'\x00' }],
    "EST\u{0000}",
    footer="EST5EDT,M3.2.0,M11.1.0",
  )
  let tz = load_ok(file.bytes)
  assert_local(
    local_ok(tz, 1_767_225_600L),
    year=2025,
    month=12,
    day=31,
    hour=19,
    minute=0,
    second=0,
    utoff=-5 * 3600,
    is_dst=false,
    abbr="EST",
  )
}

///|
test "v3 footer supplies standard time when the transition table is empty" {
  let tz = load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="EST5EDT,M3.2.0,M11.1.0").bytes,
  )
  assert_local(
    local_ok(tz, 1_767_225_600L),
    year=2025,
    month=12,
    day=31,
    hour=19,
    minute=0,
    second=0,
    utoff=-5 * 3600,
    is_dst=false,
    abbr="EST",
  )
}

///|
test "POSIX slash transition times are hours rather than seconds" {
  let tz = load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="EST5EDT,M3.2.0/2,M11.1.0/2").bytes,
  )
  // 2026-03-08 05:00:03 UTC is still before the 02:00 local-standard
  // transition (07:00 UTC).  Treating `/2` as two seconds makes this EDT.
  assert_local(
    local_ok(tz, 1_772_946_003L),
    year=2026,
    month=3,
    day=8,
    hour=0,
    minute=0,
    second=3,
    utoff=-5 * 3600,
    is_dst=false,
    abbr="EST",
  )
}

///|
test "POSIX Julian no-leap day rules are accepted" {
  let tz = load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="IST-1GMT0,J60/2,J300/2").bytes,
  )
  assert_local(
    local_ok(tz, 1_767_225_600L),
    year=2026,
    month=1,
    day=1,
    hour=1,
    minute=0,
    second=0,
    utoff=3600,
    is_dst=false,
    abbr="IST",
  )
}

///|
test "POSIX zero-based day-of-year rules are accepted" {
  let tz = load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="STD0DST,59/2,303/2").bytes,
  )
  assert_local(
    local_ok(tz, 1_767_225_600L),
    year=2026,
    month=1,
    day=1,
    hour=0,
    minute=0,
    second=0,
    utoff=0,
    is_dst=false,
    abbr="STD",
  )
}

///|
test "deployed v2 all-year DST footer is consistent at its final transition" {
  let timezone = load_ok(
    @fixtures.build(
      version=b'2',
      [{ utoff: 3600, is_dst: true, abbr_index: 0 }],
      [{ utc_time: 0L, type_index: b'\x00' }],
      "+01\u{0000}",
      footer="<+00>0<+01>,0/0,J365/25",
    ).bytes,
  )
  assert_local(
    local_ok(timezone, 0L),
    year=1970,
    month=1,
    day=1,
    hour=1,
    minute=0,
    second=0,
    utoff=3600,
    is_dst=true,
    abbr="+01",
  )
}

///|
test "POSIX day 365 crosses into January in a common year" {
  let timezone = load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="STD0DST,365/0,1/0").bytes,
  )
  assert_local(
    local_ok(timezone, 1_704_067_199L),
    year=2023,
    month=12,
    day=31,
    hour=23,
    minute=59,
    second=59,
    utoff=0,
    is_dst=false,
    abbr="STD",
  )
  assert_local(
    local_ok(timezone, 1_704_067_200L),
    year=2024,
    month=1,
    day=1,
    hour=1,
    minute=0,
    second=0,
    utoff=3600,
    is_dst=true,
    abbr="DST",
  )
}

///|
test "v3 extended transition hours retain their exact UTC boundary" {
  let timezone = load_ok(
    @fixtures.fixed_offset_v3(
      0,
      "UTC",
      footer="STD0DST,M3.2.0/167:59:59u,M11.1.0/2u",
    ).bytes,
  )
  assert_local(
    local_ok(timezone, 1_773_532_798L),
    year=2026,
    month=3,
    day=14,
    hour=23,
    minute=59,
    second=58,
    utoff=0,
    is_dst=false,
    abbr="STD",
  )
  assert_local(
    local_ok(timezone, 1_773_532_799L),
    year=2026,
    month=3,
    day=15,
    hour=0,
    minute=59,
    second=59,
    utoff=3600,
    is_dst=true,
    abbr="DST",
  )
}

///|
test "POSIX standard offsets accept the recommended TZif boundary" {
  let timezone = load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="AAA24:59:59").bytes,
  )
  assert_local(
    local_ok(timezone, 0L),
    year=1969,
    month=12,
    day=30,
    hour=23,
    minute=0,
    second=1,
    utoff=-89_999,
    is_dst=false,
    abbr="AAA",
  )
}
