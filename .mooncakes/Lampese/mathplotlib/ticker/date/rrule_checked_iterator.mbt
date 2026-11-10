///|
/// Lazy naive recurrence snapshot with checked reads. The first next() may
/// report an unreachable clock cycle; a failed or exhausted reader then ends.
pub struct RRuleDateIterator {
  priv core : RRule
  priv source : Iter[DateTime]
  priv mut checked : Bool
  priv mut finished : Bool
}

///|
fn RRule::check_clock_iteration(self : RRule) -> Unit raise DateError {
  let unit = match self.rule.frequency {
    Minutely => 60
    Secondly => 1
    _ => return
  }
  if recurrence_clock_slots(self.rule, self.dtstart(), unit).next() is None {
    raise DateError::InvalidDate(
      message="recurrence has no reachable clock cycle",
    )
  }
}

///|
fn RRuleWrapper::checked_reader(
  self : RRuleWrapper,
  lower? : DateTime,
  upper? : DateTime,
) -> RRuleDateIterator {
  {
    core: self.core,
    source: self.naive_reader(lower?, upper?),
    checked: false,
    finished: false,
  }
}

///|
fn RRuleDateIterator::next_date(
  self : RRuleDateIterator,
) -> DateTime? raise DateError {
  if self.finished {
    return None
  }
  if !self.checked {
    self.checked = true
    errdefer {
      self.finished = true
    }
    self.core.check_clock_iteration()
  }
  match self.source.next() {
    Some(value) => Some(value)
    None => {
      self.finished = true
      None
    }
  }
}

///|
/// Read the next naive date. Creating the reader performs no clock/epoch access
/// and does not raise an iteration error. A read error terminates this reader.
pub fn RRuleDateIterator::next(
  self : RRuleDateIterator,
) -> RRuleDateTime? raise DateError {
  self.next_date().map(RRuleDateTime::naive)
}

///|
/// Snapshot the successful core and its existing cache, deferring validation to
/// next(). Later wrapper.set calls do not change this reader's recurrence.
///
/// ```mbt check
/// test {
///   let rule = @date.RRuleWrapper::new(
///     @date.Minutely,
///     dtstart=@date.RRuleDateTime::naive(@date.datetime(2024, 1, 1, hour=12)),
///     interval=1440,
///     byhour=[12],
///     byminute=[0],
///     count=2,
///     cache=true,
///   )
///   let reader = rule.checked_raw_iter()
///   assert_eq(reader.next().unwrap().date().day(), 1)
///   rule.set(byhour=[13])
///   assert_eq(reader.next().unwrap().date().day(), 2)
///   assert_true(
///     try {
///       ignore(rule.occurrence_count())
///       false
///     } catch {
///       _ => true
///     },
///   )
/// }
/// ```
pub fn RRuleWrapper::checked_raw_iter(self : RRuleWrapper) -> RRuleDateIterator {
  self.checked_reader()
}
