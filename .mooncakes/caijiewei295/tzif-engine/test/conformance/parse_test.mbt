// RFC 8536 parser conformance tests. Fixtures use only public `load` so these
// remain black-box regression tests while parser internals are refactored.

///|
fn load_ok(data : Bytes) -> @types.TzifData raise {
  match @tzif.load(data) {
    Ok(tz) => tz
    Err(_) => fail("expected TZif fixture to load")
  }
}

///|
fn assert_load_error(data : Bytes) -> Unit raise {
  match @tzif.load(data) {
    Ok(_) => fail("expected malformed TZif fixture to be rejected")
    Err(_) => ()
  }
}

///|
fn one_transition_fixture() -> @fixtures.FixtureFile {
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
test "parse accepts a minimal TZif v2 data set" {
  let file = @fixtures.fixed_offset_v2(0, "UTC")
  ignore(load_ok(file.bytes))
}

///|
test "parse accepts a minimal TZif v3 data set" {
  let file = @fixtures.fixed_offset_v3(0, "UTC")
  ignore(load_ok(file.bytes))
}

///|
test "parse skips an eight-byte v1 leap block before the second header" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    v1_leap_records=1,
  )
  ignore(load_ok(file.bytes))
}

///|
test "parse rejects bad magic" {
  let file = @fixtures.fixed_offset_v2(0, "UTC")
  assert_load_error(@fixtures.bytes_with_byte_at(file, 0, b'X'))
}

///|
test "parse rejects non-zero reserved header bytes" {
  let file = @fixtures.fixed_offset_v2(0, "UTC")
  assert_load_error(@fixtures.bytes_with_byte_at(file, 5, b'\x01'))
}

///|
test "parse rejects every critical truncation boundary" {
  let file = one_transition_fixture()
  for
    length in [
      0,
      43,
      44,
      file.second_header_offset,
      file.second_body_offset,
      file.second_index_offset,
      file.second_ttinfo_offset,
      file.footer_offset,
      file.bytes.length() - 1,
    ] {
    assert_load_error(@fixtures.truncated(file, length))
  }
}

///|
test "parse rejects a zero type count in the second header" {
  let file = @fixtures.fixed_offset_v2(0, "UTC")
  let type_count_last_byte = file.second_header_offset + 39
  assert_load_error(
    @fixtures.bytes_with_byte_at(file, type_count_last_byte, b'\x00'),
  )
}

///|
test "parse rejects a zero designation count in the second header" {
  let file = @fixtures.fixed_offset_v2(0, "UTC")
  let designation_count_last_byte = file.second_header_offset + 43
  assert_load_error(
    @fixtures.bytes_with_byte_at(file, designation_count_last_byte, b'\x00'),
  )
}

///|
test "parse rejects a transition type index outside the type table" {
  let file = one_transition_fixture()
  assert_load_error(
    @fixtures.bytes_with_byte_at(file, file.second_index_offset, b'\x02'),
  )
}

///|
test "parse rejects an out-of-range designation index" {
  let file = one_transition_fixture()
  let designation_index = file.second_ttinfo_offset + 5
  assert_load_error(
    @fixtures.bytes_with_byte_at(file, designation_index, b'\xff'),
  )
}

///|
test "parse rejects a designation without a terminating NUL" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC",
  )
  assert_load_error(file.bytes)
}

///|
test "parse rejects a non-boolean isdst flag" {
  let file = one_transition_fixture()
  let is_dst = file.second_ttinfo_offset + 4
  assert_load_error(@fixtures.bytes_with_byte_at(file, is_dst, b'\x02'))
}

///|
test "parse rejects unsorted transition timestamps" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [
      { utc_time: 200L, type_index: b'\x00' },
      { utc_time: 100L, type_index: b'\x00' },
    ],
    "UTC\u{0000}",
  )
  assert_load_error(file.bytes)
}

///|
test "parse requires exact v3 footer framing and grammar consumption" {
  let file = @fixtures.fixed_offset_v3(
    0,
    "UTC",
    footer="EST5EDT,M3.2.0,M11.1.0!",
  )
  assert_load_error(file.bytes)

  let valid = @fixtures.fixed_offset_v3(0, "UTC")
  assert_load_error(
    @fixtures.bytes_with_byte_at(valid, valid.bytes.length() - 1, b'X'),
  )
}
