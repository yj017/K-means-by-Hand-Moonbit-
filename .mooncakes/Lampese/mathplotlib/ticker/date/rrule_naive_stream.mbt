///|
// Reuse the established period/clock candidate generators in local calendar
// coordinates. Filtering is exact Int64 microseconds; no epoch is selected.
fn rrule_naive_stream(
  rule : DateRule,
  lower? : DateTime,
  upper? : DateTime,
) -> Iter[DateTime] {
  let start = rule.dtstart.unwrap()
  let first = match lower {
    Some(value) if rule.count is None &&
      locator_microseconds(value) > locator_microseconds(start) => value
    _ => start
  }
  let mut last = try! datetime(
    9999,
    12,
    31,
    hour=23,
    minute=59,
    second=59,
    microsecond=999999,
  )
  for bound in [rule.until, upper] {
    if bound is Some(value) &&
      locator_microseconds(value) < locator_microseconds(last) {
      last = value
    }
  }
  if locator_microseconds(first) > locator_microseconds(last) ||
    (rule.count is Some(count) && count <= 0) {
    return Iter::empty()
  }
  let candidates = recurrence_candidates(rule, {
    first_date: first,
    last_date: last,
    anchor: start,
  })
  let start_microseconds = locator_microseconds(start)
  let first_microseconds = lower
    .map(locator_microseconds)
    .unwrap_or(start_microseconds)
  let last_microseconds = locator_microseconds(last)
  let mut seen = 0L
  let mut finished = false
  Iter::new(fn() {
    if finished {
      return None
    }
    while true {
      guard candidates.next() is Some(seconds) else {
        finished = true
        return None
      }
      let microseconds = seconds * 1000000L
      if microseconds < start_microseconds {
        continue
      }
      if microseconds > last_microseconds ||
        (rule.count is Some(count) && seen >= Int64::from_int(count)) {
        finished = true
        return None
      }
      seen += 1L
      if microseconds < first_microseconds {
        continue
      }
      return Some(locator_datetime_seconds(seconds, 0))
    }
    None
  })
}
