///|
/// A Matplotlib RRuleLocator retaining a live mutable wrapper. Its display
/// timezone is captured independently of the wrapper's base/effective zone.
pub struct RRuleLocator {
  priv rule : RRuleWrapper
  priv timezone : DateTimeZone
  priv year_base : Int32?
}

///|
pub fn RRuleLocator::new(
  rule : RRuleWrapper,
  tz? : String,
  timezone? : DateTimeZone,
) -> RRuleLocator raise DateError {
  { rule, timezone: selected_timezone(tz, timezone), year_base: None, }
}

///|
/// Return the shared wrapper; later set calls affect this locator and adapters.
pub fn RRuleLocator::rule(self : RRuleLocator) -> RRuleWrapper {
  self.rule
}

///|
pub fn RRuleLocator::timezone(self : RRuleLocator) -> DateTimeZone {
  self.timezone
}

///|
pub fn RRuleLocator::with_timezone(
  self : RRuleLocator,
  timezone : DateTimeZone,
) -> RRuleLocator {
  { ..self, timezone, }
}

///|
pub fn RRuleLocator::with_offset(
  self : RRuleLocator,
  offset_minutes : Int32,
) -> RRuleLocator raise DateError {
  self.with_timezone(fixed_timezone(offset_minutes))
}

///|
pub fn RRuleLocator::unit_for_frequency(frequency : RRuleFrequency) -> Double {
  recurrence_unit(frequency)
}

///|
pub fn RRuleLocator::unit_scale(self : RRuleLocator) -> Double {
  recurrence_unit(self.rule.frequency())
}

///|
pub fn RRuleLocator::interval(self : RRuleLocator) -> Int32 {
  self.rule.interval()
}

///|
fn RRuleDateTime::with_arithmetic_date(
  self : RRuleDateTime,
  value : DateTime,
) -> RRuleDateTime {
  if self.is_naive() {
    RRuleDateTime::naive(value)
  } else {
    RRuleDateTime::aware(value)
  }
}

///|
/// Expand the range by relativedelta, rebuilding the shared wrapper as the
/// original locator does. Direct bounds retain their own awareness and zones.
///
/// ```mbt check
/// test {
///   let first = @date.RRuleDateTime::naive(@date.datetime(2024, 1, 1))
///   let last = @date.RRuleDateTime::naive(@date.datetime(2024, 1, 3))
///   let rule = @date.RRuleWrapper::new(@date.Daily, dtstart=first)
///   let locator = @date.RRuleLocator::new(rule, tz="UTC")
///   assert_eq(locator.tick_values(first, last).length(), 3)
///   rule.set(frequency=@date.Hourly, interval=12)
///   assert_eq(locator.as_locator().interval(), 12)
/// }
/// ```
///
/// Empty rules return the original endpoints. Unlike the numeric adapter,
/// reversed direct bounds follow the source's signed calendar expansion.
pub fn RRuleLocator::tick_values(
  self : RRuleLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  let (start, stop) = if self.year_base is Some(base) {
    self.year_bounds(base, first, last)
  } else {
    if first.is_naive() != last.is_naive() {
      raise DateError::InvalidDate(
        message="cannot compare naive and aware rule dates",
      )
    }
    let delta = RelativeDelta::between(last.date(), first.date())
    let start = first.with_arithmetic_date(
      first.date().sub_relative_delta(delta),
    ) catch {
      _ => RRuleDateTime::aware(try! datetime(1, 1, 1))
    }
    let stop = last.with_arithmetic_date(last.date().add_relative_delta(delta)) catch {
      _ =>
        RRuleDateTime::aware(
          try! datetime(9999, 12, 31, hour=23, minute=59, second=59),
        )
    }
    (start, stop)
  }
  self.rule.set(dtstart=start, until=stop)
  let values = self.rule.between(
    if self.year_base is Some(_) {
      start
    } else {
      first
    },
    if self.year_base is Some(_) {
      stop
    } else {
      last
    },
    inc=true,
  )
  let values = if values.is_empty() { [first, last] } else { values }
  date_values_to_numbers(values, self.rule.context)
}

///|
/// Share the wrapper with numeric axes. copy() of this DateLocator retains that
/// handle, so locator window updates and caller set calls remain observable.
pub fn RRuleLocator::as_locator(self : RRuleLocator) -> DateLocator {
  {
    kind: if self.year_base is Some(_) {
      Years
    } else {
      Recurrence
    },
    interval: self.interval(),
    selector: 0,
    secondary: 0,
    selector_enabled: false,
    offset_minutes: self.timezone.initial_offset_minutes(),
    timezone: Some(self.timezone),
    selection: None,
    secondary_selection: None,
    holidays: [],
    rule: None,
    automatic: None,
    wrapper_locator: Some(self),
    microsecond_object: None,
  }
}

///|
/// Return the live wrapper locator behind this adapter, if any.
pub fn DateLocator::rrule_locator(self : DateLocator) -> RRuleLocator? {
  self.wrapper_locator
}

///|
fn RRuleLocator::numeric_tick_values(
  self : RRuleLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise DateError {
  let first = RRuleDateTime::aware(
    self.timezone.to_datetime(Double::min(lower, upper)),
  )
  let last = RRuleDateTime::aware(
    self.timezone.to_datetime(Double::max(lower, upper)),
  )
  let values = self.tick_values(first, last)
  if lower <= upper {
    values
  } else {
    values.rev()
  }
}
