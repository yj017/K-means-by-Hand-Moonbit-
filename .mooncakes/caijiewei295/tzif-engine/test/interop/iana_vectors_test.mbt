// Fixed IANA zoneinfo oracle vectors. Values were generated with Python 3.12
// `zoneinfo` against the system tzdb recorded in docs/test-fixtures.md. TZif
// inputs are constructed from the equivalent public rules so every MoonBit
// backend can execute them without shipping an operating-system zoneinfo tree.

///|
fn vector_load_ok(data : Bytes) -> @types.TzifData raise {
  match @tzif.load(data) {
    Ok(value) => value
    Err(_) => fail("expected IANA vector fixture to load")
  }
}

///|
fn assert_vector(
  timezone : @types.TzifData,
  utc_time : Int64,
  year~ : Int,
  month~ : Int,
  day~ : Int,
  hour~ : Int,
  minute~ : Int,
  utoff~ : Int,
  is_dst~ : Bool,
  abbr~ : String,
) -> Unit raise {
  match @tzif.utc_to_local(timezone, utc_time) {
    Err(_) => fail("expected IANA vector conversion to succeed")
    Ok(local_time) => {
      assert_eq(local_time.year, year)
      assert_eq(local_time.month, month)
      assert_eq(local_time.day, day)
      assert_eq(local_time.hour, hour)
      assert_eq(local_time.minute, minute)
      assert_eq(local_time.second, 0)
      assert_eq(local_time.utoff, utoff)
      assert_eq(local_time.is_dst, is_dst)
      assert_eq(local_time.abbr, abbr)
    }
  }
}

///|
test "IANA Europe London POSIX rule vectors match spring and fall boundaries" {
  let timezone = vector_load_ok(
    @fixtures.fixed_offset_v3(0, "GMT", footer="GMT0BST,M3.5.0/1,M10.5.0/2").bytes,
  )
  assert_vector(
    timezone,
    1_774_746_000L,
    year=2026,
    month=3,
    day=29,
    hour=2,
    minute=0,
    utoff=3600,
    is_dst=true,
    abbr="BST",
  )
  assert_vector(
    timezone,
    1_792_890_000L,
    year=2026,
    month=10,
    day=25,
    hour=1,
    minute=0,
    utoff=0,
    is_dst=false,
    abbr="GMT",
  )
}

///|
test "IANA southern hemisphere and fractional-offset rule vectors" {
  let auckland = vector_load_ok(
    @fixtures.fixed_offset_v3(0, "UTC", footer="NZST-12NZDT,M9.5.0/2,M4.1.0/3").bytes,
  )
  assert_vector(
    auckland,
    1_767_225_600L,
    year=2026,
    month=1,
    day=1,
    hour=13,
    minute=0,
    utoff=13 * 3600,
    is_dst=true,
    abbr="NZDT",
  )
  assert_vector(
    auckland,
    1_775_311_200L,
    year=2026,
    month=4,
    day=5,
    hour=2,
    minute=0,
    utoff=12 * 3600,
    is_dst=false,
    abbr="NZST",
  )
  let kolkata = vector_load_ok(@fixtures.fixed_offset_v2(19_800, "IST").bytes)
  assert_vector(
    kolkata,
    1_767_225_600L,
    year=2026,
    month=1,
    day=1,
    hour=5,
    minute=30,
    utoff=19_800,
    is_dst=false,
    abbr="IST",
  )
  let chatham = vector_load_ok(
    @fixtures.fixed_offset_v3(
      0,
      "UTC",
      footer="CHAST-12:45<+1345>,M9.5.0/2,M4.1.0/3",
    ).bytes,
  )
  assert_vector(
    chatham,
    1_767_225_600L,
    year=2026,
    month=1,
    day=1,
    hour=13,
    minute=45,
    utoff=49_500,
    is_dst=true,
    abbr="+1345",
  )
}

///|
test "IANA historical transition vectors preserve prior type and non-hour changes" {
  let paris = vector_load_ok(
    @fixtures.build(
      version=b'2',
      [
        { utoff: 3600, is_dst: true, abbr_index: 0 },
        { utoff: 7200, is_dst: true, abbr_index: 5 },
      ],
      [{ utc_time: -932_436_000L, type_index: b'\x01' }],
      "WEST\u{0000}CEST\u{0000}",
    ).bytes,
  )
  assert_vector(
    paris,
    -932_439_600L,
    year=1940,
    month=6,
    day=14,
    hour=22,
    minute=0,
    utoff=3600,
    is_dst=true,
    abbr="WEST",
  )
  assert_vector(
    paris,
    -932_436_000L,
    year=1940,
    month=6,
    day=15,
    hour=0,
    minute=0,
    utoff=7200,
    is_dst=true,
    abbr="CEST",
  )
  let shanghai = vector_load_ok(
    @fixtures.build(
      version=b'2',
      [
        { utoff: 32400, is_dst: true, abbr_index: 0 },
        { utoff: 28800, is_dst: false, abbr_index: 4 },
      ],
      [{ utc_time: 684_867_600L, type_index: b'\x01' }],
      "CDT\u{0000}CST\u{0000}",
    ).bytes,
  )
  assert_vector(
    shanghai,
    684_864_000L,
    year=1991,
    month=9,
    day=15,
    hour=1,
    minute=0,
    utoff=32400,
    is_dst=true,
    abbr="CDT",
  )
  assert_vector(
    shanghai,
    684_867_600L,
    year=1991,
    month=9,
    day=15,
    hour=1,
    minute=0,
    utoff=28800,
    is_dst=false,
    abbr="CST",
  )
}
