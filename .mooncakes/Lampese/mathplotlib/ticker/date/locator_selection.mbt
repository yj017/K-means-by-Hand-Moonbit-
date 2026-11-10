///|
// Keep the existing scalar metadata while storing multi-value selections
// privately. No caller can mutate the internal array through a public field.
fn new_date_locator(
  kind : LocatorKind,
  interval : Int32,
  selection : Array[Int32]?,
  secondary : Int32,
) -> DateLocator {
  {
    kind,
    interval,
    selector: match selection {
      Some([first, ..]) => first
      _ => 0
    },
    secondary,
    selector_enabled: selection is Some(_),
    offset_minutes: 0,
    timezone: None,
    selection,
    secondary_selection: None,
    holidays: [],
    rule: None,
    automatic: None,
    wrapper_locator: None,
    microsecond_object: None,
  }
}

///|
// Store holidays as exact Gregorian day keys. Times, offsets, duplicates and
// caller-side array mutations must not affect a constructed locator.
fn business_holiday_days(holidays : Array[DateTime]?) -> Array[Int32] {
  let result : Array[Int32] = []
  match holidays {
    Some(values) =>
      for value in values {
        let key = days_from_civil(value.year, value.month, value.day)
        if !result.contains(key) {
          result.push(key)
        }
      }
    None => ()
  }
  result.sort()
  result
}

///|
fn positive_interval(value : Int32) -> Int32 raise DateError {
  if value < 1 {
    raise DateError::InvalidDate(message="locator interval must be positive")
  }
  value
}

///|
fn month_selector(value : Int32) -> Int32 raise DateError {
  if value < 1 || value > 12 {
    raise DateError::InvalidDate(message="month selector must be in 1..12")
  }
  value
}

///|
fn day_selector(value : Int32) -> Int32 raise DateError {
  if value < 1 || value > 31 {
    raise DateError::InvalidDate(message="day selector must be in 1..31")
  }
  value
}

///|
fn monthday_selector(value : Int32) -> Int32 raise DateError {
  if value == 0 || value < -31 || value > 31 {
    raise DateError::InvalidDate(
      message="month day selector must be in -31..-1 or 1..31",
    )
  }
  value
}

///|
fn yearday_selector(value : Int32) -> Int32 raise DateError {
  if value == 0 || value < -366 || value > 366 {
    raise DateError::InvalidDate(
      message="year day selector must be in -366..-1 or 1..366",
    )
  }
  value
}

///|
fn weekno_selector(value : Int32) -> Int32 raise DateError {
  if value == 0 || value < -53 || value > 53 {
    raise DateError::InvalidDate(
      message="week number selector must be in -53..-1 or 1..53",
    )
  }
  value
}

///|
fn easter_offset_selector(value : Int32) -> Int32 raise DateError {
  if value < -366 || value > 366 {
    raise DateError::InvalidDate(message="Easter offset must be in -366..366")
  }
  value
}

///|
fn hour_selector(value : Int32) -> Int32 raise DateError {
  if value < 0 || value > 23 {
    raise DateError::InvalidDate(message="hour selector must be in 0..23")
  }
  value
}

///|
fn minute_or_second_selector(value : Int32) -> Int32 raise DateError {
  if value < 0 || value > 59 {
    raise DateError::InvalidDate(message="time selector must be in 0..59")
  }
  value
}

///|
fn weekday_selector(value : Int32) -> Int32 raise DateError {
  if value < 0 || value > 6 {
    raise DateError::InvalidDate(
      message="weekday selector must be Monday=0 through Sunday=6",
    )
  }
  value
}

///|
// Copy and normalize on construction so caller mutations cannot change a
// locator or a shared axis. None means all fields; empty arrays are rejected.
fn locator_selection(
  single : Int32?,
  multiple : Array[Int32]?,
  wildcard : Int32?,
  default_value : Int32?,
  validate : (Int32) -> Int32 raise DateError,
) -> Array[Int32]? raise DateError {
  let values = match (single, multiple) {
    (Some(_), Some(_)) =>
      raise DateError::InvalidDate(
        message="use either a scalar selector or a selector array",
      )
    (Some(value), None) =>
      if wildcard == Some(value) {
        return None
      } else {
        [value]
      }
    (None, Some(values)) => values
    (None, None) =>
      match default_value {
        Some(value) => [value]
        None => return None
      }
  }
  if values.is_empty() {
    raise DateError::InvalidDate(message="selector array must not be empty")
  }
  let normalized : Array[Int32] = []
  for value in values {
    let value = validate(value)
    if !normalized.contains(value) {
      normalized.push(value)
    }
  }
  normalized.sort()
  Some(normalized)
}

///|
fn DateLocator::matches(self : DateLocator, value : Int32) -> Bool {
  match self.selection {
    None => true
    Some(values) => values.contains(value)
  }
}

///|
fn DateLocator::matches_monthday(self : DateLocator, value : DateTime) -> Bool {
  self.matches(value.day) ||
  self.matches(value.day - days_in_month(value.year, value.month) - 1)
}

///|
fn DateLocator::matches_business_day(
  self : DateLocator,
  value : DateTime,
) -> Bool {
  self.matches(value.weekday()) &&
  !self.holidays.contains(days_from_civil(value.year, value.month, value.day))
}
