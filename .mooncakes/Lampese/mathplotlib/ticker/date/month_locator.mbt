///|
/// Matplotlib MonthLocator backed by the shared recurrence locator.
pub struct MonthLocator {
  priv locator : RRuleLocator
}

///|
/// Monthly ticks; bymonth defaults to all months and bymonthday defaults to 1.
/// context supplies host-local now. null names pass explicit None selectors.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.MonthLocator::new(tz="UTC", context~)
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2024, 3, 1)),
///   )
///   assert_eq(values.length(), 3)
/// }
/// ```
pub fn MonthLocator::new(
  bymonth? : Array[Int32],
  bymonth_value? : Int32,
  bymonthday? : Array[Int32],
  bymonthday_value? : Int32,
  interval~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
  null~ : Array[String] = [],
) -> MonthLocator raise DateError {
  named_locator_null(null, ["bymonth", "bymonthday"])
  let (months, month_value) = named_locator_selection(
    bymonth,
    bymonth_value,
    Every(1, 12),
    null.contains("bymonth"),
  )
  let reset_day = null.contains("bymonthday")
  let (days, day_value) = named_locator_selection(
    bymonthday,
    bymonthday_value,
    if reset_day {
      AnyDate
    } else {
      At(1)
    },
    reset_day,
  )
  let rule = RRuleWrapper::new(
    Monthly,
    interval~,
    context?,
    bymonth?=months,
    bymonth_value?=month_value,
    bymonthday?=days,
    bymonthday_value?=day_value,
    null=if reset_day { ["bymonthday"] } else { [] },
    byhour=[0],
    byminute=[0],
    bysecond=[0],
  )
  { locator: RRuleLocator::new(rule, tz?, timezone?), }
}

///|
/// Return the shared mutable recurrence wrapper.
pub fn MonthLocator::rule(self : MonthLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn MonthLocator::timezone(self : MonthLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn MonthLocator::interval(self : MonthLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn MonthLocator::unit_scale(self : MonthLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn MonthLocator::with_timezone(
  self : MonthLocator,
  timezone : DateTimeZone,
) -> MonthLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn MonthLocator::with_offset(
  self : MonthLocator,
  offset_minutes : Int32,
) -> MonthLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain this locator's shared wrapper and display timezone.
pub fn MonthLocator::as_rrule_locator(self : MonthLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn MonthLocator::as_locator(self : MonthLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn MonthLocator::tick_values(
  self : MonthLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}
