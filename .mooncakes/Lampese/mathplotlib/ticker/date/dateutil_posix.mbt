///|
// tzstr builds relativedelta: apply calendar fields, then relative seconds,
// then weekday. End seconds are first converted to standard time. This order
// differs from a POSIX footer for large DST shifts and clocks crossing midnight.
fn dateutil_transition_point(
  point : @tztypes.PosixTransitionRule,
  year : Int32,
  standard : Int32,
  daylight : Int32,
  is_end : Bool,
) -> Int64 {
  let seconds = point.time_of_day -
    (if is_end { daylight - standard } else { 0 })
  let mut day = 0
  match point.date_rule {
    MonthWeekDay(month, week, weekday) => {
      let anchor = if week == 5 { days_in_month(year, month) } else { 1 }
      let base = Int64::from_int(days_from_civil(year, month, anchor)) +
        locator_floor_div64(Int64::from_int(seconds), 86400L)
      let current = ((base + 4L) % 7L + 7L) % 7L
      let distance = if week == 5 {
        -((current.to_int() - weekday + 7) % 7)
      } else {
        (weekday - current.to_int() + 7) % 7 + 7 * (week - 1)
      }
      let remainder = Int64::from_int(seconds) -
        locator_floor_div64(Int64::from_int(seconds), 86400L) * 86400L
      return (base + Int64::from_int(distance)) * 86400L +
        remainder -
        Int64::from_int(standard)
    }
    JulianNoLeap(value) | DayOfYear(value) => {
      let yday = match point.date_rule {
        DayOfYear(_) => value + 1
        _ => value
      }
      let limits = [31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 366]
      let mut month = 1
      while month < 12 && yday > limits[month - 1] {
        month += 1
      }
      let previous = if month == 1 { 0 } else { limits[month - 2] }
      day = days_from_civil(
        year,
        month,
        Int32::min(yday - previous, days_in_month(year, month)),
      )
      if point.date_rule is DayOfYear(_) &&
        yday > 59 &&
        month > 2 &&
        is_leap_year(year) {
        day -= 1
      }
    }
  }
  Int64::from_int(day) * 86400L + Int64::from_int(seconds - standard)
}

///|
fn dateutil_posix_info(
  rule : @tztypes.PosixTzRule,
  seconds : Int64,
) -> (Int32, String?) {
  match (rule.start_rule, rule.end_rule, rule.dst_offset, rule.dst_abbr) {
    (Some(start), Some(end), Some(dst), Some(name)) => {
      let (year, _, _) = civil_from_days(
        locator_floor_div64(seconds, 86400L).to_int(),
      )
      let first = dateutil_transition_point(
        start,
        year,
        rule.std_offset,
        dst,
        false,
      )
      let last = dateutil_transition_point(
        end,
        year,
        rule.std_offset,
        dst,
        true,
      )
      let daylight = if first < last {
        seconds >= first && seconds < last
      } else {
        !(seconds >= last && seconds < first)
      }
      if daylight {
        (dst, Some(name))
      } else {
        (rule.std_offset, Some(rule.std_abbr))
      }
    }
    _ => (rule.std_offset, Some(rule.std_abbr))
  }
}

///|
// tzrangebase.utcoffset evaluates its standard-wall transition labels directly.
// In negative DST this differs from solving for a valid UTC instant: its gap
// keeps the old DST offset and its reverse transition has no fold override.
fn dateutil_posix_local_info(
  rule : @tztypes.PosixTzRule,
  value : DateTime,
  fold : Bool,
) -> (Int32, String?) {
  match (rule.start_rule, rule.end_rule, rule.dst_offset, rule.dst_abbr) {
    (Some(start), Some(end), Some(dst), Some(name)) => {
      let first = dateutil_transition_point(
          start,
          value.year,
          rule.std_offset,
          dst,
          false,
        ) +
        Int64::from_int(rule.std_offset)
      let last = dateutil_transition_point(
          end,
          value.year,
          rule.std_offset,
          dst,
          true,
        ) +
        Int64::from_int(rule.std_offset)
      let wall = locator_microseconds(value)
      let first = first * 1000000L
      let last = last * 1000000L
      let mut daylight = if first < last {
        wall >= first && wall < last
      } else {
        !(wall >= last && wall < first)
      }
      if !daylight &&
        wall >= last &&
        wall < last + Int64::from_int(dst - rule.std_offset) * 1000000L {
        daylight = !fold
      }
      if daylight {
        (dst, Some(name))
      } else {
        (rule.std_offset, Some(rule.std_abbr))
      }
    }
    _ => (rule.std_offset, Some(rule.std_abbr))
  }
}
