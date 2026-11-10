///|
/// Calendar frequencies used by `rrule_locator` (from years to seconds).
pub(all) enum RRuleFrequency {
  Yearly
  Monthly
  Weekly
  Daily
  Hourly
  Minutely
  Secondly
}

///|
// Normalized selector arrays are private and never exposed to callers.
priv struct DateRule {
  frequency : RRuleFrequency
  interval : Int32
  wkst : Int32
  dtstart : DateTime?
  count : Int32?
  until : DateTime?
  bymonth : Array[Int32]?
  bymonthday : Array[Int32]?
  byyearday : Array[Int32]?
  byweekno : Array[Int32]?
  byeaster : Array[Int32]?
  byweekday : Array[Int32]?
  bynweekday : Array[RelativeWeekday]?
  byhour : Array[Int32]?
  byminute : Array[Int32]?
  bysecond : Array[Int32]?
  bysetpos : Array[Int32]?
  timezone : DateTimeZone?
}

///|
/// A reusable recurrence rule with a concrete start date.
///
/// `RRule` mirrors the query-oriented part of `dateutil.rrule`: construct a
/// rule once, then ask for occurrences in a bounded interval. The locator
/// adapter remains available when the rule is attached to an axis.
pub struct RRule {
  priv rule : DateRule
  priv cache : RecurrenceCache?
}

///|
/// Return a copy whose recurrence fields are interpreted in a transition-aware
/// local timezone. Calendar candidates are still generated in local time;
/// emitted ticks remain UTC Matplotlib ordinals. The cache setting is preserved
/// with a new empty prefix.
///
/// ```mbt check
/// test {
///   let zone = try! @date.timezone(-300, transitions=[
///     try! @date.timezone_transition(@date.datetime(2024, 3, 10, hour=7), -240),
///   ])
///   let rule = try! @date.rrule(
///     @date.RRuleFrequency::Daily,
///     @date.datetime(2024, 3, 9, hour=2, offset_minutes=-300),
///     byhour=[2],
///   ).with_timezone(zone)
///   assert_eq(rule.locator().offset_minutes(), -300)
/// }
/// ```
pub fn RRule::with_timezone(self : RRule, timezone : DateTimeZone) -> RRule {
  {
    rule: self.rule.with_timezone(timezone),
    cache: recurrence_cache(self.cache_enabled()),
  }
}

///|
/// Construct a reusable recurrence rule with an explicit `dtstart`.
///
/// Keeping the start date required makes object queries deterministic. The
/// locator adapter remains available through `RRule::locator` when a rule is
/// used to generate axis ticks. Selector arrays are copied, sorted, and
/// deduplicated during construction, so callers can safely reuse or mutate
/// their input arrays afterwards. `cache=true` shares an incrementally generated
/// occurrence prefix between queries and readers; the default is uncached.
pub fn rrule(
  frequency : RRuleFrequency,
  dtstart : DateTime,
  interval~ : Int32 = 1,
  wkst~ : Int32 = 0,
  bymonth? : Array[Int32],
  bymonthday? : Array[Int32],
  byyearday? : Array[Int32],
  byweekno? : Array[Int32],
  byeaster? : Array[Int32],
  byweekday? : Array[Int32],
  byhour? : Array[Int32],
  byminute? : Array[Int32],
  bysecond? : Array[Int32],
  bysetpos? : Array[Int32],
  count? : Int32,
  until? : DateTime,
  cache~ : Bool = false,
) -> RRule raise DateError {
  {
    rule: make_date_rule(
      frequency,
      interval,
      wkst,
      bymonth,
      bymonthday,
      byyearday,
      byweekno,
      byeaster,
      byweekday,
      byhour,
      byminute,
      bysecond,
      bysetpos,
      Some(dtstart),
      count,
      until,
    ),
    cache: recurrence_cache(cache),
  }
}

///|
/// Return the axis locator represented by this rule.
pub fn RRule::locator(self : RRule) -> DateLocator {
  date_locator_from_rule(self.rule)
}

///|
/// Return the recurrence frequency.
pub fn RRule::frequency(self : RRule) -> RRuleFrequency {
  self.rule.frequency
}

///|
/// Return the positive calendar or clock interval.
pub fn RRule::interval(self : RRule) -> Int32 {
  self.rule.interval
}

///|
/// Return the week-start selector (Monday=0 through Sunday=6).
pub fn RRule::wkst(self : RRule) -> Int32 {
  self.rule.wkst
}

///|
/// Return the recurrence start date.
pub fn RRule::dtstart(self : RRule) -> DateTime {
  self.rule.dtstart.unwrap()
}

///|
/// Return the optional occurrence limit.
pub fn RRule::count(self : RRule) -> Int32? {
  self.rule.count
}

///|
/// Return the inclusive upper date-time bound, when configured.
pub fn RRule::until(self : RRule) -> DateTime? {
  self.rule.until
}

///|
/// Return a copy whose recurrence dates use a fixed UTC offset.
/// The cache setting is preserved, with independent empty cache state.
pub fn RRule::with_offset(
  self : RRule,
  offset_minutes : Int32,
) -> RRule raise DateError {
  {
    rule: self.rule.with_offset(offset_minutes),
    cache: recurrence_cache(self.cache_enabled()),
  }
}

///|
/// Return a rule with selected fields replaced.
///
/// Omitted fields keep their current values. Selector arrays are copied and
/// validated again, so the returned rule is independent of both the original
/// rule and the caller's arrays. Pass selector names through `clear` to remove
/// an existing selector before applying replacements. This typed form covers
/// the common immutable `dateutil.rrule.replace` workflow while keeping the
/// clear operation explicit in MoonBit's optional-argument type system.
/// The cache setting is retained unless replaced; a fresh cache is always used.
pub fn RRule::replace(
  self : RRule,
  frequency? : RRuleFrequency,
  dtstart? : DateTime,
  interval? : Int32,
  wkst? : Int32,
  bymonth? : Array[Int32],
  bymonthday? : Array[Int32],
  byyearday? : Array[Int32],
  byweekno? : Array[Int32],
  byeaster? : Array[Int32],
  byweekday? : Array[Int32],
  byhour? : Array[Int32],
  byminute? : Array[Int32],
  bysecond? : Array[Int32],
  bysetpos? : Array[Int32],
  count? : Int32,
  until? : DateTime,
  clear~ : Array[String] = [],
  cache? : Bool,
) -> RRule raise DateError {
  for selector in clear {
    if selector != "bymonth" &&
      selector != "bymonthday" &&
      selector != "byyearday" &&
      selector != "byweekno" &&
      selector != "byeaster" &&
      selector != "byweekday" &&
      selector != "byhour" &&
      selector != "byminute" &&
      selector != "bysecond" &&
      selector != "bysetpos" {
      raise DateError::InvalidDate(
        message="unknown rrule selector to clear: {selector}",
      )
    }
  }
  let clear_bymonth = clear.contains("bymonth")
  let clear_bymonthday = clear.contains("bymonthday")
  let clear_byyearday = clear.contains("byyearday")
  let clear_byweekno = clear.contains("byweekno")
  let clear_byeaster = clear.contains("byeaster")
  let clear_byweekday = clear.contains("byweekday")
  let clear_byhour = clear.contains("byhour")
  let clear_byminute = clear.contains("byminute")
  let clear_bysecond = clear.contains("bysecond")
  let clear_bysetpos = clear.contains("bysetpos")
  let next_frequency = match frequency {
    Some(value) => value
    None => self.rule.frequency
  }
  let next_dtstart = match dtstart {
    Some(value) => value
    None => self.dtstart()
  }
  let next_interval = match interval {
    Some(value) => value
    None => self.rule.interval
  }
  let next_wkst = match wkst {
    Some(value) => value
    None => self.rule.wkst
  }
  let next_bymonth = if clear_bymonth {
    match bymonth {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match bymonth {
      Some(value) => Some(value)
      None => self.rule.bymonth
    }
  }
  let next_bymonthday = if clear_bymonthday {
    match bymonthday {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match bymonthday {
      Some(value) => Some(value)
      None => self.rule.bymonthday
    }
  }
  let next_byyearday = if clear_byyearday {
    match byyearday {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match byyearday {
      Some(value) => Some(value)
      None => self.rule.byyearday
    }
  }
  let next_byweekno = if clear_byweekno {
    match byweekno {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match byweekno {
      Some(value) => Some(value)
      None => self.rule.byweekno
    }
  }
  let next_byeaster = if clear_byeaster {
    match byeaster {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match byeaster {
      Some(value) => Some(value)
      None => self.rule.byeaster
    }
  }
  let next_byweekday = if clear_byweekday {
    match byweekday {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match byweekday {
      Some(value) => Some(value)
      None => self.rule.byweekday
    }
  }
  let next_byhour = if clear_byhour {
    match byhour {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match byhour {
      Some(value) => Some(value)
      None => self.rule.byhour
    }
  }
  let next_byminute = if clear_byminute {
    match byminute {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match byminute {
      Some(value) => Some(value)
      None => self.rule.byminute
    }
  }
  let next_bysecond = if clear_bysecond {
    match bysecond {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match bysecond {
      Some(value) => Some(value)
      None => self.rule.bysecond
    }
  }
  let next_bysetpos = if clear_bysetpos {
    match bysetpos {
      Some(value) => Some(value)
      None => None
    }
  } else {
    match bysetpos {
      Some(value) => Some(value)
      None => self.rule.bysetpos
    }
  }
  let next_count = match count {
    Some(value) => Some(value)
    None => self.rule.count
  }
  let next_until = match until {
    Some(value) => Some(value)
    None => self.rule.until
  }
  let validated_count = if count is None &&
    next_count is Some(value) &&
    value <= 0 {
    None
  } else {
    next_count
  }
  let next_rule = make_date_rule(
    next_frequency,
    next_interval,
    next_wkst,
    next_bymonth,
    next_bymonthday,
    next_byyearday,
    next_byweekno,
    next_byeaster,
    next_byweekday,
    next_byhour,
    next_byminute,
    next_bysecond,
    next_bysetpos,
    Some(next_dtstart),
    validated_count,
    next_until,
  )
  let retained_ordinal = if clear_byweekday || byweekday is Some(_) {
    None
  } else {
    self.rule.bynweekday
  }
  let mut next_rule = {
    ..next_rule,
    count: next_count,
    bynweekday: retained_ordinal,
  }
  if !(next_frequency is Yearly || next_frequency is Monthly) &&
    retained_ordinal is Some(values) {
    let plain = next_rule.byweekday.unwrap_or([]).copy()
    for value in values {
      if !plain.contains(value.weekday) {
        plain.push(value.weekday)
      }
    }
    plain.sort()
    next_rule = { ..next_rule, byweekday: Some(plain), bynweekday: None, }
  }
  let next_rule = match self.rule.timezone {
    Some(timezone) => next_rule.with_timezone(timezone)
    None => next_rule
  }
  {
    rule: next_rule,
    cache: recurrence_cache(cache.unwrap_or(self.cache_enabled())),
  }
}

///|
fn RRule::query(
  self : RRule,
  first : DateTime,
  last : DateTime,
) -> Array[Double] {
  if self.cache is Some(_) {
    let first_ordinal = first.to_ordinal()
    let last_ordinal = last.to_ordinal()
    if first_ordinal > last_ordinal {
      return []
    }
    let result : Array[Double] = []
    for value in self.iter() {
      let ordinal = value.to_ordinal()
      if ordinal > last_ordinal {
        break
      }
      if ordinal >= first_ordinal {
        result.push(ordinal)
        if result.length() >= 100000 {
          break
        }
      }
    }
    return result
  }
  let locator = date_locator_from_rule(self.rule)
  // DateTime already represents an instant. A transition-aware timezone is
  // used only to choose the local calendar fields for generation; converting
  // the query value back through `timezone.to_ordinal` would reinterpret its
  // fields as local time and shift the query window.
  let first_ordinal = first.to_ordinal()
  let last_ordinal = last.to_ordinal()
  if first_ordinal > last_ordinal {
    return []
  }
  let first_date = self.rule.local_date(first)
  let last_date = self.rule.local_date(last)
  recurrence_ticks(locator, first_ordinal, last_ordinal, first_date, last_date)
}

///|
fn RRule::value_to_datetime(
  self : RRule,
  value : Double,
) -> DateTime raise DateError {
  match self.rule.timezone {
    Some(timezone) => timezone.generated_datetime(value)
    None => decoded_ordinal(value, self.dtstart().offset_seconds(), true)
  }
}

///|
// A DateTime query already carries an absolute instant. Keep it exact while
// choosing generation fields instead of round-tripping through public ordinals.
fn DateRule::local_date(self : DateRule, value : DateTime) -> DateTime {
  match self.timezone {
    Some(timezone) => value.with_timezone(timezone) catch { _ => value }
    None =>
      value.with_offset_seconds(self.dtstart.unwrap_or(value).offset_seconds) catch {
        _ => value
      }
  }
}

///|
// Keep reverse queries below the recurrence safety cap for dense clock rules,
// then widen the window when selectors make the rule sparse.
fn RRule::before_probe_days(self : RRule) -> Int32 {
  match self.rule.frequency {
    Secondly => 1
    Minutely => 7
    Hourly => 31
    Daily => 366
    Weekly => 366 * 4
    Monthly => 366 * 8
    Yearly => 366 * 64
  }
}

///|
fn RRule::find_before(
  self : RRule,
  value : DateTime,
  inc : Bool,
) -> DateTime? raise DateError {
  let start = self.dtstart()
  let target = value.to_ordinal()
  if target < start.to_ordinal() {
    return None
  }
  let mut span = self.before_probe_days().to_double()
  let mut attempts = 0
  while attempts < 32 {
    let lower_ordinal = Double::max(start.to_ordinal(), target - span)
    let lower = decoded_ordinal(lower_ordinal, start.offset_seconds(), true)
    let values = self.query(lower, value)
    let mut index = values.length() - 1
    while index >= 0 {
      let occurrence = values[index]
      if (inc && occurrence <= target) || (!inc && occurrence < target) {
        return Some(self.value_to_datetime(occurrence))
      }
      index -= 1
    }
    if lower_ordinal <= start.to_ordinal() {
      return None
    }
    span = span * 2.0
    attempts += 1
  }
  None
}

///|
/// Return occurrences between two date-times.
///
/// The bounds are exclusive by default, matching `dateutil.rrule`. Set
/// `inc` to include occurrences exactly equal to either bound. An inverted
/// interval returns an empty array.
pub fn RRule::between(
  self : RRule,
  after : DateTime,
  before : DateTime,
  inc~ : Bool = false,
) -> Array[DateTime] raise DateError {
  let lower = after.to_ordinal()
  let upper = before.to_ordinal()
  if lower > upper {
    return []
  }
  let values = self.query(after, before)
  let result : Array[DateTime] = []
  for value in values {
    if (inc || value > lower) && (inc || value < upper) {
      result.push(self.value_to_datetime(value))
    }
  }
  result
}

///|
/// Return the first occurrence after `value`, or the equal occurrence when
/// `inc` is true. The search is bounded by the supported Gregorian range.
// Preserve the existing checked-query signature while using a validated lazy source.
#warnings("-unused_error_type")
pub fn RRule::after(
  self : RRule,
  value : DateTime,
  inc~ : Bool = false,
) -> DateTime? raise DateError {
  self.iter_after(value, inc~).next()
}

///|
/// Return successive occurrences after `value`.
///
/// This eager array form covers the useful query semantics of
/// `dateutil.rrule.xafter`; an omitted `count` is capped at 100000 results.
// Preserve the existing checked-query signature while using a validated lazy source.
#warnings("-unused_error_type")
pub fn RRule::xafter(
  self : RRule,
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
/// Return the last occurrence before `value`, or the equal occurrence when
/// `inc` is true. The search is bounded by the supported Gregorian range.
pub fn RRule::before(
  self : RRule,
  value : DateTime,
  inc~ : Bool = false,
) -> DateTime? raise DateError {
  if value.to_ordinal() < self.dtstart().to_ordinal() {
    return None
  }
  if self.rule.count is None && self.cache is None {
    return self.find_before(value, inc)
  }
  let target = value.to_ordinal()
  let mut result = None
  for candidate in self.iter() {
    let ordinal = candidate.to_ordinal()
    if ordinal > target || (!inc && ordinal == target) {
      break
    }
    result = Some(candidate)
  }
  result
}

///|
/// Return all occurrences from `dtstart` through year 9999.
///
/// Results are capped at 100000 occurrences, the same safety limit used by
/// `DateLocator::tick_values`. Rules without `count` or `until` can therefore
/// represent an unbounded recurrence while keeping this eager query finite.
pub fn RRule::all(self : RRule) -> Array[DateTime] raise DateError {
  validate_timezone_ordinal(self.dtstart().to_ordinal())
  self.iter().take(100000).to_array()
}

///|
fn make_date_rule(
  frequency : RRuleFrequency,
  interval : Int32,
  wkst : Int32,
  bymonth : Array[Int32]?,
  bymonthday : Array[Int32]?,
  byyearday : Array[Int32]?,
  byweekno : Array[Int32]?,
  byeaster : Array[Int32]?,
  byweekday : Array[Int32]?,
  byhour : Array[Int32]?,
  byminute : Array[Int32]?,
  bysecond : Array[Int32]?,
  bysetpos : Array[Int32]?,
  dtstart : DateTime?,
  count : Int32?,
  until : DateTime?,
) -> DateRule raise DateError {
  if count is Some(value) && value <= 0 {
    raise DateError::InvalidDate(message="rrule count must be positive")
  }
  {
    frequency,
    interval: positive_interval(interval),
    wkst: weekday_selector(wkst),
    dtstart,
    count,
    until,
    bymonth: locator_selection(None, bymonth, None, None, month_selector),
    bymonthday: locator_selection(
      None,
      bymonthday,
      None,
      None,
      monthday_selector,
    ),
    byyearday: locator_selection(None, byyearday, None, None, yearday_selector),
    byweekno: locator_selection(None, byweekno, None, None, weekno_selector),
    byeaster: locator_selection(
      None,
      byeaster,
      None,
      None,
      easter_offset_selector,
    ),
    byweekday: locator_selection(None, byweekday, None, None, weekday_selector),
    bynweekday: None,
    byhour: locator_selection(None, byhour, None, None, hour_selector),
    byminute: locator_selection(
      None,
      byminute,
      None,
      None,
      minute_or_second_selector,
    ),
    bysecond: locator_selection(
      None,
      bysecond,
      None,
      None,
      minute_or_second_selector,
    ),
    bysetpos: locator_selection(None, bysetpos, None, None, recurrence_position),
    timezone: None,
  }
}

///|
fn date_locator_from_rule(rule : DateRule) -> DateLocator {
  {
    kind: Recurrence,
    interval: rule.interval,
    selector: 0,
    secondary: 0,
    selector_enabled: false,
    offset_minutes: match rule.dtstart {
      Some(value) => value.offset_minutes()
      None => 0
    },
    timezone: match rule.timezone {
      Some(zone) => Some(zone)
      None =>
        match rule.dtstart {
          Some(start) if start.offset_seconds % 60 != 0 =>
            Some(try! fixed_timezone_seconds(start.offset_seconds))
          _ => None
        }
    },
    selection: None,
    secondary_selection: None,
    holidays: [],
    rule: Some(rule),
    automatic: None,
    wrapper_locator: None,
    microsecond_object: None,
  }
}

///|
/// Locate dates with a calendar recurrence rule.
///
/// Arrays are copied, sorted and deduplicated; empty or invalid selectors raise
/// `DateError`. `bymonthday` counts from either end of the month (-1 is the last
/// day). `byweekday` and the week start `wkst` use Monday=0 through Sunday=6.
/// `byyearday` counts from January 1 (`-1` is December 31), `byweekno`
/// follows the configurable week start, and `byeaster` selects days relative
/// to Western Easter (zero is Easter Sunday).
/// `bysetpos` selects positions within each recurrence period after all other
/// filters and expansions, before clipping to the visible range.
/// `dtstart` supplies the recurrence start used for filtering and counting;
/// when omitted, the locator keeps Matplotlib's visible-window anchor. `count`
/// limits the number of occurrences from that start, and `until` is an
/// inclusive date-time bound. Supplying either bound with no explicit
/// `dtstart` uses the Matplotlib anchor as the start.
///
/// Like Matplotlib's `RRuleLocator`, the anchor is the lower bound minus the
/// calendar difference between the bounds. Omitted clock fields below the
/// frequency inherit this anchor's fields; recurrence ticks have zero
/// microseconds. With no day selector, yearly/monthly rules inherit its day,
/// yearly rules also inherit its month if omitted, and weekly rules inherit
/// its weekday. Other omitted selectors allow all values.
///
/// The interval advances calendar units before filtering. Use `with_offset`
/// for a fixed UTC offset; emitted numeric ticks remain UTC day ordinals.
///
/// ```mbt check
/// test {
///   let locator = @date.rrule_locator(
///     @date.Monthly,
///     byweekday=[0, 1, 2, 3, 4],
///     bysetpos=[-1],
///     byhour=[0],
///     byminute=[0],
///     bysecond=[0],
///   )
///   let ticks = locator.tick_values(
///     @date.datetime(2024, 1, 1).to_ordinal(),
///     @date.datetime(2024, 3, 31).to_ordinal(),
///   )
///   assert_eq(@date.format_date_ticks(ticks, format="%Y-%m-%d"), [
///     "2024-01-31", "2024-02-29", "2024-03-29",
///   ])
/// }
/// ```
pub fn rrule_locator(
  frequency : RRuleFrequency,
  tz? : String,
  timezone? : DateTimeZone,
  interval~ : Int32 = 1,
  wkst~ : Int32 = 0,
  bymonth? : Array[Int32],
  bymonthday? : Array[Int32],
  byyearday? : Array[Int32],
  byweekno? : Array[Int32],
  byeaster? : Array[Int32],
  byweekday? : Array[Int32],
  byhour? : Array[Int32],
  byminute? : Array[Int32],
  bysecond? : Array[Int32],
  bysetpos? : Array[Int32],
  dtstart? : DateTime,
  count? : Int32,
  until? : DateTime,
) -> DateLocator raise DateError {
  let locator = date_locator_from_rule(
    make_date_rule(
      frequency, interval, wkst, bymonth, bymonthday, byyearday, byweekno, byeaster,
      byweekday, byhour, byminute, bysecond, bysetpos, dtstart, count, until,
    ),
  )
  if tz is Some(_) || timezone is Some(_) || dtstart is None {
    locator.with_timezone(selected_timezone(tz, timezone))
  } else {
    locator
  }
}

///|
fn recurrence_position(value : Int32) -> Int32 raise DateError {
  if value == 0 || value < -366 || value > 366 {
    raise DateError::InvalidDate(
      message="recurrence position must be in -366..-1 or 1..366",
    )
  }
  value
}

///|
// Keep explicit recurrence boundaries in the same local calendar as a copied
// locator. The numeric instants remain unchanged when the fixed offset moves.
fn DateRule::with_offset(
  self : DateRule,
  offset_minutes : Int32,
) -> DateRule raise DateError {
  {
    frequency: self.frequency,
    interval: self.interval,
    wkst: self.wkst,
    dtstart: match self.dtstart {
      Some(value) => Some(value.with_offset(offset_minutes))
      None => None
    },
    count: self.count,
    until: match self.until {
      Some(value) => Some(value.with_offset(offset_minutes))
      None => None
    },
    bymonth: self.bymonth,
    bymonthday: self.bymonthday,
    byyearday: self.byyearday,
    byweekno: self.byweekno,
    byeaster: self.byeaster,
    byweekday: self.byweekday,
    bynweekday: self.bynweekday,
    byhour: self.byhour,
    byminute: self.byminute,
    bysecond: self.bysecond,
    bysetpos: self.bysetpos,
    timezone: None,
  }
}

///|
fn DateRule::with_timezone(
  self : DateRule,
  timezone : DateTimeZone,
) -> DateRule {
  {
    frequency: self.frequency,
    interval: self.interval,
    wkst: self.wkst,
    dtstart: self.dtstart,
    count: self.count,
    until: self.until,
    bymonth: self.bymonth,
    bymonthday: self.bymonthday,
    byyearday: self.byyearday,
    byweekno: self.byweekno,
    byeaster: self.byeaster,
    byweekday: self.byweekday,
    bynweekday: self.bynweekday,
    byhour: self.byhour,
    byminute: self.byminute,
    bysecond: self.bysecond,
    bysetpos: self.bysetpos,
    timezone: Some(timezone),
  }
}
