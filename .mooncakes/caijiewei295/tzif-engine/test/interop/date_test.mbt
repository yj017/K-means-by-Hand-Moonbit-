// Oracle values were generated with GNU date using fixed offsets.  Keeping the
// values in a pure MoonBit test lets native, wasm, and wasm-gc run the same
// regression suite without shelling out to a host timezone database.

///|
fn date_load_ok(data : Bytes) -> @types.TzifData raise {
  match @tzif.load(data) {
    Ok(tz) => tz
    Err(_) => fail("expected oracle fixture to load")
  }
}

///|
fn date_local_ok(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.LocalDateTime raise {
  match @tzif.utc_to_local(tz, utc_time) {
    Ok(local_time) => local_time
    Err(_) => fail("expected UTC conversion to succeed")
  }
}

///|
test "interop GNU date fixed UTC plus eight hours at the epoch" {
  let tz = date_load_ok(@fixtures.fixed_offset_v2(8 * 3600, "CST").bytes)
  let local_time = date_local_ok(tz, 0L)
  assert_eq(local_time.year, 1970)
  assert_eq(local_time.month, 1)
  assert_eq(local_time.day, 1)
  assert_eq(local_time.hour, 8)
  assert_eq(local_time.minute, 0)
  assert_eq(local_time.second, 0)
  assert_eq(local_time.utoff, 8 * 3600)
  assert_eq(local_time.abbr, "CST")
}

///|
test "interop GNU date fixed UTC plus eight hours in 2100" {
  let tz = date_load_ok(@fixtures.fixed_offset_v2(8 * 3600, "CST").bytes)
  let local_time = date_local_ok(tz, 4_102_444_800L)
  assert_eq(local_time.year, 2100)
  assert_eq(local_time.month, 1)
  assert_eq(local_time.day, 1)
  assert_eq(local_time.hour, 8)
  assert_eq(local_time.minute, 0)
  assert_eq(local_time.second, 0)
}
