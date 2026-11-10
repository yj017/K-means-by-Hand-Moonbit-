///|
priv enum DateInterval {
  Microseconds(Int32)
  Subday(Double)
  Days(Int32)
  Months(Int32)
  Years(Int32)
}

///|
fn interval_at_most(target : Double, limit : Double) -> Bool {
  target <= limit + 1.0e-12 * Double::max(1.0, Double::abs(limit))
}

///|
fn choose_interval(span : Double, count : Int32) -> DateInterval {
  let target = span / Double::from_int(if count < 2 { 2 } else { count - 1 })
  if target < 1.0 / 86400.0 {
    Microseconds(microsecond_interval(target * 86_400_000_000.0))
  } else if interval_at_most(target, 1.0 / 86400.0) {
    Subday(1.0 / 86400.0)
  } else if interval_at_most(target, 5.0 / 86400.0) {
    Subday(5.0 / 86400.0)
  } else if interval_at_most(target, 15.0 / 86400.0) {
    Subday(15.0 / 86400.0)
  } else if interval_at_most(target, 30.0 / 86400.0) {
    Subday(30.0 / 86400.0)
  } else if interval_at_most(target, 1.0 / 1440.0) {
    Subday(1.0 / 1440.0)
  } else if interval_at_most(target, 5.0 / 1440.0) {
    Subday(5.0 / 1440.0)
  } else if interval_at_most(target, 15.0 / 1440.0) {
    Subday(15.0 / 1440.0)
  } else if interval_at_most(target, 30.0 / 1440.0) {
    Subday(30.0 / 1440.0)
  } else if interval_at_most(target, 1.0 / 24.0) {
    Subday(1.0 / 24.0)
  } else if interval_at_most(target, 1.0 / 12.0) {
    Subday(1.0 / 12.0)
  } else if interval_at_most(target, 1.0 / 6.0) {
    Subday(1.0 / 6.0)
  } else if interval_at_most(target, 0.5) {
    Subday(0.5)
  } else if interval_at_most(target, 1.0) {
    Days(1)
  } else if interval_at_most(target, 2.0) {
    Days(2)
  } else if interval_at_most(target, 7.0) {
    Days(7)
  } else if interval_at_most(target, 14.0) {
    Days(14)
  } else if interval_at_most(target, 45.0) {
    Months(1)
  } else if interval_at_most(target, 135.0) {
    Months(3)
  } else if interval_at_most(target, 300.0) {
    Months(6)
  } else if interval_at_most(target, 730.0) {
    Years(1)
  } else if interval_at_most(target, 1825.0) {
    Years(5)
  } else {
    Years(10)
  }
}

///|
fn date_from_ordinal(value : Double, offset_minutes : Int32) -> DateTime? {
  Some(from_ordinal(value, offset_minutes~)) catch {
    _ => None
  }
}

///|
fn month_start(
  year : Int32,
  month : Int32,
  offset_minutes : Int32,
) -> DateTime? {
  if year < 1 || year > 9999 || month < 1 || month > 12 {
    None
  } else {
    Some(try! datetime(year, month, 1, offset_minutes~))
  }
}

///|
fn add_months(date : DateTime, months : Int32) -> DateTime? {
  let absolute = date.year() * 12 + date.month() - 1 + months
  let year = absolute / 12
  let month = absolute % 12 + 1
  month_start(year, month, date.offset_minutes())
}

///|
fn aligned_month_start(date : DateTime, interval : Int32) -> DateTime? {
  let month_index = date.year() * 12 + date.month() - 1
  let aligned = month_index / interval * interval
  month_start(aligned / 12, aligned % 12 + 1, date.offset_minutes())
}

///|
fn aligned_year_start(date : DateTime, interval : Int32) -> DateTime? {
  let year = (date.year() - 1) / interval * interval + 1
  month_start(year, 1, date.offset_minutes())
}

///|
fn subday_ticks(
  first : Double,
  last : Double,
  interval : Double,
) -> Array[Double] {
  let start = (first / interval).floor() * interval
  let result = Array(capacity=8)
  let mut value = start
  let mut steps = 0
  while value <= last + interval * 1.0e-9 && steps < 10000 {
    if value >= first - interval * 1.0e-9 {
      result.push(value)
    }
    value = value + interval
    steps = steps + 1
  }
  result
}

///|
fn day_ticks(first : Double, last : Double, interval : Int32) -> Array[Double] {
  let step = Double::from_int(interval)
  let start = (first / step).floor() * step
  let result = Array(capacity=8)
  let mut value = start
  let mut steps = 0
  while value <= last + step * 1.0e-9 && steps < 10000 {
    if value >= first - step * 1.0e-9 {
      result.push(value)
    }
    value = value + step
    steps = steps + 1
  }
  result
}

///|
fn shifted_subday_ticks(
  first : Double,
  last : Double,
  interval : Double,
  offset_minutes : Int32,
) -> Array[Double] {
  let (_, remainder) = delta_split(selected_epoch().seconds, 86400L)
  let shift = (remainder.to_double() + Double::from_int(offset_minutes) * 60.0) /
    86400.0
  let shifted = subday_ticks(first + shift, last + shift, interval)
  shifted.map(value => value - shift)
}

///|
fn shifted_day_ticks(
  first : Double,
  last : Double,
  interval : Int32,
  offset_minutes : Int32,
) -> Array[Double] {
  let (days, remainder) = delta_split(selected_epoch().seconds, 86400L)
  let shift = (days % Int64::from_int(interval)).to_double() +
    (remainder.to_double() + Double::from_int(offset_minutes) * 60.0) / 86400.0
  let shifted = day_ticks(first + shift, last + shift, interval)
  shifted.map(value => value - shift)
}

///|
fn calendar_ticks(
  first : Double,
  last : Double,
  interval : DateInterval,
  offset_minutes : Int32,
) -> Array[Double] {
  let first_date = match date_from_ordinal(first, offset_minutes) {
    Some(value) => value
    None => return []
  }
  match interval {
    Microseconds(step) => microsecond_ticks(first, last, step)
    Subday(step) => shifted_subday_ticks(first, last, step, offset_minutes)
    Days(step) => shifted_day_ticks(first, last, step, offset_minutes)
    Months(step) => {
      let start = match aligned_month_start(first_date, step) {
        Some(value) => value
        None => return []
      }
      let result = Array(capacity=8)
      let mut current = start
      let mut steps = 0
      while current.to_ordinal() <= last + 1.0e-9 && steps < 10000 {
        let ordinal = current.to_ordinal()
        if ordinal >= first - 1.0e-9 {
          result.push(ordinal)
        }
        current = match add_months(current, step) {
          Some(value) => value
          None => break
        }
        steps = steps + 1
      }
      result
    }
    Years(step) => {
      let start = match aligned_year_start(first_date, step) {
        Some(value) => value
        None => return []
      }
      let result = Array(capacity=8)
      let mut current = start
      let mut steps = 0
      while current.to_ordinal() <= last + 1.0e-9 && steps < 10000 {
        let ordinal = current.to_ordinal()
        if ordinal >= first - 1.0e-9 {
          result.push(ordinal)
        }
        current = match add_months(current, step * 12) {
          Some(value) => value
          None => break
        }
        steps = steps + 1
      }
      result
    }
  }
}

///|
/// Generate deterministic date tick values for a numeric day range.
/// A `timezone` aligns local calendar candidates using exact transition and
/// footer offsets, skipping gaps and retaining both sides of folds.
pub fn date_tick_values(
  lower : Double,
  upper : Double,
  count~ : Int32 = 6,
  offset_minutes~ : Int32 = 0,
  timezone? : DateTimeZone,
) -> Array[Double] {
  if lower.is_nan() || upper.is_nan() || lower.is_inf() || upper.is_inf() {
    return []
  }
  if offset_minutes <= -1440 || offset_minutes >= 1440 {
    return []
  }
  if lower == upper {
    return [lower]
  }
  let ascending = lower <= upper
  let first = Double::min(lower, upper)
  let last = Double::max(lower, upper)
  let interval = choose_interval(last - first, count)
  let result = match timezone {
    Some(zone) => timezone_calendar_ticks(first, last, interval, zone)
    None => calendar_ticks(first, last, interval, offset_minutes)
  }
  if ascending {
    result
  } else {
    result.rev()
  }
}

///|
fn timezone_calendar_ticks(
  first : Double,
  last : Double,
  interval : DateInterval,
  zone : DateTimeZone,
) -> Array[Double] {
  if interval is Microseconds(step) {
    return microsecond_ticks(first, last, step)
  }
  let first_date = zone.to_datetime(first) catch { _ => return [] }
  let last_date = zone.to_datetime(last) catch { _ => return [] }
  let (local_first, local_last, _) = recurrence_timezone_local_bounds(
    zone, first, last, first_date, last_date,
  )
  let first_local = unix_microseconds_to_ordinal(
    locator_microseconds(local_first),
  )
  let last_local = unix_microseconds_to_ordinal(
    locator_microseconds(local_last),
  )
  let result : Array[Double] = []
  for wall in calendar_ticks(first_local, last_local, interval, 0) {
    let date = forward_calendar_date(wall) catch { _ => continue }
    for ordinal in zone.local_ordinal_candidates(date) {
      if ordinal >= first && ordinal <= last {
        result.push(ordinal)
      }
    }
  }
  result.sort()
  result
}
