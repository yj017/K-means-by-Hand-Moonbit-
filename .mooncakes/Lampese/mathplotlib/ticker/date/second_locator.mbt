///|
/// Matplotlib SecondLocator backed by the shared recurrence locator.
pub struct SecondLocator {
  priv locator : RRuleLocator
}

///|
/// Second ticks default to every second.
/// context supplies host-local now. null names pass explicit None selectors.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.SecondLocator::new(bysecond=[0, 30], tz="UTC", context~)
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1, minute=1)),
///   )
///   assert_eq(values.length(), 3)
/// }
/// ```
pub fn SecondLocator::new(
  bysecond? : Array[Int32],
  bysecond_value? : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  null~ : Array[String] = [],
) -> SecondLocator raise DateError {
  named_locator_null(null, ["bysecond"])
  let (seconds, second_value) = named_locator_selection(
    bysecond,
    bysecond_value,
    Every(0, 60),
    null.contains("bysecond"),
  )
  let rule = RRuleWrapper::new(
    Secondly,
    interval~,
    context?,
    bysecond?=named_locator_array(seconds, second_value),
  )
  { locator: RRuleLocator::new(rule, tz?, timezone?), }
}

///|
/// Return the shared mutable recurrence wrapper.
pub fn SecondLocator::rule(self : SecondLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn SecondLocator::timezone(self : SecondLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn SecondLocator::interval(self : SecondLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn SecondLocator::unit_scale(self : SecondLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn SecondLocator::with_timezone(
  self : SecondLocator,
  timezone : DateTimeZone,
) -> SecondLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn SecondLocator::with_offset(
  self : SecondLocator,
  offset_minutes : Int32,
) -> SecondLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain this locator's shared wrapper and display timezone.
pub fn SecondLocator::as_rrule_locator(self : SecondLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn SecondLocator::as_locator(self : SecondLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn SecondLocator::tick_values(
  self : SecondLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}
