///|
// Resolve signed month days; invalid days are skipped, not clamped.
fn locator_month_date(
  year : Int32,
  month : Int32,
  monthday : Int32,
  offset_minutes : Int32,
) -> DateTime? {
  let length = days_in_month(year, month)
  let day = if monthday > 0 { monthday } else { length + monthday + 1 }
  Some(datetime(year, month, day, offset_minutes~)) catch {
    _ => None
  }
}

///|
fn year_ticks(
  locator : DateLocator,
  first : DateTime,
  last : DateTime,
) -> Array[Double] {
  let step = Int64::from_int(locator.interval)
  let first_year = Int64::max(1L, Int64::from_int(first.year) / step * step)
  let last_year = Int64::min(
    9999L,
    locator_ceil_div64(Int64::from_int(last.year), step) * step,
  )
  let result : Array[Double] = []
  for year = first_year; year <= last_year; year = year + step {
    match
      locator_month_date(
        year.to_int(),
        locator.selector(),
        locator.secondary,
        locator.offset_minutes,
      ) {
      Some(date) =>
        for value in locator.ordinals_for_date(date) {
          result.push(value)
        }
      None => ()
    }
  }
  result
}

///|
fn month_ticks(
  locator : DateLocator,
  first_ordinal : Double,
  last_ordinal : Double,
  first : DateTime,
  last : DateTime,
  anchor : DateTime,
) -> Array[Double] {
  let step = Int64::from_int(locator.interval)
  let first_index = Int64::from_int(first.year * 12 + first.month - 1)
  let last_index = Int64::from_int(last.year * 12 + last.month - 1)
  let anchor_index = Int64::from_int(anchor.year * 12 + anchor.month - 1)
  let result : Array[Double] = []
  let start = locator_align(first_index, anchor_index, step)
  for current = start
      current <= last_index && result.length() < 100000
      current = current + step {
    let year = (current / 12L).to_int()
    let month = (current % 12L).to_int() + 1
    if locator.matches(month) {
      match
        locator_month_date(
          year,
          month,
          locator.secondary,
          locator.offset_minutes,
        ) {
        Some(date) =>
          locator_push_date_ticks(
            result, locator, date, first_ordinal, last_ordinal,
          )
        None => ()
      }
    }
  }
  result
}

///|
fn locator_day_ticks(
  locator : DateLocator,
  first_ordinal : Double,
  last_ordinal : Double,
  first : DateTime,
  last : DateTime,
  anchor : DateTime,
) -> Array[Double] {
  let step = Int64::from_int(locator.interval)
  let first_day = locator_floor_div64(locator_seconds(first), 86400L)
  let last_day = locator_floor_div64(locator_seconds(last), 86400L)
  let anchor_day = locator_floor_div64(locator_seconds(anchor), 86400L)
  let result : Array[Double] = []
  let start = locator_align(first_day, anchor_day, step)
  for current = start
      current <= last_day && result.length() < 100000
      current = current + step {
    let date = locator_datetime(current * 86400L, locator.offset_minutes)
    let matches = match locator.kind {
      Days => locator.matches_monthday(date)
      Weekdays => locator.matches(date.weekday())
      BusinessDays => locator.matches_business_day(date)
      _ => false
    }
    if matches {
      locator_push_date_ticks(
        result, locator, date, first_ordinal, last_ordinal,
      )
    }
  }
  result
}
