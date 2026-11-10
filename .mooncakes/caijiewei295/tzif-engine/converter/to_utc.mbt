// Local time -> UTC conversion by candidate validation.

///|
fn has_offset(offsets : Array[Int], offset : Int) -> Bool {
  for existing in offsets {
    if existing == offset {
      return true
    }
  }
  false
}

///|
fn same_civil_time(
  actual : @types.LocalDateTime,
  expected : @types.LocalDateTime,
) -> Bool {
  actual.year == expected.year &&
  actual.month == expected.month &&
  actual.day == expected.day &&
  actual.hour == expected.hour &&
  actual.minute == expected.minute &&
  actual.second == expected.second
}

///|
/// Insert a UTC candidate in ascending order.  Candidate offsets are unique,
/// but sorting here also makes the public API deterministic for arbitrary
/// historical type tables.
fn insert_candidate(candidates : Array[Int64], candidate : Int64) -> Unit {
  candidates.push(candidate)
  let mut index = candidates.length() - 1
  while index > 0 && candidates[index] < candidates[index - 1] {
    let previous = candidates[index - 1]
    candidates[index - 1] = candidates[index]
    candidates[index] = previous
    index = index - 1
  }
}

///|
/// Collect every offset that can be relevant to a parsed TZif. Candidate UTC
/// instants are subsequently round-tripped through `utc_to_local`, so this
/// deliberately does not assume local transition starts are sorted.
fn candidate_offsets(tz : @types.TzifData) -> Array[Int] {
  let offsets : Array[Int] = []
  for time_type in tz.time_types {
    if !has_offset(offsets, time_type.utoff) {
      offsets.push(time_type.utoff)
    }
  }
  match tz.posix_rule {
    None => ()
    Some(rule) => {
      if !has_offset(offsets, rule.std_offset) {
        offsets.push(rule.std_offset)
      }
      match rule.dst_offset {
        None => ()
        Some(offset) => if !has_offset(offsets, offset) { offsets.push(offset) }
      }
    }
  }
  offsets
}

///|
/// Return every UTC instant which round-trips to `ldt` in ascending order.
///
/// An empty result identifies a spring-forward (or historical) gap, one item
/// identifies ordinary wall time, and multiple items identify an overlap.
/// This is the lossless counterpart to `local_to_utc`, whose strategy selects
/// only one of these candidates.
pub fn local_time_candidates(
  tz : @types.TzifData,
  ldt : @types.LocalDateTime,
) -> @types.TzifResult[Array[Int64]] {
  if tz.time_types.length() == 0 {
    return Err(InvalidTransitionTable("TZif has no local time types"))
  }
  if !@posix.is_valid_date(ldt.year, ldt.month, ldt.day) ||
    !@posix.is_valid_civil_time(ldt.hour, ldt.minute, ldt.second) {
    return Err(InvalidLocalTime(ldt))
  }

  let local_epoch = match
    @posix.compose_epoch(
      ldt.year,
      ldt.month,
      ldt.day,
      ldt.hour,
      ldt.minute,
      ldt.second,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let candidates : Array[Int64] = []
  for offset in candidate_offsets(tz) {
    let candidate = match
      @posix.checked_sub_epoch_seconds(local_epoch, offset.to_int64()) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match utc_to_local(tz, candidate) {
      Err(error) => return Err(error)
      Ok(round_trip) =>
        if same_civil_time(round_trip, ldt) {
          insert_candidate(candidates, candidate)
        }
    }
  }
  Ok(candidates)
}

///|
/// Classify a local civil time without discarding overlap candidates.
pub fn resolve_local(
  tz : @types.TzifData,
  ldt : @types.LocalDateTime,
) -> @types.TzifResult[@types.LocalTimeResolution] {
  let candidates = match local_time_candidates(tz, ldt) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if candidates.length() == 0 {
    Ok(Gap)
  } else if candidates.length() == 1 {
    Ok(Unique(candidates[0]))
  } else {
    Ok(Ambiguous(candidates))
  }
}

///|
/// Convert local wall time to UTC.
///
/// Each possible offset produces a candidate instant. The candidate is valid
/// only when formatting it back with the full TZif rules reproduces exactly
/// the requested civil fields. This directly models gaps and overlaps and is
/// robust even when historical offset changes make local starts non-monotonic.
pub fn local_to_utc(
  tz : @types.TzifData,
  ldt : @types.LocalDateTime,
  strategy : @types.AmbiguityStrategy,
) -> @types.TzifResult[Int64] {
  match resolve_local(tz, ldt) {
    Err(error) => Err(error)
    Ok(Gap) => Err(InvalidLocalTime(ldt))
    Ok(Unique(utc_time)) => Ok(utc_time)
    Ok(Ambiguous(candidates)) =>
      match strategy {
        PreferEarlier => Ok(candidates[0])
        PreferLater => Ok(candidates[candidates.length() - 1])
      }
  }
}
