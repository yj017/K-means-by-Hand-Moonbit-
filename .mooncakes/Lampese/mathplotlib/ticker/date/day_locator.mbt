///|
/// Matplotlib DayLocator backed by the shared recurrence locator.
pub struct DayLocator {
  priv locator : RRuleLocator
}

///|
/// Daily ticks default to all month days. Negative days count from month end.
/// context supplies host-local now. null names pass explicit None selectors.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.DayLocator::new(bymonthday_value=-1, tz="UTC", context~)
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2024, 3, 1)),
///   )
///   assert_eq(values.length(), 2)
/// }
/// ```
pub fn DayLocator::new(
  bymonthday? : Array[Int32],
  bymonthday_value? : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  null~ : Array[String] = [],
) -> DayLocator raise DateError {
  // This subclass validates interval before the underlying default clock.
  ignore(positive_interval(interval))
  named_locator_null(null, ["bymonthday"])
  let (days, day_value) = named_locator_selection(
    bymonthday,
    bymonthday_value,
    Every(1, 31),
    null.contains("bymonthday"),
  )
  let rule = RRuleWrapper::new(
    Daily,
    interval~,
    context?,
    bymonthday?=days,
    bymonthday_value?=day_value,
    byhour=[0],
    byminute=[0],
    bysecond=[0],
  )
  { locator: RRuleLocator::new(rule, tz?, timezone?), }
}

///|
/// Return the shared mutable recurrence wrapper.
pub fn DayLocator::rule(self : DayLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn DayLocator::timezone(self : DayLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn DayLocator::interval(self : DayLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn DayLocator::unit_scale(self : DayLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn DayLocator::with_timezone(
  self : DayLocator,
  timezone : DateTimeZone,
) -> DayLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn DayLocator::with_offset(
  self : DayLocator,
  offset_minutes : Int32,
) -> DayLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain this locator's shared wrapper and display timezone.
pub fn DayLocator::as_rrule_locator(self : DayLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn DayLocator::as_locator(self : DayLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn DayLocator::tick_values(
  self : DayLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}
