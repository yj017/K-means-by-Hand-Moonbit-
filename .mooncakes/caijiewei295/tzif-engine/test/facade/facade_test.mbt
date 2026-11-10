///|
fn fixed_timezone(offset : Int, abbreviation : String) -> @types.TzifData {
  {
    version: b'2',
    time_types: [{ utoff: offset, is_dst: false, abbr: abbreviation }],
    transitions: [],
    leap_seconds: [],
    standard_indicators: None,
    utc_indicators: None,
    posix_rule: None,
  }
}

///|
test "info preserves second-level historical UTC offsets" {
  let summary = @tzif.info(fixed_timezone(-17762, "LMT"))
  assert_true(summary.contains("UTC-04:56:02"))
  let unusual = @tzif.info(fixed_timezone(100_000, "WIDE"))
  assert_true(unusual.contains("UTC+100000s"))
}

///|
test "info rejects malformed public data without indexing a bad type" {
  let timezone = fixed_timezone(0, "UTC")
  timezone.transitions.push({ utc_time: 0L, type_index: 7 })
  inspect(@tzif.info(timezone), content="Invalid in-memory TZif data")
}

///|
test "transition query errors interpolate the requested index" {
  match @tzif.transition_detail(fixed_timezone(0, "UTC"), 7) {
    Err(InvalidTransitionTable(message)) =>
      inspect(message, content="transition index 7 is out of range")
    _ => fail("expected an out-of-range transition error")
  }
}

///|
test "transition detail reports local-boundary overflow" {
  let timezone = fixed_timezone(1, "EAST")
  timezone.transitions.push({
    utc_time: 9_223_372_036_854_775_807L,
    type_index: 0,
  })
  match @tzif.transition_detail(timezone, 0) {
    Err(TimestampOutOfRange(value)) =>
      assert_eq(value, 9_223_372_036_854_775_807L)
    _ => fail("expected checked local-boundary overflow")
  }
}

///|
test "transition detail reports an unrepresentable offset delta" {
  let timezone = @types.TzifData::{
    version: b'3',
    time_types: [
      { utoff: -2_147_483_647, is_dst: false, abbr: "WEST" },
      { utoff: 2_147_483_647, is_dst: false, abbr: "EAST" },
    ],
    transitions: [{ utc_time: 0L, type_index: 1 }],
    leap_seconds: [],
    standard_indicators: None,
    utc_indicators: None,
    posix_rule: None,
  }
  match @tzif.transition_detail(timezone, 0) {
    Err(TimestampOutOfRange(0L)) => ()
    _ => fail("expected checked offset-delta range error")
  }
}
