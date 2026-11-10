///|
fn DateRule::matches_year_fields(
  self : DateRule,
  value : DateTime,
  period_year : Int32,
) -> Bool {
  if self.byyearday is Some(days) {
    let length = if is_leap_year(value.year) { 366 } else { 365 }
    let day = days_from_civil(value.year, value.month, value.day) -
      days_from_civil(value.year, 1, 1) +
      1
    if !days.contains(day) && !days.contains(day - length - 1) {
      return false
    }
  }
  if self.byweekno is Some(weeks) &&
    !recurrence_matches_weekno(value, period_year, self.wkst, weeks) {
    return false
  }
  if self.byeaster is Some(offsets) {
    let day = days_from_civil(value.year, value.month, value.day) -
      days_from_civil(period_year, 1, 1) +
      1
    if !offsets.contains(day - recurrence_easter_day(period_year)) {
      return false
    }
  }
  true
}

///|
// Gregorian Western Easter, expressed as a one-based day of year. The
// integer algorithm also works at both ends of our supported year range.
fn recurrence_easter_day(year : Int32) -> Int32 {
  let a = year % 19
  let b = year / 100
  let c = year % 100
  let d = b / 4
  let e = b % 4
  let f = (b + 8) / 25
  let g = (b - f + 1) / 3
  let h = (19 * a + b - d - g + 15) % 30
  let i = c / 4
  let k = c % 4
  let l = (32 + 2 * e + 2 * i - h - k) % 7
  let m = (a + 11 * h + 22 * l) / 451
  let month = (h + l - 7 * m + 114) / 31
  let day = (h + l - 7 * m + 114) % 31 + 1
  days_from_civil(year, month, day) - days_from_civil(year, 1, 1) + 1
}

///|
// A weekly period may run into January of the following year. Resolve week
// numbers using the period's year, as dateutil._iterinfo.rebuild does, rather
// than rebuilding the mask midway through that period.
fn recurrence_matches_weekno(
  value : DateTime,
  year : Int32,
  wkst : Int32,
  weeks : Array[Int32],
) -> Bool {
  let length = if is_leap_year(year) { 366 } else { 365 }
  let index = days_from_civil(value.year, value.month, value.day) -
    days_from_civil(year, 1, 1)
  let weekday = weekday_from_civil(year, 1, 1)
  let first_start = (7 - weekday + wkst) % 7
  let first = if first_start >= 4 { 0 } else { first_start }
  let week_year_length = if first_start >= 4 {
    length + (weekday - wkst + 7) % 7
  } else {
    length - first
  }
  let count = week_year_length / 7 + week_year_length % 7 / 4
  for requested in weeks {
    let week = if requested < 0 { requested + count + 1 } else { requested }
    if week < 1 || week > count {
      continue
    }
    let start = if week == 1 {
      first
    } else {
      first +
      (week - 1) * 7 -
      (if first != first_start { 7 - first_start } else { 0 })
    }
    if recurrence_in_week(index, start, weekday, wkst) {
      return true
    }
  }
  // Only an explicit +1 includes the next year's first week. Keep dateutil's
  // distinction between +1 and a negative number normalized to +1.
  if weeks.contains(1) {
    let start = first +
      count * 7 -
      (if first != first_start { 7 - first_start } else { 0 })
    if start < length && recurrence_in_week(index, start, weekday, wkst) {
      return true
    }
  }
  if first != 0 && index >= 0 && index < first {
    if weeks.contains(-1) {
      return true
    }
    let previous_weekday = weekday_from_civil(year - 1, 1, 1)
    let previous_start = (7 - previous_weekday + wkst) % 7
    let previous_length = if is_leap_year(year - 1) { 366 } else { 365 }
    // This expression intentionally follows dateutil's year-mask semantics.
    let previous_count = if previous_start >= 4 {
      52 + (previous_length + (previous_weekday - wkst + 7) % 7) % 7 / 4
    } else {
      52 + (length - first) % 7 / 4
    }
    return weeks.contains(previous_count)
  }
  false
}

///|
// January 1 may be partway through a numbered week. Stop at the next WKST,
// rather than treating every numbered interval as seven days from January 1.
fn recurrence_in_week(
  index : Int32,
  start : Int32,
  year_weekday : Int32,
  wkst : Int32,
) -> Bool {
  let distance = (wkst - (year_weekday + start) % 7 + 7) % 7
  let length = if distance == 0 { 7 } else { distance }
  index >= start && index < start + length
}
