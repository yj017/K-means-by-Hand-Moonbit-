///|
fn recurrence_values(values : Array[Int32]?, fallback : Int32) -> Array[Int32] {
  match values {
    Some(values) => values
    None => [fallback]
  }
}

///|
fn recurrence_contains(values : Array[Int32]?, value : Int32) -> Bool {
  match values {
    Some(values) => values.contains(value)
    None => true
  }
}

///|
fn DateRule::matches_date(
  self : DateRule,
  value : DateTime,
  anchor : DateTime,
  period_year : Int32,
) -> Bool {
  if !recurrence_contains(self.bymonth, value.month) ||
    !recurrence_contains(self.byweekday, value.weekday()) ||
    !self.matches_ordinal_weekday(value, period_year) ||
    !self.matches_year_fields(value, period_year) {
    return false
  }
  if self.bymonthday is Some(days) &&
    !days.contains(value.day) &&
    !days.contains(value.day - days_in_month(value.year, value.month) - 1) {
    return false
  }
  // dateutil only supplies these defaults in the absence of a day selector.
  if self.bymonthday is None &&
    self.byweekday is None &&
    self.bynweekday is None &&
    self.byyearday is None &&
    self.byweekno is None &&
    self.byeaster is None {
    match self.frequency {
      Yearly =>
        value.day == anchor.day &&
        (self.bymonth is Some(_) || value.month == anchor.month)
      Monthly => value.day == anchor.day
      Weekly => value.weekday() == anchor.weekday()
      _ => true
    }
  } else {
    true
  }
}

///|
// Keep a whole period until BYSETPOS has been applied. Filtering to the view
// first would incorrectly turn a partial month into a complete month.
fn recurrence_days(
  rule : DateRule,
  anchor : DateTime,
  first_day : Int32,
  end_day : Int32,
) -> Array[Int32] {
  let anchor_day = days_from_civil(anchor.year, anchor.month, anchor.day)
  let (period_year, _, _) = civil_from_days(Int32::max(first_day, anchor_day))
  // The first weekly period starts at DTSTART, while later periods start at
  // WKST. Other frequencies apply BYSETPOS to their complete calendar period.
  let start = if rule.frequency is Weekly {
    Int32::max(first_day, anchor_day)
  } else {
    first_day
  }
  let result : Array[Int32] = []
  for day in Int32::max(start, -719162)..<Int32::min(end_day, 2932897) {
    let date = locator_datetime(
      Int64::from_int(day) * 86400L,
      anchor.offset_minutes(),
    )
    if rule.matches_date(date, anchor, period_year) {
      result.push(day)
    }
  }
  result
}

///|
// Resolve positive and negative positions to unique ascending zero-based
// indices. The Cartesian product has at most 366 * 86400 elements.
fn recurrence_indices(positions : Array[Int32], length : Int32) -> Array[Int32] {
  let indices : Array[Int32] = []
  for position in positions {
    let index = if position > 0 { position - 1 } else { length + position }
    if index >= 0 && index < length && !indices.contains(index) {
      indices.push(index)
    }
  }
  indices.sort()
  indices
}

///|
// For daily and coarser frequencies, expand the clock once and share it across
// all calendar periods. Never allocate an entire year's date/time product.
fn recurrence_times(rule : DateRule, anchor : DateTime) -> Array[Int32] {
  let times : Array[Int32] = []
  for hour in recurrence_values(rule.byhour, anchor.hour) {
    for minute in recurrence_values(rule.byminute, anchor.minute) {
      for second in recurrence_values(rule.bysecond, anchor.second) {
        times.push(hour * 3600 + minute * 60 + second)
      }
    }
  }
  times
}
