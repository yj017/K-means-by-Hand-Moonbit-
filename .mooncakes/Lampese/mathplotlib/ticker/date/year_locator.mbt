///|
/// Matplotlib YearLocator with exact aligned year bounds and a live wrapper.
/// Invalid aligned month/day pairs raise instead of skipping candidate years.
pub struct YearLocator {
  priv locator : RRuleLocator
}

///|
/// Capture the display zone after constructing the underlying yearly rule.
/// An explicit parser context provides deterministic host-local now fields.
///
/// ```mbt check
/// test {
///   let context = @date.DateParserContext::utc(clock=fn() { 1781524800123L })
///   let locator = @date.YearLocator::new(
///     base=5,
///     month=7,
///     day=4,
///     tz="UTC",
///     context~,
///   )
///   let values = locator.tick_values(
///     @date.RRuleDateTime::naive(@date.datetime(2021, 5, 1)),
///     @date.RRuleDateTime::naive(@date.datetime(2028, 1, 1)),
///   )
///   assert_eq(values.map(value => @date.from_ordinal(value).year()), [
///     2020, 2025, 2030,
///   ])
/// }
/// ```
pub fn YearLocator::new(
  base~ : Int32 = 1,
  month~ : Int32 = 1,
  day~ : Int32 = 1,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
) -> YearLocator raise DateError {
  let rule = RRuleWrapper::new(
    Yearly,
    interval=base,
    bymonth_value=month,
    bymonthday_value=day,
    byhour=[0],
    byminute=[0],
    bysecond=[0],
    context?,
  )
  {
    locator: {
      ..RRuleLocator::new(rule, tz?, timezone?),
      year_base: Some(base),
    },
  }
}

///|
pub fn YearLocator::base(self : YearLocator) -> Int32 {
  self.locator.year_base.unwrap()
}

///|
pub fn YearLocator::rule(self : YearLocator) -> RRuleWrapper {
  self.locator.rule
}

///|
pub fn YearLocator::timezone(self : YearLocator) -> DateTimeZone {
  self.locator.timezone
}

///|
pub fn YearLocator::interval(self : YearLocator) -> Int32 {
  self.locator.interval()
}

///|
pub fn YearLocator::unit_scale(self : YearLocator) -> Double {
  self.locator.unit_scale()
}

///|
pub fn YearLocator::with_timezone(
  self : YearLocator,
  timezone : DateTimeZone,
) -> YearLocator {
  { locator: self.locator.with_timezone(timezone), }
}

///|
pub fn YearLocator::with_offset(
  self : YearLocator,
  offset_minutes : Int32,
) -> YearLocator raise DateError {
  { locator: self.locator.with_offset(offset_minutes), }
}

///|
/// Retain yearly bound alignment when adapting to the common locator object.
pub fn YearLocator::as_rrule_locator(self : YearLocator) -> RRuleLocator {
  self.locator
}

///|
pub fn YearLocator::as_locator(self : YearLocator) -> DateLocator {
  self.locator.as_locator()
}

///|
pub fn YearLocator::tick_values(
  self : YearLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  self.locator.tick_values(first, last)
}

///|
fn RRuleDateTime::replace_year_date(
  self : RRuleDateTime,
  year : Int32,
  month : Int32,
  day : Int32,
) -> RRuleDateTime raise DateError {
  let wall = datetime(year, month, day, microsecond=self.value.microsecond)
  match self.timezone {
    Some(zone) => RRuleDateTime::from_local(wall, zone, fold=self.fold)
    None => RRuleDateTime::naive(wall)
  }
}

///|
fn RRuleLocator::year_bounds(
  self : RRuleLocator,
  base : Int32,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> (RRuleDateTime, RRuleDateTime) raise DateError {
  let step = Int64::from_int(base)
  let low = Int64::max(1L, Int64::from_int(first.value.year) / step * step).to_int()
  let high = Int64::min(
    9999L,
    locator_ceil_div64(Int64::from_int(last.value.year), step) * step,
  ).to_int()
  let month = self.rule.construct.bymonth_form.date_field()
  let day = self.rule.construct.bymonthday_form.date_field()
  let start = first.replace_year_date(low, month, day)
  let stop = start.replace_year_date(high, month, day)
  (start, stop)
}
