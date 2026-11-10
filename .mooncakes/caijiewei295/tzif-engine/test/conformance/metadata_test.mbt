// TZif metadata retention and read-only inspection API tests.

///|
fn metadata_fixture() -> @fixtures.FixtureFile {
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
    leap_seconds=Some([
      // 1972-06-30 and 1972-12-31 UTC month-end leap insertions.
      { transition_time: 78_796_800L, correction: 1 },
      { transition_time: 94_694_401L, correction: 2 },
    ]),
    standard_indicators=Some([true, true]),
    utc_indicators=Some([false, true]),
    footer="STD0",
  )
}

///|
test "parse retains leap records and ttisstd ttisut metadata" {
  let timezone = load_ok(metadata_fixture().bytes)
  assert_eq(timezone.leap_seconds.length(), 2)
  assert_eq(timezone.leap_seconds[0].transition_time, 78_796_800L)
  assert_eq(timezone.leap_seconds[0].correction, 1)
  assert_eq(timezone.leap_seconds[1].transition_time, 94_694_401L)
  assert_eq(timezone.leap_seconds[1].correction, 2)
  match timezone.standard_indicators {
    None => fail("expected standard/wall indicators")
    Some(values) => {
      assert_eq(values.length(), 2)
      assert_true(values[0])
      assert_true(values[1])
    }
  }
  match timezone.utc_indicators {
    None => fail("expected UT/local indicators")
    Some(values) => {
      assert_eq(values.length(), 2)
      assert_true(!values[0])
      assert_true(values[1])
    }
  }
}

///|
test "diagnostics reports explicit coverage and post-transition behavior" {
  let timezone = load_ok(metadata_fixture().bytes)
  let summary = @tzif.diagnostics(timezone)
  assert_eq(summary.version, b'3')
  assert_eq(summary.transition_count, 2)
  assert_eq(summary.time_type_count, 2)
  assert_eq(summary.leap_second_count, 2)
  assert_eq(summary.standard_indicator_count, 2)
  assert_eq(summary.utc_indicator_count, 2)
  assert_eq(summary.first_transition, Some(100L))
  assert_eq(summary.last_transition, Some(200L))
  assert_true(summary.has_posix_footer)
  match summary.post_transition_behavior {
    PosixFooter => ()
    _ => fail("expected POSIX footer extrapolation")
  }
}

///|
test "transition query API has strict before and after boundaries" {
  let timezone = load_ok(metadata_fixture().bytes)
  match @tzif.transition_at(timezone, -1) {
    None => ()
    Some(_) => fail("negative transition index must be absent")
  }
  match @tzif.transition_at(timezone, 2) {
    None => ()
    Some(_) => fail("out-of-range transition index must be absent")
  }
  match @tzif.transition_at(timezone, 0) {
    Some(value) => assert_eq(value.utc_time, 100L)
    None => fail("expected indexed transition")
  }
  match @tzif.previous_transition(timezone, 100L) {
    None => ()
    Some(_) => fail("transition at query instant is not previous")
  }
  match @tzif.next_transition(timezone, 200L) {
    None => ()
    Some(_) => fail("transition at query instant is not next")
  }
  match @tzif.previous_transition(timezone, 200L) {
    Some(value) => assert_eq(value.utc_time, 100L)
    None => fail("expected earlier transition")
  }
  match @tzif.next_transition(timezone, 100L) {
    Some(value) => assert_eq(value.utc_time, 200L)
    None => fail("expected later transition")
  }
}

///|
test "parse rejects malformed retained metadata rather than discarding it" {
  let file = metadata_fixture()
  assert_load_error(
    @fixtures.bytes_with_byte_at(
      file,
      file.second_standard_indicator_offset,
      b'\x02',
    ),
  )
  let unsorted_leaps = @fixtures.build(
    version=b'2',
    [{ utoff: 0, is_dst: false, abbr_index: 0 }],
    [],
    "UTC\u{0000}",
    leap_seconds=Some([
      { transition_time: 20L, correction: 2 },
      { transition_time: 10L, correction: 1 },
    ]),
  )
  assert_load_error(unsorted_leaps.bytes)
}

///|
test "parse rejects partial ttisstd and ttisut indicator arrays" {
  let file = metadata_fixture()
  // A TZif header stores isutcnt at byte 20 and isstdcnt at byte 24, each as
  // big-endian u32.  Change the low byte of the two-type std count from 2 to
  // 1 while leaving the body structurally present: strict parsing must reject
  // it instead of retaining a misleading partial array.
  assert_load_error(
    @fixtures.bytes_with_byte_at(file, file.second_header_offset + 27, b'\x01'),
  )
  assert_load_error(
    @fixtures.bytes_with_byte_at(file, file.second_header_offset + 23, b'\x01'),
  )
}

///|
test "omitted indicator arrays remain distinct from explicit false flags" {
  let timezone = load_ok(@fixtures.fixed_offset_v2(0, "UTC").bytes)
  assert_eq(timezone.standard_indicators, None)
  assert_eq(timezone.utc_indicators, None)
  let summary = @tzif.diagnostics(timezone)
  assert_eq(summary.standard_indicator_count, 0)
  assert_eq(summary.utc_indicator_count, 0)
  match summary.post_transition_behavior {
    LastExplicitType => ()
    _ => fail("expected explicit type compatibility behavior")
  }
}
