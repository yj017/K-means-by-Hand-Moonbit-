///|
fn new_york_rule() -> @types.PosixTzRule {
  {
    std_abbr: "EST",
    std_offset: -18000,
    dst_abbr: Some("EDT"),
    dst_offset: Some(-14400),
    start_rule: Some({
      date_rule: MonthWeekDay(3, 2, 0),
      time_of_day: 7200,
      time_basis: Wall,
    }),
    end_rule: Some({
      date_rule: MonthWeekDay(11, 1, 0),
      time_of_day: 7200,
      time_basis: Wall,
    }),
  }
}

///|
fn rule_epoch_ok(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> Int64 raise {
  match compose_epoch(year, month, day, hour, minute, second) {
    Ok(value) => value
    Err(_) => fail("expected rule test timestamp to compose")
  }
}

///|
fn assert_applied(
  result : @types.TzifResult[(Int, Bool, String)],
  expected_offset : Int,
  expected_dst : Bool,
  expected_abbr : String,
) -> Unit raise {
  match result {
    Ok((offset, is_dst, abbr)) => {
      assert_eq(offset, expected_offset)
      assert_eq(is_dst, expected_dst)
      assert_eq(abbr, expected_abbr)
    }
    Err(_) => panic()
  }
}

///|
fn assert_transition(
  result : @types.TzifResult[Int64],
  expected : Int64,
) -> Unit raise {
  match result {
    Ok(actual) => assert_eq(actual, expected)
    Err(_) => panic()
  }
}

///|
test "POSIX evaluator observes northern hemisphere transition instants" {
  let rule = new_york_rule()
  assert_applied(
    apply_posix_rule(rule, rule_epoch_ok(2026, 3, 8, 6, 59, 59)),
    -18000,
    false,
    "EST",
  )
  assert_applied(
    apply_posix_rule(rule, rule_epoch_ok(2026, 3, 8, 7, 0, 0)),
    -14400,
    true,
    "EDT",
  )
  assert_applied(
    apply_posix_rule(rule, rule_epoch_ok(2026, 11, 1, 5, 59, 59)),
    -14400,
    true,
    "EDT",
  )
  assert_applied(
    apply_posix_rule(rule, rule_epoch_ok(2026, 11, 1, 6, 0, 0)),
    -18000,
    false,
    "EST",
  )
}

///|
test "POSIX evaluator handles southern hemisphere and negative DST offsets" {
  let rule = @types.PosixTzRule::{
    std_abbr: "IST",
    std_offset: 3600,
    dst_abbr: Some("GMT"),
    dst_offset: Some(0),
    start_rule: Some({
      date_rule: MonthWeekDay(10, 5, 0),
      time_of_day: 7200,
      time_basis: Wall,
    }),
    end_rule: Some({
      date_rule: MonthWeekDay(3, 5, 0),
      time_of_day: 3600,
      time_basis: Wall,
    }),
  }
  assert_applied(
    apply_posix_rule(rule, rule_epoch_ok(2026, 1, 1, 0, 0, 0)),
    0,
    true,
    "GMT",
  )
  assert_applied(
    apply_posix_rule(rule, rule_epoch_ok(2026, 6, 1, 0, 0, 0)),
    3600,
    false,
    "IST",
  )
}

///|
test "POSIX evaluator honors Julian leap behavior and explicit UTC basis" {
  let julian = @types.PosixTransitionRule::{
    date_rule: JulianNoLeap(60),
    time_of_day: 7200,
    time_basis: Wall,
  }
  assert_transition(
    compute_transition_point(julian, 2024, 0),
    rule_epoch_ok(2024, 3, 1, 2, 0, 0),
  )

  let utc_rule = @types.PosixTransitionRule::{
    date_rule: MonthWeekDay(3, 5, 0),
    time_of_day: -7200,
    time_basis: Utc,
  }
  assert_transition(
    compute_transition_point(utc_rule, 2026, 19800),
    rule_epoch_ok(2026, 3, 28, 22, 0, 0),
  )
}

///|
test "POSIX day-of-year 365 crosses into the next year only in common years" {
  let rule = @types.PosixTransitionRule::{
    date_rule: DayOfYear(365),
    time_of_day: 0,
    time_basis: Utc,
  }
  assert_transition(
    compute_transition_point(rule, 2023, 0),
    rule_epoch_ok(2024, 1, 1, 0, 0, 0),
  )
  assert_transition(
    compute_transition_point(rule, 2024, 0),
    rule_epoch_ok(2024, 12, 31, 0, 0, 0),
  )
}

///|
test "POSIX transition clock basis and signed time preserve exact UTC events" {
  let date_rule = @types.PosixDateRule::MonthWeekDay(3, 2, 0)
  let wall = @types.PosixTransitionRule::{
    date_rule,
    time_of_day: 7200,
    time_basis: Wall,
  }
  let standard = @types.PosixTransitionRule::{
    date_rule,
    time_of_day: 7200,
    time_basis: Standard,
  }
  let utc = @types.PosixTransitionRule::{
    date_rule,
    time_of_day: 7200,
    time_basis: Utc,
  }
  assert_transition(
    compute_transition_point_with_offsets(wall, 2026, 3600, 7200),
    rule_epoch_ok(2026, 3, 8, 0, 0, 0),
  )
  assert_transition(
    compute_transition_point_with_offsets(standard, 2026, 3600, 7200),
    rule_epoch_ok(2026, 3, 8, 1, 0, 0),
  )
  assert_transition(
    compute_transition_point_with_offsets(utc, 2026, 3600, 7200),
    rule_epoch_ok(2026, 3, 8, 2, 0, 0),
  )

  let cross_year = @types.PosixTransitionRule::{
    date_rule: DayOfYear(0),
    time_of_day: -7200,
    time_basis: Utc,
  }
  assert_transition(
    compute_transition_point(cross_year, 2026, 0),
    rule_epoch_ok(2025, 12, 31, 22, 0, 0),
  )
}

///|
test "implicit daylight offset reports Int overflow" {
  let rule = @types.PosixTzRule::{
    std_abbr: "STD",
    std_offset: 2_147_483_647,
    dst_abbr: Some("DST"),
    dst_offset: None,
    start_rule: Some({
      date_rule: MonthWeekDay(3, 2, 0),
      time_of_day: 7200,
      time_basis: Wall,
    }),
    end_rule: Some({
      date_rule: MonthWeekDay(11, 1, 0),
      time_of_day: 7200,
      time_basis: Wall,
    }),
  }
  match apply_posix_rule(rule, 0L) {
    Err(TimestampOutOfRange(0L)) => ()
    _ => fail("expected checked implicit-DST offset overflow")
  }
}
