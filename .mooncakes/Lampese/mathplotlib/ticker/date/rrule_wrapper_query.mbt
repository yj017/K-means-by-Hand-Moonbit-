///|
fn RRuleWrapper::normalize_query(
  self : RRuleWrapper,
  value : RRuleDateTime,
) -> RRuleDateTime raise DateError {
  match self.timezone {
    Some(zone) => RRuleDateTime::naive(value.wall_in(zone))
    None => value
  }
}

///|
fn wrapper_compare(
  candidate : DateTime,
  target : RRuleDateTime,
) -> Int64 raise DateError {
  if !target.is_naive() {
    raise DateError::InvalidDate(
      message="cannot compare an aware argument with a naive recurrence",
    )
  }
  locator_microseconds(candidate) - locator_microseconds(target.value)
}

///|
fn RRuleWrapper::return_one(
  self : RRuleWrapper,
  value : DateTime?,
) -> RRuleDateTime? raise DateError {
  match value {
    Some(value) => Some(attach_rule_timezone(value, self.timezone))
    None if self.timezone is Some(_) =>
      raise DateError::InvalidDate(
        message="aware recurrence query returned no datetime to attach",
      )
    None => None
  }
}

///|
/// First recurrence after a date, or at the date when inc=true. An aware
/// wrapper raises when no match exists, matching the original attach(None).
pub fn RRuleWrapper::after(
  self : RRuleWrapper,
  value : RRuleDateTime,
  inc~ : Bool = false,
) -> RRuleDateTime? raise DateError {
  let query = self.normalize_query(value)
  let lower = if query.is_naive() { Some(query.value) } else { None }
  let reader = self.checked_reader(lower?)
  while reader.next_date() is Some(candidate) {
    let comparison = wrapper_compare(candidate, query)
    if comparison > 0L || (inc && comparison == 0L) {
      return self.return_one(Some(candidate))
    }
  }
  self.return_one(None)
}

///|
/// Eager typed xafter companion. It attaches the effective zone when present;
/// raw_iter exposes the underlying naive stream. Eager arrays stop at 100000.
pub fn RRuleWrapper::xafter(
  self : RRuleWrapper,
  value : RRuleDateTime,
  count? : Int32,
  inc~ : Bool = false,
) -> Array[RRuleDateTime] raise DateError {
  let query = self.normalize_query(value)
  let lower = if query.is_naive() { Some(query.value) } else { None }
  let result : Array[RRuleDateTime] = []
  let mut seen = 0L
  let reader = self.checked_reader(lower?)
  while reader.next_date() is Some(candidate) {
    let comparison = wrapper_compare(candidate, query)
    if comparison > 0L || (inc && comparison == 0L) {
      seen += 1L
      if count is Some(count) && seen > Int64::from_int(count) {
        break
      }
      result.push(attach_rule_timezone(candidate, self.timezone))
      if result.length() >= 100000 {
        break
      }
    }
  }
  result
}

///|
/// Recurrences between local-normalized bounds. Both ends are exclusive by
/// default. The underlying comparison order is before, then after.
pub fn RRuleWrapper::between(
  self : RRuleWrapper,
  after : RRuleDateTime,
  before : RRuleDateTime,
  inc~ : Bool = false,
) -> Array[RRuleDateTime] raise DateError {
  let lower = self.normalize_query(after)
  let upper = self.normalize_query(before)
  let (first, last) = if lower.is_naive() && upper.is_naive() {
    (Some(lower.value), Some(upper.value))
  } else {
    (None, None)
  }
  let result : Array[RRuleDateTime] = []
  let reader = self.checked_reader(lower?=first, upper?=last)
  while reader.next_date() is Some(candidate) {
    let last_comparison = wrapper_compare(candidate, upper)
    if last_comparison > 0L || (!inc && last_comparison == 0L) {
      break
    }
    let first_comparison = wrapper_compare(candidate, lower)
    if first_comparison > 0L || (inc && first_comparison == 0L) {
      result.push(attach_rule_timezone(candidate, self.timezone))
      if result.length() >= 100000 {
        break
      }
    }
  }
  result
}

///|
fn RRuleWrapper::find_naive_before(
  self : RRuleWrapper,
  value : RRuleDateTime,
  inc : Bool,
) -> DateTime? raise DateError {
  let target = locator_microseconds(value.value)
  let start = locator_microseconds(self.core.dtstart())
  if target < start {
    return None
  }
  let mut span = Int64::from_int(self.core.before_probe_days()) * 86400000000L
  while true {
    let first = Int64::max(start, target - span)
    let lower = locator_datetime_microseconds(first, 0)
    let mut result : DateTime? = None
    let reader = self.checked_reader(lower~, upper=value.value)
    while reader.next_date() is Some(candidate) {
      let comparison = wrapper_compare(candidate, value)
      if comparison > 0L || (!inc && comparison == 0L) {
        break
      }
      result = Some(candidate)
    }
    if result is Some(_) || first <= start {
      return result
    }
    span = Int64::min(315537897600000000L, span * 2L)
  }
  None
}

///|
pub fn RRuleWrapper::before(
  self : RRuleWrapper,
  value : RRuleDateTime,
  inc~ : Bool = false,
) -> RRuleDateTime? raise DateError {
  let query = self.normalize_query(value)
  // The optimized before path can return without reading any candidate.
  self.core.check_clock_iteration()
  if query.is_naive() && self.core.rule.count is None && self.core.cache is None {
    return self.return_one(self.find_naive_before(query, inc))
  }
  let mut result : DateTime? = None
  let reader = self.checked_reader()
  while reader.next_date() is Some(candidate) {
    let comparison = wrapper_compare(candidate, query)
    if comparison > 0L || (!inc && comparison == 0L) {
      break
    }
    result = Some(candidate)
  }
  self.return_one(result)
}
