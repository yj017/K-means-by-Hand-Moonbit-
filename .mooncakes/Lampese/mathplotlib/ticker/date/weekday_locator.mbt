///|
/// Matplotlib WeekdayLocator backed by the shared recurrence locator.
pub struct WeekdayLocator {
  priv locator : RRuleLocator
}

///|
/// Weekday ticks default to Tuesday (Monday=0). Daily frequency ignores nth.
/// context supplies host-local now. null names pass explicit None selectors.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.WeekdayLocator::new(tz="UTC", context~)
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 8)),
///   )
///   assert_eq(values.length(), 1)
/// }
/// ```
pub fn WeekdayLocator::new(
  byweekday? : Array[Int32],
  byweekday_value? : Int32,
  byweekdays? : Array[RelativeWeekday],
  on_weekday? : RelativeWeekday,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  null~ : Array[String] = [],
) -> WeekdayLocator raise DateError {
  named_locator_null(null, ["byweekday"])
  let forms = (if byweekday is Some(_) { 1 } else { 0 }) +
    (if byweekday_value is Some(_) { 1 } else { 0 }) +
    (if byweekdays is Some(_) { 1 } else { 0 }) +
    (if on_weekday is Some(_) { 1 } else { 0 })
  if forms > 1 {
    raise DateError::InvalidDate(message="use one weekday keyword form")
  }
  let reset = null.contains("byweekday")
  let objects = if reset {
    None
  } else {
    match on_weekday {
      Some(value) => Some([value])
      None => byweekdays
    }
  }
  let (days, day_value) = named_locator_selection(
    byweekday,
    byweekday_value,
    if reset || objects is Some(_) {
      AnyDate
    } else {
      At(1)
    },
    reset,
  )
  let rule = RRuleWrapper::new(
    Daily,
    interval~,
    context?,
    byweekday?=named_locator_array(days, day_value),
    byweekdays?=objects,
    byhour=[0],
    byminute=[0],
    bysecond=[0],
  )
  { locator: RRuleLocator::new(rule, tz?, timezone?), }
}

///|
/// Return the shared mutable recurrence wrapper.
pub fn WeekdayLocator::rule(self : WeekdayLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn WeekdayLocator::timezone(self : WeekdayLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn WeekdayLocator::interval(self : WeekdayLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn WeekdayLocator::unit_scale(self : WeekdayLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn WeekdayLocator::with_timezone(
  self : WeekdayLocator,
  timezone : DateTimeZone,
) -> WeekdayLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn WeekdayLocator::with_offset(
  self : WeekdayLocator,
  offset_minutes : Int32,
) -> WeekdayLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain this locator's shared wrapper and display timezone.
pub fn WeekdayLocator::as_rrule_locator(self : WeekdayLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn WeekdayLocator::as_locator(self : WeekdayLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn WeekdayLocator::tick_values(
  self : WeekdayLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}
