///|
fn locator_gcd(left : Int32, right : Int32) -> Int32 {
  for a = left, b = right; b != 0; {
    continue b, a % b
  } nobreak {
    a
  }
}

///|
fn time_ticks(
  locator : DateLocator,
  first_ordinal : Double,
  last_ordinal : Double,
  first : DateTime,
  last : DateTime,
  anchor : DateTime,
  unit : Int32,
  fields : Int32,
) -> Array[Double] {
  let unit64 = Int64::from_int(unit)
  let step = Int64::from_int(locator.interval)
  let first_unit = locator_floor_div64(locator_seconds(first), unit64)
  let last_unit = locator_floor_div64(locator_seconds(last), unit64)
  let anchor_unit = locator_floor_div64(locator_seconds(anchor), unit64)
  let start = locator_align(first_unit, anchor_unit, step)
  // A selector repeats after at most 24 or 60 recurrence steps. Precompute
  // reachable fields so sparse or impossible filters never scan entire years
  // second by second, and so the tick cap counts output, not skipped candidates.
  let period = match locator.selection {
    None => 1
    Some(_) => fields / locator_gcd(locator.interval, fields)
  }
  let offsets : Array[Int64] = []
  for index in 0..<period {
    let offset = Int64::from_int(index) * step
    let field = ((start + offset) % Int64::from_int(fields)).to_int()
    let field = if field < 0 { field + fields } else { field }
    if locator.matches(field) {
      offsets.push(offset)
    }
  }
  let result : Array[Double] = []
  if offsets.is_empty() {
    return result
  }
  let cycle = Int64::from_int(period) * step
  for base = start
      base <= last_unit && result.length() < 100000
      base = base + cycle {
    for offset in offsets {
      let current = base + offset
      if current > last_unit || result.length() >= 100000 {
        break
      }
      for
        ordinal in locator.ordinals_for_date(
          locator_datetime(current * unit64, locator.offset_minutes),
        ) {
        locator_push_tick(result, ordinal, first_ordinal, last_ordinal)
      }
    }
  }
  result
}
