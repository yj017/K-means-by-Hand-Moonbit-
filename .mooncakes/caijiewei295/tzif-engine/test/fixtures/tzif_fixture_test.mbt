///|
fn fixture_u32(data : Bytes, offset : Int) -> UInt {
  (data[offset].to_uint() << 24) |
  (data[offset + 1].to_uint() << 16) |
  (data[offset + 2].to_uint() << 8) |
  data[offset + 3].to_uint()
}

///|
test "fixture mutation helpers remain total outside valid bounds" {
  let file = @fixtures.fixed_offset_v2(0, "UTC")
  let negative = @fixtures.bytes_with_byte_at(file, -1, b'\xff')
  let past_end = @fixtures.bytes_with_byte_at(
    file,
    file.bytes.length(),
    b'\xff',
  )
  assert_eq(negative, file.bytes)
  assert_eq(past_end, file.bytes)
  assert_eq(@fixtures.truncated(file, -1).length(), 0)
  assert_eq(@fixtures.truncated(file, file.bytes.length() + 1), file.bytes)
}

///|
test "fixture v1 compatibility block never wraps 64-bit transitions" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [
      { utc_time: -2_147_483_649L, type_index: b'\x00' },
      { utc_time: 2_147_483_648L, type_index: b'\x00' },
    ],
    "UTC\u{0000}",
  )
  assert_eq(fixture_u32(file.bytes, 32), 0U)
  assert_eq(fixture_u32(file.bytes, file.second_header_offset + 32), 2U)
}

///|
test "synthetic leap records are RFC 9636 month-end values" {
  let file = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    v1_leap_records=2,
  )
  assert_eq(fixture_u32(file.bytes, 28), 2U)
  assert_eq(fixture_u32(file.bytes, file.second_header_offset + 28), 2U)
}
