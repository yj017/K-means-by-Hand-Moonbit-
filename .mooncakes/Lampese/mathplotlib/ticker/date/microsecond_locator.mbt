///|
/// Matplotlib MicrosecondLocator with a finite positive Double interval.
/// Date conversion precedes the midnight-relative MultipleLocator grid.
pub struct MicrosecondLocator {
  priv interval : Double
  priv timezone : DateTimeZone
  priv context : DateParserContext?
}

///|
/// Capture the display zone before validating the interval. context is only
/// used for host interpretation of naive values in a first-aware mixed array.
///
/// ```mbt check
/// test {
///   let locator = @date.MicrosecondLocator::new(interval=0.5, tz="UTC")
///   let first = @date.RRuleDateTime::naive(@date.datetime(1970, 1, 1))
///   let last = @date.RRuleDateTime::naive(
///     @date.datetime(1970, 1, 1, microsecond=3),
///   )
///   assert_eq(locator.tick_values(first, last).length(), 9)
///   assert_eq(locator.as_locator().interval_value(), 0.5)
/// }
/// ```
pub fn MicrosecondLocator::new(
  interval~ : Double = 1.0,
  tz? : String,
  timezone? : DateTimeZone,
  context? : DateParserContext,
) -> MicrosecondLocator raise DateError {
  let timezone = selected_timezone(tz, timezone)
  if interval.is_nan() || interval.is_inf() || interval <= 0.0 {
    raise DateError::InvalidDate(
      message="microsecond interval must be finite and positive",
    )
  }
  { interval, timezone, context, }
}

///|
pub fn MicrosecondLocator::interval(self : MicrosecondLocator) -> Double {
  self.interval
}

///|
pub fn MicrosecondLocator::unit_scale(_self : MicrosecondLocator) -> Double {
  1.0 / 86_400_000_000.0
}

///|
pub fn MicrosecondLocator::timezone(self : MicrosecondLocator) -> DateTimeZone {
  self.timezone
}

///|
pub fn MicrosecondLocator::with_timezone(
  self : MicrosecondLocator,
  timezone : DateTimeZone,
) -> MicrosecondLocator {
  { ..self, timezone, }
}

///|
pub fn MicrosecondLocator::with_offset(
  self : MicrosecondLocator,
  offset_minutes : Int32,
) -> MicrosecondLocator raise DateError {
  self.with_timezone(fixed_timezone(offset_minutes))
}

///|
/// Return source-order ascending ticks, including neighboring points outside
/// years 1..9999. Direct reversed bounds keep the original first origin.
pub fn MicrosecondLocator::tick_values(
  self : MicrosecondLocator,
  first : RRuleDateTime,
  last : RRuleDateTime,
) -> Array[Double] raise DateError {
  let numbers = date_values_to_numbers([first, last], self.context)
  microsecond_ticks_unclipped(numbers[0], numbers[1], self.interval)
}

///|
fn microsecond_interval_projection(interval : Double) -> Int32 {
  Double::min(2147483647.0, interval).to_int()
}

///|
/// Adapt the exact interval while retaining the legacy integer projection.
pub fn MicrosecondLocator::as_locator(self : MicrosecondLocator) -> DateLocator {
  {
    kind: Microseconds,
    interval: microsecond_interval_projection(self.interval),
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
    wrapper_locator: None,
    microsecond_object: Some(self),
  }
}

///|
/// Return the exact interval, including fractional microseconds.
pub fn DateLocator::interval_value(self : DateLocator) -> Double {
  match self.microsecond_object {
    Some(value) => value.interval
    None => Double::from_int(self.interval())
  }
}

///|
pub fn DateLocator::microsecond_locator(
  self : DateLocator,
) -> MicrosecondLocator? {
  self.microsecond_object
}

///|
pub fn MicrosecondLocator::nonsingular(
  self : MicrosecondLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  self.as_locator().nonsingular(lower, upper)
}

///|
fn MicrosecondLocator::numeric_tick_values(
  self : MicrosecondLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise DateError {
  // Inverse conversion selects epoch even when nonfinite input then fails.
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    ignore(selected_epoch())
    raise DateError::InvalidDate(
      message="microsecond numeric bounds must be finite",
    )
  }
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
