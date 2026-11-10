// POSIX TZ rule evaluation.

///|
fn rule_error(message : String) -> @types.TzifResult[(Int, Int, Int)] {
  Err(PosixParseError(message))
}

///|
/// Resolve a POSIX date rule to an absolute Gregorian date associated with
/// `year`. `DayOfYear(365)` intentionally resolves to the following January 1
/// in a common year.
fn resolve_rule_date(
  date_rule : @types.PosixDateRule,
  year : Int,
) -> @types.TzifResult[(Int, Int, Int)] {
  match date_rule {
    JulianNoLeap(day) => {
      if day < 1 || day > 365 {
        return rule_error("POSIX Julian day must be in 1..365")
      }
      // J60 is 1 March in both common and leap years: leap day is skipped.
      let mut day_index = day - 1
      if is_leap_year(year) && day >= 60 {
        day_index = day_index + 1
      }
      let absolute_days = match
        checked_add_epoch_seconds(
          days_from_civil(year, 1, 1),
          day_index.to_int64(),
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let (resolved_year, month, day) = match civil_from_days(absolute_days) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if resolved_year != year {
        return rule_error(
          "POSIX Julian date resolved outside its calendar year",
        )
      }
      Ok((resolved_year, month, day))
    }
    DayOfYear(day_index) => {
      if day_index < 0 || day_index > 365 {
        return rule_error("POSIX day-of-year must be in 0..365")
      }
      let absolute_days = match
        checked_add_epoch_seconds(
          days_from_civil(year, 1, 1),
          day_index.to_int64(),
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      match civil_from_days(absolute_days) {
        Ok(value) => Ok(value)
        Err(error) => Err(error)
      }
    }
    MonthWeekDay(month, week, weekday) => {
      if month < 1 || month > 12 {
        return rule_error("POSIX transition month must be in 1..12")
      }
      if week < 1 || week > 5 {
        return rule_error("POSIX transition week must be in 1..5")
      }
      if weekday < 0 || weekday > 6 {
        return rule_error("POSIX transition weekday must be in 0..6")
      }
      let max_day = days_in_month(year, month)
      let target_day = if week == 5 {
        let last_epoch = match compose_epoch(year, month, max_day, 0, 0, 0) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let last_weekday = day_of_week_of_epoch(last_epoch)
        max_day - (last_weekday - weekday + 7) % 7
      } else {
        let first_epoch = match compose_epoch(year, month, 1, 0, 0, 0) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let first_weekday = day_of_week_of_epoch(first_epoch)
        1 + (weekday - first_weekday + 7) % 7 + (week - 1) * 7
      }
      Ok((year, month, target_day))
    }
  }
}

///|
/// Compute one transition's UTC instant. `standard_offset` is the rule's
/// standard offset; `wall_offset` is the offset in force immediately before
/// this transition and is used only by the default wall-clock basis.
fn compute_transition_point_with_offsets(
  rule : @types.PosixTransitionRule,
  year : Int,
  standard_offset : Int,
  wall_offset : Int,
) -> @types.TzifResult[Int64] {
  let (resolved_year, month, day) = match
    resolve_rule_date(rule.date_rule, year) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let midnight = match compose_epoch(resolved_year, month, day, 0, 0, 0) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let nominal = match
    checked_add_epoch_seconds(midnight, rule.time_of_day.to_int64()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match rule.time_basis {
    Wall => checked_sub_epoch_seconds(nominal, wall_offset.to_int64())
    Standard => checked_sub_epoch_seconds(nominal, standard_offset.to_int64())
    Utc => Ok(nominal)
  }
}

///|
/// Compute a POSIX transition point using `utoff` as both the standard and
/// wall offset.  This compatibility helper is sufficient for rules with a
/// UTC or standard suffix and for callers that already know the pre-change
/// wall offset. `apply_posix_rule` uses the more precise internal helper.
pub fn compute_transition_point(
  rule : @types.PosixTransitionRule,
  year : Int,
  utoff : Int,
) -> @types.TzifResult[Int64] {
  compute_transition_point_with_offsets(rule, year, utoff, utoff)
}

///|
/// Apply a POSIX TZ rule to one UTC timestamp.
///
/// The evaluator considers transitions from adjacent calendar years and uses
/// the latest transition at or before `utc_time`.  That avoids hemisphere
/// assumptions and correctly handles southern rules, signed v3 transition
/// hours that cross a year boundary, and rules whose DST offset is smaller
/// than the standard offset.
pub fn apply_posix_rule(
  rule : @types.PosixTzRule,
  utc_time : Int64,
) -> @types.TzifResult[(Int, Bool, String)] {
  let dst_abbr = match rule.dst_abbr {
    None => return Ok((rule.std_offset, false, rule.std_abbr))
    Some(value) => value
  }
  let dst_offset = match rule.dst_offset {
    None => {
      let value = rule.std_offset.to_int64() + 3600L
      let narrowed = value.to_int()
      if narrowed.to_int64() != value {
        return Err(TimestampOutOfRange(utc_time))
      }
      narrowed
    }
    Some(value) => value
  }
  let start_rule = match rule.start_rule {
    None =>
      return Err(
        PosixParseError(
          "POSIX DST abbreviation requires a start transition rule",
        ),
      )
    Some(value) => value
  }
  let end_rule = match rule.end_rule {
    None =>
      return Err(
        PosixParseError(
          "POSIX DST abbreviation requires an end transition rule",
        ),
      )
    Some(value) => value
  }
  let (year, _, _, _, _, _) = match decompose_epoch(utc_time) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if year < -2_147_483_646 || year > 2_147_483_645 {
    return Err(TimestampOutOfRange(utc_time))
  }
  let mut has_latest = false
  let mut latest_time = 0L
  let mut latest_enters_dst = false
  // A POSIX time can move a nominal date by at most 167 hours in v3.  Two
  // neighbouring calendar years on each side therefore cover the latest
  // relevant event even near 1 January.
  for transition_year in (year - 2)..<=(year + 2) {
    let start = match
      compute_transition_point_with_offsets(
        start_rule,
        transition_year,
        rule.std_offset,
        rule.std_offset,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let end = match
      compute_transition_point_with_offsets(
        end_rule,
        transition_year,
        rule.std_offset,
        dst_offset,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if start <= utc_time && (!has_latest || start >= latest_time) {
      has_latest = true
      latest_time = start
      latest_enters_dst = true
    }
    // If malformed-but-grammatical rules place both transitions at the same
    // instant, process the end second so the resulting state is standard.
    if end <= utc_time && (!has_latest || end >= latest_time) {
      has_latest = true
      latest_time = end
      latest_enters_dst = false
    }
  }
  if has_latest && latest_enters_dst {
    Ok((dst_offset, true, dst_abbr))
  } else {
    Ok((rule.std_offset, false, rule.std_abbr))
  }
}
