///|
/// Matplotlib MinuteLocator backed by the shared recurrence locator.
pub struct MinuteLocator {
  priv locator : RRuleLocator
}

///|
/// Minute ticks default to every minute, at second zero.
/// context supplies host-local now. null names pass explicit None selectors.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.MinuteLocator::new(byminute=[0, 30], tz="UTC", context~)
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1, hour=1)),
///   )
///   assert_eq(values.length(), 3)
/// }
/// ```
pub fn MinuteLocator::new(
  byminute? : Array[Int32],
  byminute_value? : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  null~ : Array[String] = [],
) -> MinuteLocator raise DateError {
  named_locator_null(null, ["byminute"])
  let (minutes, minute_value) = named_locator_selection(
    byminute,
    byminute_value,
    Every(0, 60),
    null.contains("byminute"),
  )
  let rule = RRuleWrapper::new(
    Minutely,
    interval~,
    context?,
    byminute?=named_locator_array(minutes, minute_value),
    bysecond=[0],
  )
  { locator: RRuleLocator::new(rule, tz?, timezone?), }
}

///|
/// Return the shared mutable recurrence wrapper.
pub fn MinuteLocator::rule(self : MinuteLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn MinuteLocator::timezone(self : MinuteLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn MinuteLocator::interval(self : MinuteLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn MinuteLocator::unit_scale(self : MinuteLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn MinuteLocator::with_timezone(
  self : MinuteLocator,
  timezone : DateTimeZone,
) -> MinuteLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn MinuteLocator::with_offset(
  self : MinuteLocator,
  offset_minutes : Int32,
) -> MinuteLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain this locator's shared wrapper and display timezone.
pub fn MinuteLocator::as_rrule_locator(self : MinuteLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn MinuteLocator::as_locator(self : MinuteLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn MinuteLocator::tick_values(
  self : MinuteLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}
