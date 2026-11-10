// UTC -> local conversion over TZif transition intervals.

///|
/// Find the last transition whose UTC timestamp is at most `target`.
/// Returns -1 when `target` is before the first transition.
fn find_transition(
  transitions : Array[@types.Transition],
  target : Int64,
) -> Int {
  if transitions.length() == 0 || transitions[0].utc_time > target {
    return -1
  }
  let mut low = 0
  let mut high = transitions.length() - 1
  while low < high {
    let middle = low + (high - low + 1) / 2
    if transitions[middle].utc_time <= target {
      low = middle
    } else {
      high = middle - 1
    }
  }
  low
}

///|
/// Return a checked local-time type from a publicly constructible `TzifData`.
fn checked_time_type(
  tz : @types.TzifData,
  type_index : Int,
) -> @types.TzifResult[@types.TimeType] {
  if type_index < 0 || type_index >= tz.time_types.length() {
    Err(
      InvalidTransitionTable(
        "transition references missing local time type \{type_index}",
      ),
    )
  } else {
    Ok(tz.time_types[type_index])
  }
}

///|
/// Determine the active type for a UTC timestamp.
///
/// TZif specifies time type zero before the first transition. A non-empty
/// footer controls timestamps after the final transition; otherwise the last
/// explicit type is retained as this library's documented compatibility
/// behaviour for the RFC-unspecified range.
fn effective_ttinfo(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.TzifResult[(Int, Bool, String)] {
  if tz.time_types.length() == 0 {
    return Err(InvalidTransitionTable("TZif has no local time types"))
  }

  let index = find_transition(tz.transitions, utc_time)
  if index >= 0 {
    if index + 1 < tz.transitions.length() || tz.posix_rule is None {
      let time_type = match
        checked_time_type(tz, tz.transitions[index].type_index) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      return Ok((time_type.utoff, time_type.is_dst, time_type.abbr))
    }
    match tz.posix_rule {
      Some(rule) => @posix.apply_posix_rule(rule, utc_time)
      None => {
        let time_type = match
          checked_time_type(tz, tz.transitions[index].type_index) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        Ok((time_type.utoff, time_type.is_dst, time_type.abbr))
      }
    }
  } else {
    // A transition-less TZif with a POSIX footer is a rule-only zone. For a
    // non-empty table, the period before its first transition remains type 0.
    if tz.transitions.length() == 0 {
      match tz.posix_rule {
        Some(rule) => return @posix.apply_posix_rule(rule, utc_time)
        None => ()
      }
    }
    let time_type = match checked_time_type(tz, 0) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    Ok((time_type.utoff, time_type.is_dst, time_type.abbr))
  }
}

///|
/// Return the offset metadata active at `utc_time` without decomposing it into
/// calendar fields.  `source` distinguishes an initial type, an explicit TZif
/// transition and a POSIX-footer extrapolation, which is useful to callers
/// deciding how much historical data backs a displayed value.
pub fn active_offset(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.TzifResult[@types.OffsetInfo] {
  let (utoff, is_dst, abbr) = match effective_ttinfo(tz, utc_time) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let transition_index = find_transition(tz.transitions, utc_time)
  let source = if transition_index < 0 {
    if tz.transitions.length() == 0 && tz.posix_rule is Some(_) {
      @types.OffsetSource::PosixFooter
    } else {
      InitialType
    }
  } else if transition_index + 1 < tz.transitions.length() ||
    tz.posix_rule is None {
    ExplicitTransition(transition_index)
  } else {
    PosixFooter
  }
  Ok({ utoff, is_dst, abbr, source })
}

///|
/// Convert a UTC timestamp to local civil time and accompanying TZ metadata.
pub fn utc_to_local(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.TzifResult[@types.LocalDateTime] {
  let active = match active_offset(tz, utc_time) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let local_epoch = match
    @posix.checked_add_epoch_seconds(utc_time, active.utoff.to_int64()) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (year, month, day, hour, minute, second) = match
    @posix.decompose_epoch(local_epoch) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    year,
    month,
    day,
    hour,
    minute,
    second,
    utoff: active.utoff,
    is_dst: active.is_dst,
    abbr: active.abbr,
  })
}
