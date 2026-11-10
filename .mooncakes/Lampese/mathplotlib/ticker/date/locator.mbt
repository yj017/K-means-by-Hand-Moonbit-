///|
/// Calendar units supported by the explicit date locators.
pub(all) enum LocatorKind {
  Automatic
  Days
  BusinessDays
  Years
  Months
  Weekdays
  NthWeekdays
  Recurrence
  Hours
  Minutes
  Seconds
  Microseconds
}

///|
/// A calendar locator for UTC numeric dates, capturing its display timezone.
pub struct DateLocator {
  kind : LocatorKind
  interval : Int32
  selector : Int32
  secondary : Int32
  selector_enabled : Bool
  offset_minutes : Int32
  priv timezone : DateTimeZone?
  priv selection : Array[Int32]?
  priv secondary_selection : Array[Int32]?
  // Calendar-day keys excluded by a BusinessDays locator. The keys are
  // Gregorian day counts, so an explicit holiday remains a calendar label
  // when the locator is copied to another fixed UTC offset.
  priv holidays : Array[Int32]
  priv rule : DateRule?
  priv automatic : AutoDateLocator?
  priv wrapper_locator : RRuleLocator?
  priv microsecond_object : MicrosecondLocator?
}

///|
/// Locate calendar days at a fixed number of day intervals.
pub fn date_locator(
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  day_locator(interval~, tz?, timezone?)
}

///|
/// Locate business days using a configurable weekday mask and explicit
/// holiday dates.
///
/// `weekdays` uses Monday=0 through Sunday=6 and defaults to Monday through
/// Friday. `holidays` is interpreted as a list of Gregorian calendar dates;
/// the time and fixed offset on each value are ignored. `interval` advances
/// calendar days before applying the weekday and holiday filters, matching
/// the interval behavior of `weekday_locator`.
///
/// ```mbt check
/// test {
///   let locator = @date.business_day_locator(holidays=[@date.datetime(2024, 1, 1)])
///   let ticks = locator.tick_values(
///     @date.datetime(2023, 12, 29).to_ordinal(),
///     @date.datetime(2024, 1, 5).to_ordinal(),
///   )
///   assert_eq(@date.format_date_ticks(ticks, format="%Y-%m-%d"), [
///     "2023-12-29", "2024-01-02", "2024-01-03", "2024-01-04", "2024-01-05",
///   ])
/// }
/// ```
pub fn business_day_locator(
  weekdays? : Array[Int32],
  holidays? : Array[DateTime],
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = {
    let selection = match weekdays {
      Some(values) =>
        locator_selection(None, Some(values), None, None, weekday_selector)
      None => Some([0, 1, 2, 3, 4])
    }
    let holiday_days = business_holiday_days(holidays)
    {
      kind: BusinessDays,
      interval: positive_interval(interval),
      selector: match selection {
        Some([first, ..]) => first
        _ => 0
      },
      secondary: 0,
      selector_enabled: true,
      offset_minutes: 0,
      timezone: None,
      selection,
      secondary_selection: None,
      holidays: holiday_days,
      rule: None,
      automatic: None,
      wrapper_locator: None,
      microsecond_object: None,
    }
  }
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate a given month and day every `base` years, including aligned years
/// outside the visible range. Invalid dates in non-leap years are skipped.
pub fn year_locator(
  base~ : Int32 = 1,
  month~ : Int32 = 1,
  day~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Years,
    positive_interval(base),
    Some([month_selector(month)]),
    day_selector(day),
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate months, optionally filtering by `bymonth`, with day 1 as the default.
/// `bymonthday=-1` selects each month's last day. Impossible dates are skipped.
/// The interval counts calendar months before applying the filter.
///
/// ```mbt check
/// test {
///   let locator = @date.month_locator(bymonth=[2, 4], bymonthday=-1)
///   let ticks = locator.tick_values(
///     @date.datetime(2024, 1, 1).to_ordinal(),
///     @date.datetime(2024, 5, 1).to_ordinal(),
///   )
///   assert_eq(
///     ticks.map(value => @date.format_date(@date.from_ordinal(value), "%Y-%m-%d")),
///     ["2024-02-29", "2024-04-30"],
///   )
/// }
/// ```
pub fn month_locator(
  interval~ : Int32 = 1,
  bymonth? : Array[Int32],
  bymonthday~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Months,
    positive_interval(interval),
    locator_selection(None, bymonth, None, None, month_selector),
    monthday_selector(bymonthday),
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate one month at a fixed number of calendar month intervals.
pub fn month_locator_on(
  month : Int32,
  interval~ : Int32 = 1,
  bymonthday~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  month_locator(interval~, bymonth=[month], bymonthday~, tz?, timezone?)
}

///|
/// Locate weekdays using Monday=0 through Sunday=6; the default is Tuesday.
/// Use either `weekday` or a nonempty `byweekday` array.
/// As in Matplotlib, `interval` counts days before filtering by weekday.
///
/// ```mbt check
/// test {
///   let locator = @date.weekday_locator(byweekday=[0, 2])
///   let ticks = locator.tick_values(
///     @date.datetime(2024, 1, 1).to_ordinal(),
///     @date.datetime(2024, 1, 7).to_ordinal(),
///   )
///   assert_eq(ticks.map(value => @date.from_ordinal(value).day()), [1, 3])
/// }
/// ```
pub fn weekday_locator(
  weekday? : Int32,
  interval~ : Int32 = 1,
  byweekday? : Array[Int32],
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Weekdays,
    positive_interval(interval),
    locator_selection(weekday, byweekday, None, Some(1), weekday_selector),
    0,
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate the nth occurrence of a weekday in each selected calendar month.
/// `ordinal` is in `-5..-1` or `1..5`; negative values count back from the
/// month's end. The interval counts months before applying `bymonth`.
/// Use `byweekday` to select more than one weekday; the emitted dates remain
/// in chronological order within each month.
///
/// ```mbt check
/// test {
///   let locator = @date.nth_weekday_locator(weekday=0, ordinal=2)
///   let ticks = locator.tick_values(
///     @date.datetime(2024, 1, 1).to_ordinal(),
///     @date.datetime(2024, 4, 30).to_ordinal(),
///   )
///   assert_eq(
///     ticks.map(value => @date.format_date(@date.from_ordinal(value), "%Y-%m-%d")),
///     ["2024-01-08", "2024-02-12", "2024-03-11", "2024-04-08"],
///   )
/// }
/// ```
pub fn nth_weekday_locator(
  weekday? : Int32,
  ordinal~ : Int32 = 1,
  interval~ : Int32 = 1,
  bymonth? : Array[Int32],
  byweekday? : Array[Int32],
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = {
    if ordinal == 0 || ordinal < -5 || ordinal > 5 {
      raise DateError::InvalidDate(
        message="weekday ordinal must be in -5..-1 or 1..5",
      )
    }
    let weekdays = locator_selection(
      weekday,
      byweekday,
      None,
      Some(1),
      weekday_selector,
    )
    let months = locator_selection(None, bymonth, None, None, month_selector)
    {
      kind: NthWeekdays,
      interval: positive_interval(interval),
      selector: match weekdays {
        Some([first, ..]) => first
        _ => 1
      },
      secondary: ordinal,
      selector_enabled: weekdays is Some(_),
      offset_minutes: 0,
      timezone: None,
      selection: months,
      secondary_selection: weekdays,
      holidays: [],
      rule: None,
      automatic: None,
      wrapper_locator: None,
      microsecond_object: None,
    }
  }
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate days, optionally using `day` or a nonempty `bymonthday` array.
/// Negative selectors count from the end of the month (-1 is the last day).
/// The legacy scalar `day=0` selects all days. The interval counts days before
/// filtering, rather than counting occurrences of the selected month days.
///
/// ```mbt check
/// test {
///   let locator = @date.day_locator(bymonthday=[1, -1])
///   let ticks = locator.tick_values(
///     @date.datetime(2024, 2, 1).to_ordinal(),
///     @date.datetime(2024, 2, 29).to_ordinal(),
///   )
///   assert_eq(ticks.map(value => @date.from_ordinal(value).day()), [1, 29])
/// }
/// ```
pub fn day_locator(
  day? : Int32,
  interval~ : Int32 = 1,
  bymonthday? : Array[Int32],
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Days,
    positive_interval(interval),
    locator_selection(day, bymonthday, Some(0), None, monthday_selector),
    0,
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate hours using `hour` or a nonempty `byhour` array (0..23).
/// Omission or the legacy scalar -1 selects all hours; 0 selects midnight.
/// The interval counts hours before filtering.
///
/// ```mbt check
/// test {
///   let locator = @date.hour_locator(byhour=[0, 12])
///   assert_eq(locator.tick_values(0.0, 1.0), [0.0, 0.5, 1.0])
/// }
/// ```
pub fn hour_locator(
  hour? : Int32,
  interval~ : Int32 = 1,
  byhour? : Array[Int32],
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Hours,
    positive_interval(interval),
    locator_selection(hour, byhour, Some(-1), None, hour_selector),
    0,
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate one explicit hour of each day, including midnight when `hour` is 0.
pub fn hour_locator_at(
  hour : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  hour_locator(hour=hour_selector(hour), interval~, tz?, timezone?)
}

///|
/// Locate minutes using `minute` or a nonempty `byminute` array (0..59).
/// Omission or the legacy scalar -1 selects all minutes; 0 selects minute 0.
/// The interval counts minutes before filtering.
///
/// ```mbt check
/// test {
///   let locator = @date.minute_locator(byminute=[0, 30])
///   let ticks = locator.tick_values(0.0, 1.0 / 24.0)
///   assert_eq(ticks.map(value => @date.from_ordinal(value).minute()), [0, 30, 0])
/// }
/// ```
pub fn minute_locator(
  minute? : Int32,
  interval~ : Int32 = 1,
  byminute? : Array[Int32],
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Minutes,
    positive_interval(interval),
    locator_selection(
      minute,
      byminute,
      Some(-1),
      None,
      minute_or_second_selector,
    ),
    0,
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate one explicit minute of each hour, including minute 0.
pub fn minute_locator_at(
  minute : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  minute_locator(
    minute=minute_or_second_selector(minute),
    interval~,
    tz?,
    timezone?,
  )
}

///|
/// Locate seconds using `second` or a nonempty `bysecond` array (0..59).
/// Omission or the legacy scalar -1 selects all seconds; 0 selects second 0.
/// The interval counts seconds before filtering.
///
/// ```mbt check
/// test {
///   let locator = @date.second_locator(bysecond=[0, 30])
///   let ticks = locator.tick_values(0.0, 1.0 / 1440.0)
///   assert_eq(ticks.map(value => @date.from_ordinal(value).second()), [0, 30, 0])
/// }
/// ```
pub fn second_locator(
  second? : Int32,
  interval~ : Int32 = 1,
  bysecond? : Array[Int32],
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Seconds,
    positive_interval(interval),
    locator_selection(
      second,
      bysecond,
      Some(-1),
      None,
      minute_or_second_selector,
    ),
    0,
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
/// Locate one explicit second of each minute, including second 0.
pub fn second_locator_at(
  second : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  second_locator(
    second=minute_or_second_selector(second),
    interval~,
    tz?,
    timezone?,
  )
}

///|
/// Locate ticks at a fixed number of microseconds from the first UTC midnight.
/// Include one adjacent tick beyond each end, as Matplotlib does. Ticks outside
/// years 1..9999 are omitted. Ordinal precision decreases far from 1970.
///
/// ```mbt check
/// test {
///   let locator = @date.microsecond_locator(interval=250)
///   let ticks = locator.tick_values(
///     100.0 / 86_400_000_000.0,
///     1000.0 / 86_400_000_000.0,
///   )
///   assert_eq(ticks.map(value => @date.from_ordinal(value).microsecond()), [
///     0, 250, 500, 750, 1000, 1250,
///   ])
/// }
/// ```
pub fn microsecond_locator(
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
) -> DateLocator raise DateError {
  let locator = new_date_locator(
    Microseconds,
    positive_interval(interval),
    None,
    0,
  )
  locator.with_timezone(selected_timezone(tz, timezone))
}

///|
pub fn DateLocator::kind(self : DateLocator) -> LocatorKind {
  self.kind
}

///|
/// Legacy integer interval. Fractional microsecond intervals truncate and large
/// ones saturate to Int32::MAX; interval_value() retains the exact Double value.
pub fn DateLocator::interval(self : DateLocator) -> Int32 {
  if self.microsecond_object is Some(value) {
    return microsecond_interval_projection(value.interval)
  }
  if self.wrapper_locator is Some(value) {
    return value.interval()
  }
  self.interval
}

///|
/// Return the smallest selector, or 0 when no filter is configured.
pub fn DateLocator::selector(self : DateLocator) -> Int32 {
  self.selector
}

///|
/// Return configured whole minutes, truncated toward zero for TZif history.
/// A configured `timezone` supplies the exact offsets used for expansion.
pub fn DateLocator::offset_minutes(self : DateLocator) -> Int32 {
  self.offset_minutes
}

///|
/// Return the explicit transition-aware timezone used for tick conversion,
/// if configured.
pub fn DateLocator::timezone(self : DateLocator) -> DateTimeZone? {
  self.timezone
}

///|
/// Return a copy of this locator whose calendar boundaries use a fixed UTC
/// offset. The emitted numeric ticks remain UTC Matplotlib ordinals.
///
/// ```mbt check
/// test {
///   let locator = try! @date.hour_locator().with_offset(90)
///   assert_eq(locator.offset_minutes(), 90)
/// }
/// ```
pub fn DateLocator::with_offset(
  self : DateLocator,
  offset_minutes : Int32,
) -> DateLocator raise DateError {
  if offset_minutes <= -1440 || offset_minutes >= 1440 {
    raise DateError::InvalidDate(
      message="offset_minutes must be in -1439..1439",
    )
  }
  {
    kind: self.kind,
    interval: self.interval,
    selector: self.selector,
    secondary: self.secondary,
    selector_enabled: self.selector_enabled,
    offset_minutes,
    timezone: None,
    microsecond_object: self.microsecond_object.map(value => {
      try! value.with_offset(offset_minutes)
    }),
    wrapper_locator: self.wrapper_locator.map(value => {
      try! value.with_offset(offset_minutes)
    }),
    automatic: self.automatic.map(value => {
      try! value.with_offset(offset_minutes)
    }),
    selection: self.selection,
    secondary_selection: self.secondary_selection,
    holidays: self.holidays.copy(),
    rule: match self.rule {
      Some(rule) => Some(rule.with_offset(offset_minutes))
      None => None
    },
  }
}

///|
/// Return a copy whose calendar candidates resolve with an explicit transition
/// table. Recurrence locators generate local candidates in the same zone, so a
/// spring gap is skipped and a fall fold can emit both UTC instants.
pub fn DateLocator::with_timezone(
  self : DateLocator,
  timezone : DateTimeZone,
) -> DateLocator {
  {
    kind: self.kind,
    interval: self.interval,
    selector: self.selector,
    secondary: self.secondary,
    selector_enabled: self.selector_enabled,
    offset_minutes: timezone.initial_offset_minutes(),
    timezone: Some(timezone),
    microsecond_object: self.microsecond_object.map(value => {
      value.with_timezone(timezone)
    }),
    wrapper_locator: self.wrapper_locator.map(value => {
      value.with_timezone(timezone)
    }),
    automatic: self.automatic.map(value => value.with_timezone(timezone)),
    selection: self.selection,
    secondary_selection: self.secondary_selection,
    holidays: self.holidays.copy(),
    rule: match self.rule {
      Some(rule) => Some(rule.with_timezone(timezone))
      None => None
    },
  }
}

///|
/// Generate up to 100000 ticks in input range order. With no matching dates,
/// return the input endpoints. Invalid ordinals return an empty array.
///
/// Recurrences use an explicit `dtstart` when configured; otherwise they use
/// Matplotlib's calendar-expanded window as their anchor.
/// Year locators include aligned years outside the range. Microsecond locators
/// include adjacent multiples on either side, within years 1..9999.
pub fn DateLocator::tick_values(
  self : DateLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] {
  self.tick_values_checked(lower, upper) catch {
    _ => []
  }
}

///|
/// Generate calendar ticks while preserving date conversion and selection errors.
/// The legacy tick_values convenience method returns [] on these errors.
pub fn DateLocator::tick_values_checked(
  self : DateLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise DateError {
  if self.microsecond_object is Some(value) {
    return value.numeric_tick_values(lower, upper)
  }
  if self.wrapper_locator is Some(value) {
    return value.numeric_tick_values(lower, upper)
  }
  if self.automatic is Some(value) {
    return value.tick_values(lower, upper)
  }
  let (first, last) = if lower > upper {
    (upper, lower)
  } else {
    (lower, upper)
  }
  let first_date = match self.timezone {
    Some(zone) => zone.to_datetime(first)
    None => from_ordinal(first, offset_minutes=self.offset_minutes)
  }
  let last_date = match self.timezone {
    Some(zone) => zone.to_datetime(last)
    None => from_ordinal(last, offset_minutes=self.offset_minutes)
  }
  self.ticks_for_dates(first, last, first_date, last_date, lower <= upper)
}

///|
// The automatic view path already decoded and rounded endpoints. Keep those
// calendar fields while clipping emitted date2num coordinates, without a second
// public inverse conversion (which would add a fractional epoch again).
fn DateLocator::ticks_for_dates(
  self : DateLocator,
  first : Double,
  last : Double,
  first_date : DateTime,
  last_date : DateTime,
  ascending : Bool,
) -> Array[Double] {
  if first == last && !(self.kind is Microseconds) {
    return [first]
  }
  let values = match self.kind {
    Years => year_ticks(self, first_date, last_date)
    NthWeekdays => nth_weekday_ticks(self, first, last, first_date, last_date)
    Recurrence => recurrence_ticks(self, first, last, first_date, last_date)
    Microseconds => microsecond_ticks(first, last, self.interval)
    _ => {
      let anchor = recurrence_start(first_date, last_date)
      match self.kind {
        Months => month_ticks(self, first, last, first_date, last_date, anchor)
        Days | Weekdays | BusinessDays =>
          locator_day_ticks(self, first, last, first_date, last_date, anchor)
        Hours =>
          time_ticks(self, first, last, first_date, last_date, anchor, 3600, 24)
        Minutes =>
          time_ticks(self, first, last, first_date, last_date, anchor, 60, 60)
        Seconds =>
          time_ticks(self, first, last, first_date, last_date, anchor, 1, 60)
        Microseconds => []
        NthWeekdays => []
        Recurrence => []
        Years => []
        Automatic => []
      }
    }
  }
  if values.is_empty() {
    if ascending {
      [first, last]
    } else {
      [last, first]
    }
  } else if ascending {
    values
  } else {
    values.rev()
  }
}
