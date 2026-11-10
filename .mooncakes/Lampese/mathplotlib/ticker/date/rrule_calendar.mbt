///|
// Calendar candidate generation is shared by numeric locators and naive rule
// wrappers. Only numeric consumers need ordinal clipping, UTC heaps or epochs.
priv struct RecurrenceCalendarWindow {
  first_date : DateTime
  last_date : DateTime
  anchor : DateTime
}

///|
fn recurrence_candidates(
  rule : DateRule,
  window : RecurrenceCalendarWindow,
) -> Iter[Int64] {
  match rule.frequency {
    Hourly => recurrence_clock_candidates(rule, window, 3600)
    Minutely => recurrence_clock_candidates(rule, window, 60)
    Secondly => recurrence_clock_candidates(rule, window, 1)
    _ => recurrence_calendar_candidates(rule, window)
  }
}

///|
fn recurrence_week_start(value : DateTime, wkst : Int32) -> Int32 {
  days_from_civil(value.year, value.month, value.day) -
  (value.weekday() - wkst + 7) % 7
}

///|
// Index periods in calendar units, so interval phase survives variable month
// lengths and leap years. Weeks use the explicitly configured first weekday.
fn recurrence_calendar_index(value : DateTime, rule : DateRule) -> Int32 {
  match rule.frequency {
    Yearly => value.year
    Monthly => value.year * 12 + value.month - 1
    Weekly => recurrence_week_start(value, rule.wkst)
    _ => days_from_civil(value.year, value.month, value.day)
  }
}

///|
fn recurrence_period_days(
  index : Int32,
  frequency : RRuleFrequency,
) -> (Int32, Int32) {
  match frequency {
    Yearly => (days_from_civil(index, 1, 1), days_from_civil(index + 1, 1, 1))
    Monthly => {
      let year = index / 12
      let month = index % 12 + 1
      let start = days_from_civil(year, month, 1)
      (start, start + days_in_month(year, month))
    }
    Weekly => (index, index + 7)
    _ => (index, index + 1)
  }
}

///|
fn recurrence_calendar_candidates(
  rule : DateRule,
  window : RecurrenceCalendarWindow,
) -> Iter[Int64] {
  let period_days = if rule.frequency is Weekly { 7L } else { 1L }
  let step = Int64::from_int(rule.interval) * period_days
  let anchor_index = Int64::from_int(
    recurrence_calendar_index(window.anchor, rule),
  )
  let first_index = Int64::from_int(
    if rule.count is Some(_) {
      Int32::min(
        recurrence_calendar_index(window.first_date, rule),
        recurrence_calendar_index(window.anchor, rule),
      )
    } else {
      recurrence_calendar_index(window.first_date, rule)
    },
  )
  let last_index = Int64::from_int(
    recurrence_calendar_index(window.last_date, rule),
  )
  let start = locator_align(first_index, anchor_index, step)
  let times = recurrence_times(rule, window.anchor)
  let mut index = start
  let mut current : Iter[Int64] = Iter::empty()
  Iter::new(fn() {
    while true {
      match current.next() {
        Some(value) => return Some(value)
        None => ()
      }
      if index > last_index {
        return None
      }
      let (first_day, end_day) = recurrence_period_days(
        index.to_int(),
        rule.frequency,
      )
      index += step
      let days = recurrence_days(rule, window.anchor, first_day, end_day)
      current = match rule.bysetpos {
        Some(positions) =>
          recurrence_indices(positions, days.length() * times.length())
          .iter()
          .map(fn(position) {
            Int64::from_int(days[position / times.length()]) * 86400L +
            Int64::from_int(times[position % times.length()])
          })
        None =>
          days
          .iter()
          .flat_map(day => {
            times
            .iter()
            .map(time => Int64::from_int(day) * 86400L + Int64::from_int(time))
          })
      }
    }
    None
  })
}
