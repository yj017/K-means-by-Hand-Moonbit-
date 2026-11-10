///|
priv struct RecurrenceCache {
  values : Array[DateTime]
  mut source : Iter[DateTime]?
  mut complete : Bool
}

///|
fn recurrence_cache(enabled : Bool) -> RecurrenceCache? {
  if enabled {
    Some({ values: [], source: None, complete: false, })
  } else {
    None
  }
}

///|
fn RecurrenceCache::iterator(
  self : RecurrenceCache,
  factory : () -> Iter[DateTime],
) -> Iter[DateTime] {
  let mut index = 0
  Iter::new(fn() {
    if index < self.values.length() {
      let value = self.values[index]
      index += 1
      return Some(value)
    }
    if self.complete {
      return None
    }
    if self.source is None {
      self.source = Some(factory())
    }
    match self.source.unwrap().next() {
      Some(value) => {
        self.values.push(value)
        index += 1
        Some(value)
      }
      None => {
        self.complete = true
        self.source = None
        None
      }
    }
  })
}

///|
// Delay candidate construction until the reader actually requests a value.
// Only calendar-boundary conversions can be unavailable for a validated rule;
// these are clipped to the same supported Gregorian/UTC domain as locators.
fn rrule_stream(rule : DateRule, lower : DateTime?) -> Iter[DateTime] {
  let mut source : Iter[Double]? = None
  let mut finished = false
  Iter::new(fn() {
    if finished {
      return None
    }
    if source is None {
      let start = rule.dtstart.unwrap()
      let first = match lower {
        Some(value) if value.to_ordinal() > start.to_ordinal() => value
        _ => start
      }
      let last = try! datetime(9999, 12, 31, hour=23, minute=59, second=59)
      if first.to_ordinal() > last.to_ordinal() {
        finished = true
        return None
      }
      let locator = date_locator_from_rule(rule)
      let first_date = rule.local_date(first)
      let last_date = rule.local_date(last)
      source = Some(
        recurrence_ordinals(
          locator,
          first.to_ordinal(),
          last.to_ordinal(),
          first_date,
          last_date,
        ),
      )
    }
    while true {
      match source.unwrap().next() {
        Some(ordinal) => {
          let value = match rule.timezone {
            Some(zone) =>
              zone.generated_datetime(ordinal) catch {
                _ => continue
              }
            None =>
              decoded_ordinal(
                ordinal,
                rule.dtstart.unwrap().offset_seconds,
                true,
              ) catch {
                _ => continue
              }
          }
          return Some(value)
        }
        None => {
          finished = true
          return None
        }
      }
    }
    None
  })
}

///|
/// Return whether this rule shares a lazily generated occurrence cache.
pub fn RRule::cache_enabled(self : RRule) -> Bool {
  self.cache is Some(_)
}

///|
/// Return an independent lazy reader starting at DTSTART. Native Iter supports
/// `next`, `take`, `map` and `for`. It stops at count/until or the supported
/// calendar boundary; unlike eager arrays it has no 100000 occurrence cap.
///
/// ```mbt check
/// test {
///   let rule = @date.rrule(@date.Daily, @date.datetime(2024, 1, 1), cache=true)
///   assert_eq(rule.iter().take(3).to_array().map(value => value.day()), [1, 2, 3])
///   assert_eq(rule.iter().next().unwrap().day(), 1)
/// }
/// ```
pub fn RRule::iter(self : RRule) -> Iter[DateTime] {
  let rule = self.rule
  match self.cache {
    Some(cache) => cache.iterator(() => rrule_stream(rule, None))
    None => rrule_stream(rule, None)
  }
}

///|
/// Lazily yield occurrences after an instant, including equality with `inc`.
/// An omitted count streams to the rule's natural end; nonpositive counts
/// return an empty iterator. Each call has an independent reader position.
pub fn RRule::iter_after(
  self : RRule,
  value : DateTime,
  count? : Int32,
  inc~ : Bool = false,
) -> Iter[DateTime] {
  if count is Some(limit) && limit <= 0 {
    return Iter::empty()
  }
  let target = value.to_ordinal()
  let source = match self.cache {
    Some(_) => self.iter()
    None => rrule_stream(self.rule, Some(value))
  }
  let values = source.filter(candidate => {
    if inc {
      candidate.to_ordinal() >= target
    } else {
      candidate.to_ordinal() > target
    }
  })
  match count {
    Some(limit) => values.take(limit)
    None => values
  }
}
