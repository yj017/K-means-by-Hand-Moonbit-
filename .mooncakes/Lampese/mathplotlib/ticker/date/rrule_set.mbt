///|
/// A reusable set of recurrence rules and explicit dates.
///
/// Inclusion rules and dates are merged in UTC instant order. Duplicate
/// instants are emitted once, and exclusion rules or dates remove an instant
/// from every inclusion source. Adding a source reuses the existing `RRule`
/// query implementation; the set does not duplicate recurrence generation.
pub struct RRuleSet {
  priv rules : Array[RRule]
  priv dates : Array[DateTime]
  priv exrules : Array[RRule]
  priv exdates : Array[DateTime]
  priv mut cache : RecurrenceCache?
}

///|
/// Construct an empty recurrence set. `cache=true` shares a lazy occurrence
/// prefix across readers and queries. Adding any source invalidates that prefix.
///
/// ```mbt check
/// test {
///   let values = @date.rruleset().between(
///     @date.datetime(2024, 1, 1),
///     @date.datetime(2024, 1, 2),
///     inc=true,
///   )
///   assert_eq(values.length(), 0)
/// }
/// ```
pub fn rruleset(cache~ : Bool = false) -> RRuleSet {
  {
    rules: [],
    dates: [],
    exrules: [],
    exdates: [],
    cache: recurrence_cache(cache),
  }
}

///|
/// Add an inclusive recurrence rule to the set.
pub fn RRuleSet::rrule(self : RRuleSet, rule : RRule) -> Unit {
  self.rules.push(rule)
  self.invalidate_cache()
}

///|
/// Add an inclusive explicit date to the set.
pub fn RRuleSet::rdate(self : RRuleSet, date : DateTime) -> Unit {
  self.dates.push(date)
  self.invalidate_cache()
}

///|
/// Add a recurrence rule whose occurrences are excluded from the set.
pub fn RRuleSet::exrule(self : RRuleSet, rule : RRule) -> Unit {
  self.exrules.push(rule)
  self.invalidate_cache()
}

///|
/// Add an explicit date whose instant is excluded from the set.
pub fn RRuleSet::exdate(self : RRuleSet, date : DateTime) -> Unit {
  self.exdates.push(date)
  self.invalidate_cache()
}

///|
priv struct RRuleSetCandidate {
  instant : Int64
  value : DateTime
}

///|
// Convert a DateTime to an exact UTC microsecond key. Using the integer key
// avoids treating two fixed-offset representations of one instant as distinct
// because of floating-point ordinal rounding.
fn rruleset_instant(value : DateTime) -> Int64 {
  let days = days_from_civil(value.year, value.month, value.day)
  Int64::from_int(days) * 86_400_000_000L +
  Int64::from_int(value.hour * 3600 + value.minute * 60 + value.second) *
  1_000_000L +
  Int64::from_int(value.microsecond) -
  Int64::from_int(value.offset_seconds) * 1_000_000L
}

///|
fn rruleset_unique_sorted(
  values : Array[RRuleSetCandidate],
) -> Array[RRuleSetCandidate] {
  values.sort_by_key(candidate => candidate.instant)
  let result : Array[RRuleSetCandidate] = []
  for candidate in values {
    match result.last() {
      Some(previous) if previous.instant == candidate.instant => ()
      _ => result.push(candidate)
    }
  }
  result
}

///|
/// Return occurrences between two date-times.
///
/// The bounds are exclusive by default, matching `RRule::between`; set `inc`
/// to include occurrences exactly equal to either bound. Inclusion sources
/// are merged and deduplicated before exclusion sources are applied.
// Retain the checked-query API while the validated merge itself is non-throwing.
#warnings("-unused_error_type")
pub fn RRuleSet::between(
  self : RRuleSet,
  after : DateTime,
  before : DateTime,
  inc~ : Bool = false,
) -> Array[DateTime] raise DateError {
  let upper = rruleset_instant(before)
  if rruleset_instant(after) > upper {
    return []
  }
  self
  .iter_after(after, inc~)
  .take_while(value => {
    if inc {
      rruleset_instant(value) <= upper
    } else {
      rruleset_instant(value) < upper
    }
  })
  .take(100000)
  .to_array()
}

///|
fn RRuleSet::is_excluded(
  self : RRuleSet,
  value : DateTime,
) -> Bool raise DateError {
  let instant = rruleset_instant(value)
  for date in self.exdates {
    if rruleset_instant(date) == instant {
      return true
    }
  }
  for rule in self.exrules {
    if !rule.between(value, value, inc=true).is_empty() {
      return true
    }
  }
  false
}

///|
/// Return the first occurrence after `value`, or the equal occurrence when
/// `inc` is true. Excluded candidates are skipped one instant at a time.
// Retain the checked-query API while the validated merge itself is non-throwing.
#warnings("-unused_error_type")
pub fn RRuleSet::after(
  self : RRuleSet,
  value : DateTime,
  inc~ : Bool = false,
) -> DateTime? raise DateError {
  self.iter_after(value, inc~).next()
}

///|
fn RRuleSet::previous_candidate(
  self : RRuleSet,
  value : DateTime,
  inc : Bool,
) -> DateTime? raise DateError {
  let mut result : DateTime? = None
  let mut result_instant : Int64? = None
  for rule in self.rules {
    match rule.before(value, inc~) {
      Some(candidate) => {
        let instant = rruleset_instant(candidate)
        match result_instant {
          Some(current) if instant <= current => ()
          _ => {
            result = Some(candidate)
            result_instant = Some(instant)
          }
        }
      }
      None => ()
    }
  }
  let target = rruleset_instant(value)
  for candidate in self.dates {
    let instant = rruleset_instant(candidate)
    if (inc && instant <= target) || (!inc && instant < target) {
      match result_instant {
        Some(current) if instant <= current => ()
        _ => {
          result = Some(candidate)
          result_instant = Some(instant)
        }
      }
    }
  }
  result
}

///|
/// Return the last occurrence before `value`, or the equal occurrence when
/// `inc` is true. Excluded candidates are skipped one instant at a time.
pub fn RRuleSet::before(
  self : RRuleSet,
  value : DateTime,
  inc~ : Bool = false,
) -> DateTime? raise DateError {
  if self.cache is Some(_) {
    let target = rruleset_instant(value)
    let mut result = None
    for candidate in self.iter() {
      let instant = rruleset_instant(candidate)
      if instant > target || (!inc && instant == target) {
        break
      }
      result = Some(candidate)
    }
    return result
  }
  let mut cursor = value
  let mut inclusive = inc
  for _ in 0..<100000 {
    match self.previous_candidate(cursor, inclusive) {
      Some(candidate) =>
        if self.is_excluded(candidate) {
          cursor = candidate
          inclusive = false
          continue
        } else {
          return Some(candidate)
        }
      None => return None
    }
  }
  None
}

///|
/// Return successive occurrences after `value`, up to `count` results.
///
/// With no count, the result is capped at 100000 entries. The sequence keeps
/// the same inclusion and exclusion semantics as `RRuleSet::after`.
// Retain the checked-query API while the validated merge itself is non-throwing.
#warnings("-unused_error_type")
pub fn RRuleSet::xafter(
  self : RRuleSet,
  value : DateTime,
  count? : Int32,
  inc~ : Bool = false,
) -> Array[DateTime] raise DateError {
  let limit = Int32::min(100000, count.unwrap_or(100000))
  if limit <= 0 {
    return []
  }
  self.iter_after(value, count=limit, inc~).to_array()
}

///|
/// Return all occurrences through year 9999, capped at 100000 results.
pub fn RRuleSet::all(self : RRuleSet) -> Array[DateTime] raise DateError {
  // Checked eager entry points retain DateError for unsupported UTC starts.
  for rule in self.rules {
    validate_timezone_ordinal(rule.dtstart().to_ordinal())
  }
  self.iter().take(100000).to_array()
}
