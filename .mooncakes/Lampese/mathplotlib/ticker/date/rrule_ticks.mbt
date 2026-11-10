///|
priv struct RecurrenceWindow {
  first : Double
  last : Double
  anchor : DateTime
  dtstart_ordinal : Double
  until_ordinal : Double?
  count_limit : Int32?
  timezone : DateTimeZone?
  max_offset_seconds : Int32
  // Transition-aware recurrence candidates are generated in local calendar
  // order. Negative ordinals turn the standard library's max-priority queue
  // into a UTC min-priority queue. The offset range bounds pending candidates
  // to less than two days of local time.
  pending : @priority_queue.PriorityQueue[Double]
  // [occurrences_seen, exhausted]. An array keeps the state shared while the
  // window is passed through the calendar and clock expansion helpers.
  state : Array[Int64]
}

///|
fn RecurrenceWindow::push_ordinal(
  self : RecurrenceWindow,
  result : Array[Double],
  value : Double,
) -> Unit {
  if value < self.dtstart_ordinal {
    return
  }
  match self.until_ordinal {
    Some(until) =>
      if value > until {
        self.state[1] = 1L
        return
      }
    None => ()
  }
  match self.count_limit {
    Some(limit) =>
      if self.state[0] >= Int64::from_int(limit) {
        self.state[1] = 1L
        return
      }
    None => ()
  }
  self.state[0] = self.state[0] + 1L
  locator_push_tick(result, value, self.first, self.last)
}

///|
fn RecurrenceWindow::flush_pending_before(
  self : RecurrenceWindow,
  result : Array[Double],
  watermark : Double,
) -> Unit {
  while result.length() < 100000 && !self.exhausted() {
    match self.pending.peek() {
      Some(negative) if -negative <= watermark => {
        let _ = self.pending.pop()
        self.push_ordinal(result, -negative)
      }
      _ => return
    }
  }
}

///|
fn RecurrenceWindow::flush_pending(
  self : RecurrenceWindow,
  result : Array[Double],
) -> Unit {
  while result.length() < 100000 && !self.exhausted() {
    match self.pending.pop() {
      Some(negative) => self.push_ordinal(result, -negative)
      None => return
    }
  }
}

///|
fn RecurrenceWindow::push_tick(
  self : RecurrenceWindow,
  result : Array[Double],
  local_seconds : Int64,
) -> Unit {
  match self.timezone {
    Some(timezone) => {
      let candidate = locator_datetime_seconds(
        local_seconds,
        self.anchor.offset_seconds,
      )
      for value in timezone.local_ordinal_candidates(candidate) {
        self.pending.push(-value)
      }
      // Every future local candidate is at least `local_seconds` in local
      // time. The largest configured offset therefore gives a safe UTC
      // watermark for flushing the heap. Candidates in a fall-back fold are
      // consequently interleaved by their actual instant before count/until
      // is applied.
      let watermark = unix_seconds_to_ordinal(
        local_seconds - Int64::from_int(self.max_offset_seconds),
      )
      self.flush_pending_before(result, watermark)
    }
    None => {
      let utc_seconds = local_seconds -
        Int64::from_int(self.anchor.offset_seconds)
      self.push_ordinal(result, unix_seconds_to_ordinal(utc_seconds))
    }
  }
}

///|
fn RecurrenceWindow::exhausted(self : RecurrenceWindow) -> Bool {
  self.state[1] == 1L
}

///|
fn recurrence_timezone_offset_bounds(
  timezone : DateTimeZone,
  first : Double,
  last : Double,
) -> (Int32, Int32) {
  let current = timezone.offset_seconds_at(first) catch {
    _ => timezone.initial_offset_seconds
  }
  let mut minimum = current
  let mut maximum = current
  for transition in timezone.transitions {
    if transition.at() > first && transition.at() <= last {
      minimum = Int32::min(minimum, transition.offset_seconds)
      maximum = Int32::max(maximum, transition.offset_seconds)
    }
  }
  // Only offsets that actually occur in this UTC window may widen the
  // local range: inactive historical/future offsets must not shift inferred
  // recurrence phases.
  match timezone.footer {
    Some(_) if timezone.footer_reached(last) => {
      let first_year = (from_ordinal(first) catch {
          _ => return (minimum, maximum)
        }).year
      let last_year = (from_ordinal(last) catch {
          _ => return (minimum, maximum)
        }).year
      for
        transition in timezone.future_transitions(first_year - 1, last_year + 1) {
        if transition.at() > first && transition.at() <= last {
          minimum = Int32::min(minimum, transition.offset_seconds)
          maximum = Int32::max(maximum, transition.offset_seconds)
        }
      }
    }
    _ => ()
  }
  (minimum, maximum)
}

///|
fn recurrence_timezone_max_offset(timezone : DateTimeZone) -> Int32 {
  let mut maximum = timezone.initial_offset_seconds
  for offset in timezone.offsets() {
    maximum = Int32::max(maximum, offset)
  }
  maximum
}

///|
fn recurrence_local_bound(
  utc_seconds : Int64,
  offset_seconds : Int32,
  fallback : DateTime,
) -> DateTime {
  let value = locator_datetime_seconds(utc_seconds, offset_seconds)
  if value.year < 1 || value.year > 9999 {
    fallback
  } else {
    value
  }
}

///|
// A UTC window can cover a local fold whose endpoint fields run backwards.
// Widen the local generation range by offsets active in this UTC window;
// UTC clipping in push_ordinal then selects exactly the visible instants.
fn recurrence_timezone_local_bounds(
  timezone : DateTimeZone,
  first : Double,
  last : Double,
  fallback_first : DateTime,
  fallback_last : DateTime,
) -> (DateTime, DateTime, Int32) {
  let (minimum, maximum) = recurrence_timezone_offset_bounds(
    timezone, first, last,
  )
  let first_utc = from_ordinal(first, offset_minutes=0) catch {
    _ => fallback_first
  }
  let last_utc = from_ordinal(last, offset_minutes=0) catch {
    _ => fallback_last
  }
  let first_seconds = locator_seconds(first_utc)
  let last_seconds = locator_seconds(last_utc)
  let first_offset = timezone.offset_seconds_at(first) catch {
    _ => fallback_first.offset_seconds
  }
  let last_offset = timezone.offset_seconds_at(last) catch {
    _ => fallback_last.offset_seconds
  }
  let local_first = recurrence_local_bound(
    first_seconds + Int64::from_int(minimum),
    first_offset,
    fallback_first,
  )
  let local_last = recurrence_local_bound(
    last_seconds + Int64::from_int(maximum),
    last_offset,
    fallback_last,
  )
  (local_first, local_last, recurrence_timezone_max_offset(timezone))
}

///|
fn recurrence_ordinals(
  locator : DateLocator,
  first_ordinal : Double,
  last_ordinal : Double,
  first : DateTime,
  last : DateTime,
) -> Iter[Double] {
  guard locator.rule is Some(rule) else { return Iter::empty() }
  let effective_last_ordinal = match rule.until {
    Some(value) => Double::min(last_ordinal, value.to_ordinal())
    None => last_ordinal
  }
  if first_ordinal > effective_last_ordinal {
    return Iter::empty()
  }
  let effective_last = match rule.until {
    Some(value) =>
      if value.to_ordinal() < last_ordinal {
        rule.local_date(value)
      } else {
        last
      }
    None => last
  }
  let (anchor_first_date, anchor_last_date, _) = match locator.timezone {
    Some(timezone) =>
      recurrence_timezone_local_bounds(
        timezone, first_ordinal, last_ordinal, first, last,
      )
    None => (first, last, 0)
  }
  let anchor = match rule.dtstart {
    Some(value) =>
      match locator.timezone {
        Some(_) => rule.local_date(value)
        None => value
      }
    None => recurrence_start(anchor_first_date, anchor_last_date)
  }
  let (first_date, last_date, max_offset_seconds) = match locator.timezone {
    Some(timezone) =>
      recurrence_timezone_local_bounds(
        timezone, first_ordinal, effective_last_ordinal, first, effective_last,
      )
    None => (first, effective_last, 0)
  }
  let dtstart_ordinal = match rule.dtstart {
    Some(value) => value.to_ordinal()
    None =>
      match locator.timezone {
        Some(timezone) =>
          timezone.to_ordinal(anchor) catch {
            _ => anchor.to_ordinal()
          }
        None => anchor.to_ordinal()
      }
  }
  let window = {
    first: first_ordinal,
    last: effective_last_ordinal,
    anchor,
    dtstart_ordinal,
    until_ordinal: match rule.until {
      Some(value) => Some(value.to_ordinal())
      None => None
    },
    count_limit: rule.count,
    timezone: locator.timezone,
    max_offset_seconds,
    pending: @priority_queue.PriorityQueue([]),
    state: [0L, 0L],
  }
  let candidates = recurrence_candidates(rule, {
    first_date,
    last_date,
    anchor,
  })
  let buffer : Array[Double] = []
  let mut index = 0
  let mut finished = false
  let mut candidates_done = false
  Iter::new(fn() {
    while !finished {
      if index < buffer.length() {
        let value = buffer[index]
        index += 1
        return Some(value)
      }
      buffer.clear()
      index = 0
      if window.exhausted() {
        finished = true
        return None
      }
      if candidates_done {
        window.flush_pending(buffer)
        if buffer.is_empty() {
          finished = true
        }
      } else {
        match candidates.next() {
          Some(seconds) => window.push_tick(buffer, seconds)
          None => {
            candidates_done = true
            window.flush_pending(buffer)
          }
        }
      }
    }
    None
  })
}

///|
fn recurrence_ticks(
  locator : DateLocator,
  first_ordinal : Double,
  last_ordinal : Double,
  first : DateTime,
  last : DateTime,
) -> Array[Double] {
  recurrence_ordinals(locator, first_ordinal, last_ordinal, first, last)
  .take(100000)
  .to_array()
}
