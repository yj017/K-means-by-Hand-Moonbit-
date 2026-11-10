// Lossless local-time resolution and interpreted transition query tests.

///|
test "local time resolution distinguishes unique gap and overlap" {
  let fixed = load_ok(@fixtures.fixed_offset_v2(8 * 3600, "CST").bytes)
  match @tzif.resolve_local(fixed, civil(1970, 1, 1, 8, 0, 0)) {
    Ok(Unique(utc_time)) => assert_eq(utc_time, 0L)
    _ => fail("expected unique fixed-offset local time")
  }

  let gap_timezone = load_ok(spring_forward_fixture().bytes)
  match @tzif.resolve_local(gap_timezone, civil(1970, 1, 1, 2, 30, 0)) {
    Ok(Gap) => ()
    _ => fail("expected spring-forward gap")
  }

  let overlap_timezone = load_ok(fall_back_fixture().bytes)
  match @tzif.resolve_local(overlap_timezone, civil(1970, 1, 1, 2, 30, 0)) {
    Ok(Ambiguous(candidates)) => {
      assert_eq(candidates.length(), 2)
      assert_eq(candidates[0], 5400L)
      assert_eq(candidates[1], 9000L)
    }
    _ => fail("expected fall-back overlap candidates")
  }
}

///|
test "candidate API is sorted for a non-hour historical overlap" {
  let timezone = load_ok(
    @fixtures.build(
      version=b'2',
      [
        { utoff: 3600, is_dst: true, abbr_index: 0 },
        { utoff: 1800, is_dst: false, abbr_index: 4 },
      ],
      [{ utc_time: 7200L, type_index: b'\x01' }],
      "DST\u{0000}STD\u{0000}",
    ).bytes,
  )
  match @tzif.local_time_candidates(timezone, civil(1970, 1, 1, 2, 45, 0)) {
    Ok(candidates) => {
      assert_eq(candidates.length(), 2)
      assert_eq(candidates[0], 6300L)
      assert_eq(candidates[1], 8100L)
    }
    Err(_) => fail("expected non-hour overlap candidates")
  }
}

///|
test "active offset reports initial explicit and footer sources" {
  let fixed = load_ok(@fixtures.fixed_offset_v2(8 * 3600, "CST").bytes)
  match @tzif.active_offset(fixed, 0L) {
    Ok(value) => {
      assert_eq(value.utoff, 8 * 3600)
      assert_eq(value.abbr, "CST")
      match value.source {
        InitialType => ()
        _ => fail("expected initial time-type source")
      }
    }
    Err(_) => fail("expected fixed offset")
  }

  let explicit = load_ok(standard_then_dst_fixture().bytes)
  match @tzif.active_offset(explicit, 100L) {
    Ok(value) =>
      match value.source {
        ExplicitTransition(index) => assert_eq(index, 0)
        _ => fail("expected explicit transition source")
      }
    Err(_) => fail("expected explicit offset")
  }

  let footer = load_ok(metadata_fixture().bytes)
  match @tzif.active_offset(footer, 200L) {
    Ok(value) =>
      match value.source {
        PosixFooter => ()
        _ => fail("expected POSIX footer source")
      }
    Err(_) => fail("expected footer-derived offset")
  }
}

///|
test "transition detail exposes local discontinuity and inclusive range" {
  let timezone = load_ok(metadata_fixture().bytes)
  match @tzif.transition_detail(timezone, 0) {
    Ok(detail) => {
      assert_eq(detail.utc_time, 100L)
      assert_eq(detail.before.utoff, 0)
      assert_eq(detail.after.utoff, 3600)
      assert_eq(detail.offset_change, 3600)
      assert_eq(detail.local_before, 100L)
      assert_eq(detail.local_after, 3700L)
      match detail.clock_change {
        ClockForward => ()
        _ => fail("expected forward clock change")
      }
    }
    Err(_) => fail("expected first transition detail")
  }
  match @tzif.transition_detail(timezone, 1) {
    Ok(detail) =>
      match detail.clock_change {
        ClockBackward => assert_eq(detail.offset_change, -3600)
        _ => fail("expected backward clock change")
      }
    Err(_) => fail("expected second transition detail")
  }
  match @tzif.transition_details_between(timezone, 100L, 100L) {
    Ok(values) => {
      assert_eq(values.length(), 1)
      assert_eq(values[0].index, 0)
    }
    Err(_) => fail("expected inclusive transition range")
  }
  match @tzif.transition_details_between(timezone, 201L, 300L) {
    Ok(values) => assert_eq(values.length(), 0)
    Err(_) => fail("expected empty transition range")
  }
}

///|
test "transition detail rejects invalid query index and reversed range" {
  let timezone = load_ok(metadata_fixture().bytes)
  match @tzif.transition_detail(timezone, -1) {
    Err(InvalidTransitionTable(_)) => ()
    _ => fail("expected invalid transition index")
  }
  match @tzif.transition_details_between(timezone, 2L, 1L) {
    Err(InvalidTransitionTable(_)) => ()
    _ => fail("expected rejected reversed range")
  }
}

///|
test "local resolution propagates structural round-trip errors" {
  let invalid = @types.TzifData::{
    ..base_memory_timezone(),
    transitions: [{ utc_time: -1L, type_index: 1 }],
  }
  match @tzif.resolve_local(invalid, civil(1970, 1, 1, 0, 0, 0)) {
    Err(InvalidTransitionTable(_)) => ()
    Ok(Gap) => fail("structural errors must not be misclassified as gaps")
    _ => fail("expected invalid transition table error")
  }
}
