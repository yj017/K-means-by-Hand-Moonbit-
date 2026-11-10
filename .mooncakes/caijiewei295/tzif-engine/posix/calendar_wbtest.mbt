///|
fn compose_ok(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> Int64 raise {
  match compose_epoch(year, month, day, hour, minute, second) {
    Ok(value) => value
    Err(_) => fail("expected civil timestamp to compose")
  }
}

///|
fn decompose_ok(epoch : Int64) -> (Int, Int, Int, Int, Int, Int) raise {
  match decompose_epoch(epoch) {
    Ok(value) => value
    Err(_) => fail("expected epoch timestamp to decompose")
  }
}

///|
test "calendar supports negative POSIX timestamps with floor division" {
  assert_eq(floor_div_i64(-1L, 86400L), -1L)
  assert_eq(floor_mod_i64(-1L, 86400L), 86399L)
  assert_eq(decompose_ok(-1L), (1969, 12, 31, 23, 59, 59))
  assert_eq(compose_ok(1969, 12, 31, 23, 59, 59), -1L)
  assert_eq(decompose_ok(-2208988800L), (1900, 1, 1, 0, 0, 0))
  assert_eq(day_of_week_of_epoch(-1L), 3)
}

///|
test "calendar preserves 2038 and 2100 timestamps on 32-bit Int targets" {
  assert_eq(decompose_ok(2147483647L), (2038, 1, 19, 3, 14, 7))
  assert_eq(compose_ok(2038, 1, 19, 3, 14, 7), 2147483647L)

  let epoch_2100 = 4102444800L
  assert_eq(decompose_ok(epoch_2100), (2100, 1, 1, 0, 0, 0))
  assert_eq(compose_ok(2100, 1, 1, 0, 0, 0), epoch_2100)
  assert_eq(day_of_week_of_epoch(epoch_2100), 5)
}

///|
test "calendar validates Gregorian dates and round-trips leap days" {
  assert_true(is_valid_date(2000, 2, 29))
  assert_true(!is_valid_date(1900, 2, 29))
  assert_true(!is_valid_date(2100, 2, 29))
  assert_true(!is_valid_date(2026, 13, 1))
  assert_true(is_valid_civil_time(23, 59, 59))
  assert_true(!is_valid_civil_time(24, 0, 0))
  assert_true(!is_valid_civil_time(0, 0, 60))

  let leap_day = compose_ok(2000, 2, 29, 12, 34, 56)
  assert_eq(decompose_ok(leap_day), (2000, 2, 29, 12, 34, 56))
  match civil_from_days(days_from_civil(2000, 2, 29)) {
    Ok(value) => assert_eq(value, (2000, 2, 29))
    Err(_) => fail("expected leap day to fit the civil year domain")
  }
}

///|
test "calendar rejects Int64 epochs whose civil year cannot fit Int" {
  for epoch in [-9_223_372_036_854_775_808L, 9_223_372_036_854_775_807L] {
    match decompose_epoch(epoch) {
      Err(TimestampOutOfRange(value)) => assert_eq(value, epoch)
      _ => fail("expected checked civil-year range error")
    }
  }
}

///|
test "calendar checked arithmetic and compose reject wraparound and bad civil fields" {
  match checked_add_epoch_seconds(9_223_372_036_854_775_807L, 1L) {
    Err(TimestampOutOfRange(value)) =>
      assert_eq(value, 9_223_372_036_854_775_807L)
    _ => fail("expected checked addition overflow")
  }
  match checked_sub_epoch_seconds(-9_223_372_036_854_775_808L, 1L) {
    Err(TimestampOutOfRange(value)) =>
      assert_eq(value, -9_223_372_036_854_775_808L)
    _ => fail("expected checked subtraction underflow")
  }
  match compose_epoch(2026, 2, 29, 0, 0, 0) {
    Err(InvalidLocalTime(_)) => ()
    _ => fail("expected invalid civil date")
  }
}
