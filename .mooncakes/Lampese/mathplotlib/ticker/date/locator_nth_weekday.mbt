///|
fn locator_nth_weekday_date(
  year : Int32,
  month : Int32,
  weekday : Int32,
  ordinal : Int32,
  offset_minutes : Int32,
) -> DateTime? {
  let last_day = days_in_month(year, month)
  let day = if ordinal > 0 {
    let first_weekday = weekday_from_civil(year, month, 1)
    let offset = (weekday - first_weekday + 7) % 7
    1 + offset + (ordinal - 1) * 7
  } else {
    let last_weekday = weekday_from_civil(year, month, last_day)
    let offset = (last_weekday - weekday + 7) % 7
    last_day - offset + (ordinal + 1) * 7
  }
  if day < 1 || day > last_day {
    None
  } else {
    Some(datetime(year, month, day, offset_minutes~)) catch {
      _ => None
    }
  }
}

///|
fn nth_weekday_ticks(
  locator : DateLocator,
  first_ordinal : Double,
  last_ordinal : Double,
  first : DateTime,
  last : DateTime,
) -> Array[Double] {
  let step = Int64::from_int(locator.interval)
  let first_index = Int64::from_int(first.year * 12 + first.month - 1)
  let last_index = Int64::from_int(last.year * 12 + last.month - 1)
  let anchor = recurrence_start(first, last)
  let anchor_index = Int64::from_int(anchor.year * 12 + anchor.month - 1)
  let result : Array[Double] = []
  let start = locator_align(first_index, anchor_index, step)
  for current = start
      current <= last_index && result.length() < 100000
      current = current + step {
    let year = (current / 12L).to_int()
    let month = (current % 12L).to_int() + 1
    if locator.matches(month) {
      let candidates : Array[Double] = []
      for weekday in locator.secondary_selection.unwrap() {
        match
          locator_nth_weekday_date(
            year,
            month,
            weekday,
            locator.secondary,
            locator.offset_minutes,
          ) {
          Some(date) =>
            for value in locator.ordinals_for_date(date) {
              locator_push_tick(candidates, value, first_ordinal, last_ordinal)
            }
          None => ()
        }
      }
      candidates.sort()
      for value in candidates {
        if result.length() >= 100000 {
          break
        }
        result.push(value)
      }
    }
  }
  result
}
