///|
// datetime compares/subtracts in wall time only for the same tzinfo object.
// Fixed-offset values with equal offsets have the same result either way.
fn relative_date_difference(first : DateTime, second : DateTime) -> Int64 {
  let same_zone = match (first.timezone, second.timezone) {
    (Some(a), Some(b)) => physical_equal(a, b)
    (None, None) => first.offset_seconds == second.offset_seconds
    _ => false
  }
  if same_zone {
    locator_microseconds(first) - locator_microseconds(second)
  } else {
    rruleset_instant(first) - rruleset_instant(second)
  }
}

///|
/// Construct first - second using calendar years/months and the remaining wall
/// or instant duration. Matching rule-zone handles follow datetime's same-tzinfo
/// semantics. Construction does not read the date epoch or display timezone rc.
pub fn RelativeDelta::between(
  first : DateTime,
  second : DateTime,
) -> RelativeDelta raise DateError {
  let mut months = Int64::from_int(
    (first.year - second.year) * 12 + first.month - second.month,
  )
  let mut delta = RelativeDelta::new(months~)
  let mut adjusted = second.add_relative_delta(delta)
  let backwards = relative_date_difference(first, second) < 0L
  while (if backwards {
          relative_date_difference(first, adjusted) > 0L
        } else {
          relative_date_difference(first, adjusted) < 0L
        }) {
    months += if backwards { 1L } else { -1L }
    delta = RelativeDelta::new(months~)
    adjusted = second.add_relative_delta(delta)
  }
  let (seconds, microseconds) = delta_split(
    relative_date_difference(first, adjusted),
    1000000L,
  )
  RelativeDelta::new(
    years=delta.years,
    months=Int64::from_int(delta.months),
    seconds=seconds.to_double(),
    microseconds=microseconds.to_double(),
  )
}
