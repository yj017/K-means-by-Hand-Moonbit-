///|
/// Select a concrete calendar locator from local DateTime endpoints. Reuses
/// the public recurrence wrapper, captured timezone and microsecond generators.
pub fn AutoDateLocator::get_locator(
  self : AutoDateLocator,
  first : DateTime,
  last : DateTime,
) -> DateLocator raise DateError {
  let nums = automatic_distances(first, last)
  let ranges : Array[Array[Int32]?] = [
    None,
    Some([1]),
    Some([1]),
    Some([0]),
    Some([0]),
    Some([0]),
    None,
  ]
  let warnings : Array[AutoDateWarning] = []
  let mut index = 6
  let mut interval = 1
  for current in 0..<7 {
    if nums[current] < Double::from_int(self.settings.minticks) {
      ranges[current] = None
      continue
    }
    index = current
    let intervals = self.settings.intervals[current]
    interval = intervals[intervals.length() - 1]
    let mut matched = false
    for candidate in intervals {
      if nums[current] <=
        Double::from_int(candidate) *
        Double::from_int(self.settings.maxticks[current] - 1) {
        interval = candidate
        matched = true
        break
      }
    }
    if !matched && !(self.settings.multiples && current == 2) {
      warnings.push(IntervalFallback(auto_frequency(current), interval))
    }
    self.state.frequency = auto_frequency(current)
    break
  }
  self.state.interval = interval
  let mut actual_interval = interval
  if index >= 1 && index <= 5 {
    let start = if index < 3 { 1 } else { 0 }
    let length = match index {
      1 => 12
      2 => 31
      3 => 24
      _ => 60
    }
    let full = Array::makei(length, offset => start + offset)
    if self.settings.multiples {
      ranges[index] = Some(
        full.filter(value => (value - start) % interval == 0),
      )
      // The fixed source tests the range index against DAILY/WEEKLY constants,
      // so preserve the same special handling for custom hourly 7/14 tables.
      if index == 2 || index == 3 {
        if interval == 14 {
          ranges[index] = Some([1, 15])
        }
        if interval == 7 {
          ranges[index] = Some([1, 8, 15, 22])
        }
      }
      actual_interval = 1
    } else {
      ranges[index] = Some(full)
    }
  }
  let selected = if index == 0 && self.settings.multiples {
    YearLocator::new(
      base=actual_interval,
      tz="UTC",
      context?=self.settings.context,
    ).as_locator()
  } else if index < 6 {
    let frequency = match index {
      0 => Yearly
      1 => Monthly
      2 => Daily
      3 => Hourly
      4 => Minutely
      _ => Secondly
    }
    let bymonth = ranges[1]
    let bymonthday = ranges[2]
    let byhour = ranges[3]
    let byminute = ranges[4]
    let bysecond = ranges[5]
    let wrapper = RRuleWrapper::new(
      frequency,
      dtstart=RRuleDateTime::aware(first),
      until=RRuleDateTime::aware(last),
      interval=actual_interval,
      bymonth?,
      bymonthday?,
      byhour?,
      byminute?,
      bysecond?,
    )
    RRuleLocator::new(wrapper, tz="UTC").as_locator()
  } else {
    if first.to_ordinal() > 70.0 * 365.0 && actual_interval < 1000 {
      warnings.push(DistantMicroseconds)
    }
    MicrosecondLocator::new(
      interval=Double::from_int(actual_interval),
      tz="UTC",
      context?=self.settings.context,
    ).as_locator()
  }
  self.state.warnings = warnings
  match self.settings.timezone {
    Some(zone) => selected.with_timezone(zone)
    None => selected.with_offset(self.settings.offset_minutes)
  }
}

///|
fn AutoDateLocator::date_at(
  self : AutoDateLocator,
  value : Double,
) -> DateTime raise DateError {
  match self.settings.timezone {
    Some(zone) => zone.to_datetime(value)
    None => from_ordinal(value, offset_minutes=self.settings.offset_minutes)
  }
}

///|
fn AutoDateLocator::range_dates(
  self : AutoDateLocator,
  lower : Double,
  upper : Double,
) -> (DateTime, DateTime) raise DateError {
  ignore(selected_epoch())
  // Floating min/max may discard NaN on some targets, so validate before sorting.
  if lower.is_nan() || upper.is_nan() || lower.is_inf() || upper.is_inf() {
    raise DateError::InvalidDate(message="automatic date bounds must be finite")
  }
  (
    self.date_at(Double::min(lower, upper)),
    self.date_at(Double::max(lower, upper)),
  )
}

///|
/// Select from numeric UTC day bounds, interpreting both in this locator's zone.
pub fn AutoDateLocator::get_locator_for_range(
  self : AutoDateLocator,
  lower : Double,
  upper : Double,
) -> DateLocator raise DateError {
  let (first, last) = self.range_dates(lower, upper)
  self.get_locator(first, last)
}

///|
/// Generate ticks in the port's input range order. Singular inputs are passed
/// directly to selection; nonsingular() is a separate autoscale operation.
pub fn AutoDateLocator::tick_values(
  self : AutoDateLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise DateError {
  let (first, last) = self.range_dates(lower, upper)
  let selected = self.get_locator(first, last)
  if selected.microsecond_object is Some(locator) {
    let values = locator.tick_values(
      RRuleDateTime::aware(first),
      RRuleDateTime::aware(last),
    )
    return if lower <= upper { values } else { values.rev() }
  }
  if selected.wrapper_locator is Some(locator) {
    // These endpoints already passed through public num2date rounding. A second
    // inverse conversion would add a fractional epoch displacement again.
    let values = locator.tick_values(
      RRuleDateTime::aware(first),
      RRuleDateTime::aware(last),
    )
    return if lower <= upper { values } else { values.rev() }
  }
  selected.ticks_for_dates(
    first.to_ordinal(),
    last.to_ordinal(),
    first,
    last,
    lower <= upper,
  )
}
