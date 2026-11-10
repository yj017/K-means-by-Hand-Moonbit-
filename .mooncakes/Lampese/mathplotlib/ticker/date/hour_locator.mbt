///|
/// Matplotlib HourLocator backed by the shared recurrence locator.
pub struct HourLocator {
  priv locator : RRuleLocator
}

///|
/// Hourly ticks default to every hour, at minute/second zero.
/// context supplies host-local now. null names pass explicit None selectors.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.HourLocator::new(byhour=[0, 12], tz="UTC", context~)
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 2)),
///   )
///   assert_eq(values.length(), 3)
/// }
/// ```
pub fn HourLocator::new(
  byhour? : Array[Int32],
  byhour_value? : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  null~ : Array[String] = [],
) -> HourLocator raise DateError {
  named_locator_null(null, ["byhour"])
  let (hours, hour_value) = named_locator_selection(
    byhour,
    byhour_value,
    Every(0, 24),
    null.contains("byhour"),
  )
  let rule = RRuleWrapper::new(
    Hourly,
    interval~,
    context?,
    byhour?=named_locator_array(hours, hour_value),
    byminute=[0],
    bysecond=[0],
  )
  { locator: RRuleLocator::new(rule, tz?, timezone?), }
}

///|
/// Return the shared mutable recurrence wrapper.
pub fn HourLocator::rule(self : HourLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn HourLocator::timezone(self : HourLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn HourLocator::interval(self : HourLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn HourLocator::unit_scale(self : HourLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn HourLocator::with_timezone(
  self : HourLocator,
  timezone : DateTimeZone,
) -> HourLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn HourLocator::with_offset(
  self : HourLocator,
  offset_minutes : Int32,
) -> HourLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain this locator's shared wrapper and display timezone.
pub fn HourLocator::as_rrule_locator(self : HourLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn HourLocator::as_locator(self : HourLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn HourLocator::tick_values(
  self : HourLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}
