///|
fn recurrence_unit(frequency : RRuleFrequency) -> Double {
  match frequency {
    Yearly => 365.0
    Monthly => 30.0
    Weekly => 7.0
    Daily => 1.0
    Hourly => 1.0 / 24.0
    Minutely => 1.0 / 1440.0
    Secondly => 1.0 / 86400.0
  }
}

///|
/// Return the locator's base unit in days, independent of its interval.
pub fn DateLocator::unit_scale(self : DateLocator) -> Double {
  if self.wrapper_locator is Some(value) {
    return value.unit_scale()
  }
  match self.kind {
    Automatic => self.automatic.unwrap().unit_scale()
    Years => 365.0
    Months | NthWeekdays => 30.0
    Days | BusinessDays | Weekdays => 1.0
    Hours => 1.0 / 24.0
    Minutes => 1.0 / 1440.0
    Seconds => 1.0 / 86400.0
    Microseconds => 1.0 / 86_400_000_000.0
    Recurrence => recurrence_unit(self.rule.unwrap().frequency)
  }
}

///|
/// Return the base unit of the frequency chosen by date_tick_values for a view.
/// This shares the generator's selection, rather than inferring unit from ticks.
pub fn auto_date_unit(
  lower : Double,
  upper : Double,
  count~ : Int32 = 6,
) -> Double {
  if lower.is_nan() || upper.is_nan() || lower.is_inf() || upper.is_inf() {
    return 1.0
  }
  match choose_interval(Double::abs(upper - lower), count) {
    Microseconds(_) => 1.0 / 86_400_000_000.0
    Subday(step) if step < 1.0 / 1440.0 => 1.0 / 86400.0
    Subday(step) if step < 1.0 / 24.0 => 1.0 / 1440.0
    Subday(_) => 1.0 / 24.0
    Days(_) => 1.0
    Months(_) => 30.0
    Years(_) => 365.0
  }
}
