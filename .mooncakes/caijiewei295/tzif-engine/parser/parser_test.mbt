///|
fn parse_header_ok(
  data : Bytes,
  offset : Int,
) -> (@parser.TzifHeader, Int) raise {
  match @parser.parse_header(data, offset) {
    Ok(value) => value
    Err(_) => fail("expected TZif header to parse")
  }
}

///|
fn parse_second_body(file : @fixtures.FixtureFile) -> @parser.ParsedBody raise {
  let (v1_header, v1_body_offset) = parse_header_ok(file.bytes, 0)
  let second_header_offset = match
    @parser.data_block_end(file.bytes, v1_header, v1_body_offset, 4) {
    Ok(value) => value
    Err(_) => fail("expected v1 compatibility block to fit")
  }
  let (v2_header, v2_body_offset) = parse_header_ok(
    file.bytes,
    second_header_offset,
  )
  match @parser.parse_body(file.bytes, v2_header, v2_body_offset) {
    Ok(value) => value
    Err(_) => fail("expected v2+ body to parse")
  }
}

///|
test "low-level parser reads both headers and the complete v2 body" {
  let file = @fixtures.build(
    version=b'2',
    [
      { utoff: 0, is_dst: false, abbr_index: 0 },
      { utoff: 3600, is_dst: true, abbr_index: 4 },
    ],
    [{ utc_time: 100L, type_index: b'\x01' }],
    "STD\u{0000}DST\u{0000}",
  )
  let body = parse_second_body(file)
  assert_eq(body.transitions.length(), 1)
  assert_eq(body.transitions[0].utc_time, 100L)
  assert_eq(body.transitions[0].type_index, 1)
  assert_eq(body.time_types.length(), 2)
  assert_eq(body.time_types[1].abbr, "DST")
  assert_eq(body.end_offset, file.footer_offset)
}

///|
test "RFC 9636 accepts utoff outside the SHOULD range but rejects INT32_MIN" {
  let unusual = @fixtures.build(
    version=b'3',
    [{ utoff: 100_000, is_dst: false, abbr_index: 0 }],
    [],
    "ODD\u{0000}",
  )
  let body = parse_second_body(unusual)
  assert_eq(body.time_types[0].utoff, 100_000)

  let invalid = @fixtures.build(
    version=b'3',
    [{ utoff: -2_147_483_647 - 1, is_dst: false, abbr_index: 0 }],
    [],
    "BAD\u{0000}",
  )
  let (_, second_body_offset) = parse_header_ok(
    invalid.bytes,
    invalid.second_header_offset,
  )
  let (header, _) = parse_header_ok(invalid.bytes, invalid.second_header_offset)
  match @parser.parse_body(invalid.bytes, header, second_body_offset) {
    Err(InvalidTransitionTable(_)) => ()
    _ => fail("INT32_MIN utoff must be rejected")
  }
}

///|
test "RFC 9636 leap occurrence is retained only at a UTC month end" {
  let valid = @fixtures.build(
    version=b'3',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    leap_seconds=Some([
      { transition_time: 78_796_800L, correction: 1 },
      { transition_time: 94_694_401L, correction: 2 },
    ]),
  )
  let body = parse_second_body(valid)
  assert_eq(body.leap_seconds.length(), 2)
  assert_eq(body.leap_seconds[1].correction, 2)

  let invalid = @fixtures.build(
    version=b'3',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    leap_seconds=Some([{ transition_time: 10L, correction: 1 }]),
  )
  let (header, body_offset) = parse_header_ok(
    invalid.bytes,
    invalid.second_header_offset,
  )
  match @parser.parse_body(invalid.bytes, header, body_offset) {
    Err(InvalidTransitionTable(_)) => ()
    _ => fail("non-month-end leap occurrence must be rejected")
  }
}

///|
test "designation reader retains lossless legacy ASCII and rejects non-ASCII" {
  let legacy = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "A B\u{0000}",
  )
  assert_eq(parse_second_body(legacy).time_types[0].abbr, "A B")

  let unsupported = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "CETé\u{0000}",
  )
  let (header, body_offset) = parse_header_ok(
    unsupported.bytes,
    unsupported.second_header_offset,
  )
  match @parser.parse_body(unsupported.bytes, header, body_offset) {
    Err(InvalidTransitionTable(_)) => ()
    _ => fail("non-ASCII designation must not be decoded lossily")
  }
}

///|
test "default parser limits reject allocation-amplifying header counts" {
  let header = @parser.TzifHeader::{
    version: b'3',
    isutcnt: 0U,
    isstdcnt: 0U,
    leapcnt: 0U,
    timecnt: 1_000_001U,
    typecnt: 1U,
    charcnt: 1U,
  }
  match @parser.validate_header_counts(header) {
    Err(ResourceLimitExceeded(_)) => ()
    _ => fail("oversized transition count must hit the resource limit")
  }
}

///|
test "v1 compatibility block omits out-of-i32 transitions without wrapping" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [{ utc_time: 2_147_483_648L, type_index: b'\x00' }],
    "UTC\u{0000}",
  )
  let (v1_header, _) = parse_header_ok(file.bytes, 0)
  let (v2_header, _) = parse_header_ok(file.bytes, file.second_header_offset)
  assert_eq(v1_header.timecnt, 0U)
  assert_eq(v2_header.timecnt, 1U)
  assert_eq(parse_second_body(file).transitions[0].utc_time, 2_147_483_648L)
}
