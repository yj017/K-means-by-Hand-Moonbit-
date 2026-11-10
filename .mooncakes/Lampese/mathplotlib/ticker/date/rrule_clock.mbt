///|
// Clock fields at or above the recurrence frequency filter base positions.
// Smaller fields expand within a base period in recurrence_clock_times.
fn DateRule::matches_clock_unit(
  self : DateRule,
  slot : Int32,
  unit : Int32,
) -> Bool {
  let seconds = slot * unit
  recurrence_contains(self.byhour, seconds / 3600) &&
  (unit >= 3600 || recurrence_contains(self.byminute, seconds % 3600 / 60)) &&
  (unit >= 60 || recurrence_contains(self.bysecond, seconds % 60))
}

///|
fn recurrence_clock_times(
  rule : DateRule,
  anchor : DateTime,
  unit : Int32,
) -> Array[Int32] {
  let times : Array[Int32] = []
  let minutes = if unit == 3600 {
    recurrence_values(rule.byminute, anchor.minute)
  } else {
    [0]
  }
  let seconds = if unit >= 60 {
    recurrence_values(rule.bysecond, anchor.second)
  } else {
    [0]
  }
  for minute in minutes {
    for second in seconds {
      times.push(minute * 60 + second)
    }
  }
  match rule.bysetpos {
    Some(positions) =>
      recurrence_indices(positions, times.length()).map(index => times[index])
    None => times
  }
}

///|
fn recurrence_clock_candidates(
  rule : DateRule,
  window : RecurrenceCalendarWindow,
  unit : Int32,
) -> Iter[Int64] {
  let unit64 = Int64::from_int(unit)
  let units_per_day = 86400 / unit
  let units64 = Int64::from_int(units_per_day)
  let step = Int64::from_int(rule.interval)
  let anchor_unit = locator_floor_div64(locator_seconds(window.anchor), unit64)
  let times = recurrence_clock_times(rule, window.anchor, unit)
  if times.is_empty() {
    return Iter::empty()
  }
  let slots = recurrence_clock_slots(rule, window.anchor, unit).to_array()
  if slots.is_empty() {
    return Iter::empty()
  }
  let first_day = if rule.count is Some(_) {
    Int64::min(
      locator_floor_div64(locator_seconds(window.first_date), 86400L),
      locator_floor_div64(locator_seconds(window.anchor), 86400L),
    )
  } else {
    locator_floor_div64(locator_seconds(window.first_date), 86400L)
  }
  let last_day = locator_floor_div64(locator_seconds(window.last_date), 86400L)
  let mut day = first_day
  let mut current : Iter[Int64] = Iter::empty()
  Iter::new(fn() {
    while true {
      match current.next() {
        Some(value) => return Some(value)
        None => ()
      }
      if day > last_day {
        return None
      }
      let start_unit = day * units64
      let end_unit = start_unit + units64
      let first_unit = locator_align(start_unit, anchor_unit, step)
      if first_unit >= end_unit {
        day = locator_floor_div64(first_unit, units64)
        continue
      }
      let date = locator_datetime_seconds(
        day * 86400L,
        window.anchor.offset_seconds,
      )
      day += 1L
      if !rule.matches_date(date, window.anchor, date.year) {
        continue
      }
      let count = (end_unit - 1L - first_unit) / step + 1L
      let bases = if count <= Int64::from_int(slots.length()) {
        let mut next = first_unit
        Iter::new(fn() {
          while next < end_unit {
            let value = next
            next += step
            if rule.matches_clock_unit((value - start_unit).to_int(), unit) {
              return Some(value)
            }
          }
          None
        })
      } else {
        slots
        .iter()
        .map(slot => start_unit + Int64::from_int(slot))
        .filter(value => {
          value >= anchor_unit && (value - anchor_unit) % step == 0L
        })
      }
      current = bases.flat_map(base => {
        times.iter().map(time => base * unit64 + Int64::from_int(time))
      })
    }
    None
  })
}

///|
// Clock phases repeat over one day. Iterate only the anchor's residue modulo
// gcd(interval, units_per_day), sharing the same mask with checked wrappers.
fn recurrence_clock_slots(
  rule : DateRule,
  anchor : DateTime,
  unit : Int32,
) -> Iter[Int32] {
  let units_per_day = 86400 / unit
  let divisor = locator_gcd(rule.interval, units_per_day)
  let anchor_unit = locator_floor_div64(
    locator_seconds(anchor),
    Int64::from_int(unit),
  )
  let remainder = anchor_unit % Int64::from_int(divisor)
  let mut slot = ((remainder + Int64::from_int(divisor)) %
  Int64::from_int(divisor)).to_int()
  Iter::new(fn() {
    while slot < units_per_day {
      let value = slot
      slot += divisor
      if rule.matches_clock_unit(value, unit) {
        return Some(value)
      }
    }
    None
  })
}
