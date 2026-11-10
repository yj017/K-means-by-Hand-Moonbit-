// Deterministic malformed-input corpus. No randomized seed or host fuzzing is
// required, so native and wasm targets execute the same parser-hardening test.

///|
fn mutation_fixture() -> @fixtures.FixtureFile {
  @fixtures.build(
    version=b'3',
    [
      { utoff: 0, is_dst: false, abbr_index: 0 },
      { utoff: 3600, is_dst: true, abbr_index: 4 },
    ],
    [
      { utc_time: 100L, type_index: b'\x01' },
      { utc_time: 200L, type_index: b'\x00' },
    ],
    "STD\u{0000}DST\u{0000}",
    leap_seconds=Some([{ transition_time: 78_796_800L, correction: 1 }]),
    standard_indicators=Some([true, true]),
    utc_indicators=Some([false, true]),
    footer="STD0",
  )
}

///|
fn byte_replaced(data : Bytes, index : Int, replacement : Byte) -> Bytes {
  let mutated = data.to_array()
  mutated[index] = replacement
  Bytes::from_array(mutated)
}

///|
fn assert_tzif_rejected(bytes : Bytes) -> Unit raise {
  match @tzif.load(bytes) {
    Err(InvalidTransitionTable(_)) => ()
    Err(_) => fail("expected an RFC 9636 structural validation error")
    Ok(_) => fail("malformed TZif data unexpectedly parsed")
  }
}

///|
fn leap_fixture(
  leap_seconds : Array[@fixtures.FixtureLeapSecond],
) -> @fixtures.FixtureFile {
  @fixtures.build(
    version=b'3',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    leap_seconds=Some(leap_seconds),
    footer="UTC0",
  )
}

///|
test "parser rejects leap records that violate RFC 9636 MUST constraints" {
  assert_tzif_rejected(
    leap_fixture([{ transition_time: -1L, correction: 1 }]).bytes,
  )
  assert_tzif_rejected(
    leap_fixture([{ transition_time: 78_796_800L, correction: 2 }]).bytes,
  )
  assert_tzif_rejected(
    leap_fixture([{ transition_time: 10L, correction: 1 }]).bytes,
  )
  assert_tzif_rejected(
    leap_fixture([
      { transition_time: 78_796_800L, correction: 1 },
      { transition_time: 81_215_998L, correction: 2 },
    ]).bytes,
  )
  assert_tzif_rejected(
    leap_fixture([
      { transition_time: 78_796_800L, correction: 1 },
      { transition_time: 94_694_401L, correction: 3 },
    ]).bytes,
  )
  assert_tzif_rejected(
    leap_fixture([
      { transition_time: 78_796_800L, correction: 1 },
      { transition_time: 0L, correction: 2 },
    ]).bytes,
  )
}

///|
test "parser rejects ttisut indicators without corresponding ttisstd flags" {
  let missing_standard = @fixtures.build(
    version=b'3',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    utc_indicators=Some([true]),
    footer="UTC0",
  )
  assert_tzif_rejected(missing_standard.bytes)

  let conflicting = @fixtures.build(
    version=b'3',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    standard_indicators=Some([false]),
    utc_indicators=Some([true]),
    footer="UTC0",
  )
  assert_tzif_rejected(conflicting.bytes)
}

///|
test "loader rejects POSIX footer inconsistent with final transition type" {
  let inconsistent = @fixtures.build(
    version=b'3',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [{ utc_time: 0L, type_index: b'\x00' }],
    "UTC\u{0000}",
    footer="EST5",
  )
  assert_tzif_rejected(inconsistent.bytes)
}

///|
test "deterministic single-byte mutation corpus never panics and rejects most corruptions" {
  let source = mutation_fixture().bytes
  let mut rejected = 0
  let mut accepted = 0
  for index in 0..<source.length() {
    for replacement in [b'\x00', b'\xff'] {
      match @tzif.load(byte_replaced(source, index, replacement)) {
        Ok(_) => accepted = accepted + 1
        Err(_) => rejected = rejected + 1
      }
    }
  }
  // The v1 compatibility block is intentionally skipped, so some mutations
  // remain valid. The corpus still has a large, stable set of validated
  // rejection paths and all remaining changes return a Result rather than
  // triggering an unchecked crash.
  assert_true(accepted > 0)
  assert_true(rejected > 150)
}

///|
test "every strict prefix of a complete TZif fixture is rejected without panic" {
  let source = mutation_fixture().bytes
  for length in 0..<source.length() {
    let prefix = Bytes::from_array(source.to_array()[:length])
    match @tzif.load(prefix) {
      Err(_) => ()
      Ok(_) =>
        fail("truncated TZif prefix unexpectedly parsed at byte \{length}")
    }
  }
}

///|
test "unmodified deterministic corpus seed remains accepted" {
  match @tzif.load(mutation_fixture().bytes) {
    Ok(_) => ()
    Err(_) => fail("baseline fixture must remain valid")
  }
}
