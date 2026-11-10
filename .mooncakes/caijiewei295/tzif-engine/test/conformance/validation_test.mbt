// Public in-memory TzifData validation tests.

///|
fn base_memory_timezone() -> @types.TzifData {
  {
    version: b'3',
    time_types: [{ utoff: 0, is_dst: false, abbr: "UTC" }],
    transitions: [],
    leap_seconds: [],
    standard_indicators: None,
    utc_indicators: None,
    posix_rule: None,
  }
}

///|
fn assert_memory_validation_error(timezone : @types.TzifData) -> Unit raise {
  match @tzif.validate(timezone) {
    Err(InvalidTransitionTable(_)) => ()
    Err(_) => fail("expected structural timezone validation error")
    Ok(_) => fail("expected invalid in-memory timezone to fail validation")
  }
}

///|
test "public validation accepts parsed compliant timezone data" {
  let timezone = load_ok(metadata_fixture().bytes)
  match @tzif.validate(timezone) {
    Ok(_) => ()
    Err(_) => fail("expected parsed timezone to validate")
  }
}

///|
test "public validation rejects invalid time type and transition tables" {
  let empty_types = @types.TzifData::{
    ..base_memory_timezone(),
    time_types: [],
  }
  assert_memory_validation_error(empty_types)

  let bad_offset = @types.TzifData::{
    ..base_memory_timezone(),
    time_types: [{ utoff: -2_147_483_647 - 1, is_dst: false, abbr: "UTC" }],
  }
  assert_memory_validation_error(bad_offset)

  let interoperable_but_unusual_offset = @types.TzifData::{
    ..base_memory_timezone(),
    time_types: [{ utoff: 100_000, is_dst: false, abbr: "UTC" }],
  }
  match @tzif.validate(interoperable_but_unusual_offset) {
    Ok(_) => ()
    Err(_) => fail("RFC 9636 makes the conventional offset range a SHOULD")
  }

  let bad_transition = @types.TzifData::{
    ..base_memory_timezone(),
    transitions: [{ utc_time: 0L, type_index: 1 }],
  }
  assert_memory_validation_error(bad_transition)
}

///|
test "public validation rejects unordered metadata and incorrect indicator lengths" {
  let unordered_leaps = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [
      { transition_time: 2L, correction: 1 },
      { transition_time: 1L, correction: 2 },
    ],
  }
  assert_memory_validation_error(unordered_leaps)

  let wrong_indicators = @types.TzifData::{
    ..base_memory_timezone(),
    time_types: [
      { utoff: 0, is_dst: false, abbr: "UTC" },
      { utoff: 3600, is_dst: true, abbr: "DST" },
    ],
    standard_indicators: Some([true]),
  }
  assert_memory_validation_error(wrong_indicators)
}

///|
test "public validation enforces RFC 9636 leap-second invariants" {
  let negative_first_occurrence = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [{ transition_time: -1L, correction: 1 }],
  }
  assert_memory_validation_error(negative_first_occurrence)

  let invalid_first_correction = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [{ transition_time: 0L, correction: 2 }],
  }
  assert_memory_validation_error(invalid_first_correction)

  let occurrence_too_close = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [
      { transition_time: 0L, correction: 1 },
      { transition_time: 2_419_198L, correction: 2 },
    ],
  }
  assert_memory_validation_error(occurrence_too_close)

  let correction_jump = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [
      { transition_time: 0L, correction: 1 },
      { transition_time: 2_419_199L, correction: 3 },
    ],
  }
  assert_memory_validation_error(correction_jump)

  let decreasing_extreme_occurrences = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [
      { transition_time: 9_223_372_036_854_775_000L, correction: 1 },
      { transition_time: -1L, correction: 2 },
    ],
  }
  assert_memory_validation_error(decreasing_extreme_occurrences)

  let non_month_end = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [{ transition_time: 10L, correction: 1 }],
  }
  assert_memory_validation_error(non_month_end)

  let valid_month_ends = @types.TzifData::{
    ..base_memory_timezone(),
    leap_seconds: [
      { transition_time: 78_796_800L, correction: 1 },
      { transition_time: 94_694_401L, correction: 2 },
    ],
  }
  match @tzif.validate(valid_month_ends) {
    Ok(_) => ()
    Err(_) => fail("UTC month-end leap records must validate")
  }
}

///|
test "public validation enforces the ttisut implies ttisstd invariant" {
  let missing_standard_indicators = @types.TzifData::{
    ..base_memory_timezone(),
    utc_indicators: Some([true]),
  }
  assert_memory_validation_error(missing_standard_indicators)

  let conflicting_indicators = @types.TzifData::{
    ..base_memory_timezone(),
    standard_indicators: Some([false]),
    utc_indicators: Some([true]),
  }
  assert_memory_validation_error(conflicting_indicators)
}

///|
test "public validation rejects a footer inconsistent with the final transition" {
  let inconsistent_footer = @types.TzifData::{
    ..base_memory_timezone(),
    transitions: [{ utc_time: 0L, type_index: 0 }],
    posix_rule: Some({
      std_abbr: "EST",
      std_offset: -18_000,
      dst_abbr: None,
      dst_offset: None,
      start_rule: None,
      end_rule: None,
    }),
  }
  assert_memory_validation_error(inconsistent_footer)

  let consistent_footer = @types.TzifData::{
    ..base_memory_timezone(),
    transitions: [{ utc_time: 0L, type_index: 0 }],
    posix_rule: Some({
      std_abbr: "UTC",
      std_offset: 0,
      dst_abbr: None,
      dst_offset: None,
      start_rule: None,
      end_rule: None,
    }),
  }
  match @tzif.validate(consistent_footer) {
    Ok(_) => ()
    Err(_) => fail("matching final transition and POSIX footer must validate")
  }
}

///|
test "public validation rejects incomplete POSIX daylight rule" {
  let incomplete_footer = @types.TzifData::{
    ..base_memory_timezone(),
    posix_rule: Some({
      std_abbr: "STD",
      std_offset: 0,
      dst_abbr: Some("DST"),
      dst_offset: Some(3600),
      start_rule: None,
      end_rule: None,
    }),
  }
  assert_memory_validation_error(incomplete_footer)
}
