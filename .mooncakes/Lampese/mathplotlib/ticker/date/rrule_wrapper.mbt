///|
/// Mutable Matplotlib rrulewrapper. The underlying recurrence stays naive;
/// selected query methods attach the current effective timezone on return.
pub struct RRuleWrapper {
  priv base : DateTimeZone?
  priv context : DateParserContext?
  priv mut construct : WrapperOptions
  priv mut timezone : DateTimeZone?
  priv mut core : RRule
}

///|
/// Construct with optional explicit base zone and deterministic host clock.
/// dtstart may be omitted. null names pass Python-style None; null dtstart/until
/// reproduce the wrapper's checked date-normalization error. Configuration
/// arrays are retained for later set calls; core query selectors are snapshots.
/// bymonth_value/bymonthday_value retain scalar keyword forms for YearLocator.
///
/// ```mbt check
/// test {
///   let start = @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1))
///   let rule = @date.RRuleWrapper::new(@date.Daily, dtstart=start, count=3)
///   assert_eq(
///     rule.xafter(start, count=2, inc=true).map(value => value.date().day()),
///     [1, 2],
///   )
///   rule.set(interval=2)
///   assert_eq(rule.raw_iter().to_array().map(value => value.date().day()), [
///     1, 3, 5,
///   ])
/// }
/// ```
pub fn RRuleWrapper::new(
  frequency : RRuleFrequency,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  dtstart? : RRuleDateTime,
  until? : RRuleDateTime,
  interval~ : Int32 = 1,
  wkst~ : Int32 = 0,
  count? : Int32,
  bymonth? : Array[Int32],
  bymonthday? : Array[Int32],
  bymonth_value? : Int32,
  bymonthday_value? : Int32,
  byyearday? : Array[Int32],
  byweekno? : Array[Int32],
  byeaster? : Array[Int32],
  byweekday? : Array[Int32],
  byhour? : Array[Int32],
  byminute? : Array[Int32],
  bysecond? : Array[Int32],
  bysetpos? : Array[Int32],
  byweekdays? : Array[RelativeWeekday],
  cache~ : Bool = false,
  null~ : Array[String] = [],
) -> RRuleWrapper raise DateError {
  if (bymonth is Some(_) && bymonth_value is Some(_)) ||
    (bymonthday is Some(_) && bymonthday_value is Some(_)) {
    raise DateError::InvalidDate(
      message="use array or scalar month/day keyword, not both",
    )
  }
  let options : WrapperOptions = {
    frequency,
    interval,
    wkst,
    dtstart: wrapper_date_option(dtstart),
    until: wrapper_date_option(until),
    count,
    cache,
    bymonth_form: match bymonth_value {
      Some(value) => ScalarCalendar(value)
      None => if bymonth is Some(_) { ArrayCalendar } else { OmittedCalendar }
    },
    bymonthday_form: match bymonthday_value {
      Some(value) => ScalarCalendar(value)
      None =>
        if bymonthday is Some(_) {
          ArrayCalendar
        } else {
          OmittedCalendar
        }
    },
    bymonth: match bymonth_value {
      Some(value) => Some([value])
      None => bymonth
    },
    bymonthday: match bymonthday_value {
      Some(value) => Some([value])
      None => bymonthday
    },
    byyearday,
    byweekno,
    byeaster,
    byweekday,
    byhour,
    byminute,
    bysecond,
    bysetpos,
    byweekdays,
  }
  let (construct, effective) = options.with_null(null).normalized(timezone)
  let core = construct.build_rule(context)
  { base: timezone, context, construct, timezone: effective, core, }
}

///|
/// Update the stored construction arguments and rebuild the naive recurrence.
/// Follows the original failure stages: normalization can leave new arguments;
/// a later core error can also leave new timezone metadata with the old rule.
pub fn RRuleWrapper::set(
  self : RRuleWrapper,
  frequency? : RRuleFrequency,
  dtstart? : RRuleDateTime,
  until? : RRuleDateTime,
  interval? : Int32,
  wkst? : Int32,
  count? : Int32,
  bymonth? : Array[Int32],
  bymonthday? : Array[Int32],
  bymonth_value? : Int32,
  bymonthday_value? : Int32,
  byyearday? : Array[Int32],
  byweekno? : Array[Int32],
  byeaster? : Array[Int32],
  byweekday? : Array[Int32],
  byhour? : Array[Int32],
  byminute? : Array[Int32],
  bysecond? : Array[Int32],
  bysetpos? : Array[Int32],
  byweekdays? : Array[RelativeWeekday],
  cache? : Bool,
  null~ : Array[String] = [],
) -> Unit raise DateError {
  let previous = self.construct
  if (bymonth is Some(_) && bymonth_value is Some(_)) ||
    (bymonthday is Some(_) && bymonthday_value is Some(_)) {
    raise DateError::InvalidDate(
      message="use array or scalar month/day keyword, not both",
    )
  }
  let options : WrapperOptions = {
    frequency: frequency.unwrap_or(previous.frequency),
    interval: interval.unwrap_or(previous.interval),
    wkst: wkst.unwrap_or(previous.wkst),
    dtstart: match dtstart {
      Some(value) => DateValue(value)
      None => previous.dtstart
    },
    until: match until {
      Some(value) => DateValue(value)
      None => previous.until
    },
    count: relative_prefer(count, previous.count),
    cache: cache.unwrap_or(previous.cache),
    bymonth_form: match bymonth_value {
      Some(value) => ScalarCalendar(value)
      None =>
        if bymonth is Some(_) {
          ArrayCalendar
        } else {
          previous.bymonth_form
        }
    },
    bymonthday_form: match bymonthday_value {
      Some(value) => ScalarCalendar(value)
      None =>
        if bymonthday is Some(_) {
          ArrayCalendar
        } else {
          previous.bymonthday_form
        }
    },
    bymonth: match bymonth_value {
      Some(value) => Some([value])
      None => relative_prefer(bymonth, previous.bymonth)
    },
    bymonthday: match bymonthday_value {
      Some(value) => Some([value])
      None => relative_prefer(bymonthday, previous.bymonthday)
    },
    byyearday: relative_prefer(byyearday, previous.byyearday),
    byweekno: relative_prefer(byweekno, previous.byweekno),
    byeaster: relative_prefer(byeaster, previous.byeaster),
    byweekday: if byweekdays is Some(_) && byweekday is None {
      None
    } else {
      relative_prefer(byweekday, previous.byweekday)
    },
    byhour: relative_prefer(byhour, previous.byhour),
    byminute: relative_prefer(byminute, previous.byminute),
    bysecond: relative_prefer(bysecond, previous.bysecond),
    bysetpos: relative_prefer(bysetpos, previous.bysetpos),
    byweekdays: if byweekday is Some(_) && byweekdays is None {
      None
    } else {
      relative_prefer(byweekdays, previous.byweekdays)
    },
  }
  self.construct = options.with_null(null)
  let (construct, effective) = self.construct.normalized(self.base)
  self.construct = construct
  self.timezone = effective
  self.core = construct.build_rule(self.context)
}

///|
/// Independent construction arrays and empty cache; base/context handles are
/// retained. This explicit copy is a typed snapshot, including failed-set state.
pub fn RRuleWrapper::copy(self : RRuleWrapper) -> RRuleWrapper {
  {
    ..self,
    construct: self.construct.snapshot(),
    core: {
      rule: self.core.rule,
      cache: recurrence_cache(self.core.cache_enabled()),
    },
  }
}

///|
pub fn RRuleWrapper::timezone(self : RRuleWrapper) -> DateTimeZone? {
  self.timezone
}

///|
pub fn RRuleWrapper::base_timezone(self : RRuleWrapper) -> DateTimeZone? {
  self.base
}

///|
pub fn RRuleWrapper::frequency(self : RRuleWrapper) -> RRuleFrequency {
  self.core.frequency()
}

///|
pub fn RRuleWrapper::interval(self : RRuleWrapper) -> Int32 {
  self.core.interval()
}

///|
pub fn RRuleWrapper::cache_enabled(self : RRuleWrapper) -> Bool {
  self.core.cache_enabled()
}

///|
pub fn RRuleWrapper::dtstart(self : RRuleWrapper) -> RRuleDateTime {
  RRuleDateTime::naive(self.core.dtstart())
}

///|
pub fn RRuleWrapper::until(self : RRuleWrapper) -> RRuleDateTime? {
  self.core.until().map(RRuleDateTime::naive)
}

///|
pub fn RRuleWrapper::count_limit(self : RRuleWrapper) -> Int32? {
  self.core.count()
}

///|
/// Snapshot of the underlying naive recurrence. Public RRule ordinal adapters
/// retain their existing behavior; raw_iter provides an epoch-free date stream.
pub fn RRuleWrapper::raw_rule(self : RRuleWrapper) -> RRule {
  self.core
}

///|
fn RRuleWrapper::naive_reader(
  self : RRuleWrapper,
  lower? : DateTime,
  upper? : DateTime,
) -> Iter[DateTime] {
  let core = self.core
  match core.cache {
    Some(cache) => cache.iterator(() => rrule_naive_stream(core.rule))
    None => rrule_naive_stream(core.rule, lower?, upper?)
  }
}

///|
/// Explicit access to a native, nonraising Iter snapshot of naive dates.
/// checked_raw_iter() preserves checked iteration errors; this legacy extension
/// represents unreachable clock masks as an empty stream.
pub fn RRuleWrapper::raw_iter(self : RRuleWrapper) -> Iter[RRuleDateTime] {
  self.naive_reader().map(RRuleDateTime::naive)
}

///|
/// Count the underlying recurrence to its natural end, preserving cache behavior.
/// Unreachable cross-field clock masks raise as the source count() does.
pub fn RRuleWrapper::occurrence_count(
  self : RRuleWrapper,
) -> Int64 raise DateError {
  let mut count = 0L
  let reader = self.checked_reader()
  while reader.next_date() is Some(_) {
    count += 1L
  }
  count
}
