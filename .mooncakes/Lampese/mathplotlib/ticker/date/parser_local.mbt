///|
fn DateParserContext::naive_dst(
  self : DateParserContext,
  value : DateTime,
  snapshot : ParserLocalSnapshot,
  shift~ : Int32 = 0,
) -> Bool raise DateError {
  let (_, dst, _) = self.info(
    locator_seconds(value) - Int64::from_int(snapshot.standard + shift),
  )
  dst
}

///|
fn DateParserContext::local_info(
  self : DateParserContext,
  value : DateTime,
  snapshot : ParserLocalSnapshot,
  fold : Bool,
) -> (Int32, String) raise DateError {
  if snapshot.standard == snapshot.daylight {
    return (snapshot.standard, snapshot.standard_name)
  }
  let naive = self.naive_dst(value, snapshot)
  let saved = snapshot.daylight - snapshot.standard
  let ambiguous = !naive &&
    naive != self.naive_dst(value, snapshot, shift=saved)
  let dst = if ambiguous { !fold } else { naive }
  if dst {
    (snapshot.daylight, snapshot.daylight_name)
  } else {
    (snapshot.standard, snapshot.standard_name)
  }
}

///|
fn parser_default_fold(fallback : DateTime) -> Bool raise DateError {
  match fallback.timezone {
    Some(zone) =>
      zone.resolve_arithmetic_local(fallback).offset_seconds !=
      fallback.offset_seconds
    None => false
  }
}

///|
fn parser_set_offset(
  value : DateTime,
  offset : Int32,
  name : String?,
) -> DateTime raise DateError {
  validate_offset_seconds(offset)
  {
    ..value,
    offset_seconds: offset,
    offset_minutes: offset / 60,
    abbreviation: name,
    timezone: None,
  }
}

///|
// date2num's first-aware array branch calls astimezone on later naive values.
// Unlike tzlocal, this uses the actual host rules, with reversed gap preference.
fn DateParserContext::interpret_naive(
  self : DateParserContext,
  value : DateTime,
  fold : Bool,
) -> DateTime raise DateError {
  let mut seconds = self.local_to_seconds(value, fold)
  let other = self.local_to_seconds(value, !fold)
  if other != seconds && (other > seconds) == fold {
    seconds = other
  }
  let (offset, _, _) = self.info(seconds)
  parser_set_offset(value, offset, None)
}

///|
// CPython's local() constructs a year-1..9999 calendar result for each probe.
// The fold search can fail at either endpoint even when the final UTC date fits.
fn DateParserContext::local_seconds(
  self : DateParserContext,
  seconds : Int64,
) -> Int64 raise DateError {
  let (offset, _, _) = self.info(seconds)
  let wall = seconds + Int64::from_int(offset)
  if wall < -62135596800L || wall >= 253402300800L {
    raise DateError::InvalidDate(
      message="host local datetime probe is outside years 1..9999",
    )
  }
  wall
}

///|
fn DateParserContext::local_to_seconds(
  self : DateParserContext,
  value : DateTime,
  fold : Bool,
) -> Int64 raise DateError {
  let target = locator_seconds(value)
  let first_offset = self.local_seconds(target) - target
  let first = target - first_offset
  let first_wall = self.local_seconds(first)
  let second_offset = if first_wall == target {
    let probe = first + (if fold { 86400L } else { -86400L })
    let offset = self.local_seconds(probe) - probe
    if first_offset == offset {
      return first
    }
    offset
  } else {
    first_wall - first
  }
  let second = target - second_offset
  let second_wall = self.local_seconds(second)
  if second_wall == target {
    return second
  }
  if first_wall == target {
    return first
  }
  if fold {
    Int64::min(first, second)
  } else {
    Int64::max(first, second)
  }
}
