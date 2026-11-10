// Read-only inspection helpers for parsed TZif metadata.

///|
/// Return a structural summary of the parsed TZif data.
pub fn diagnostics(tz : @types.TzifData) -> @types.TzifDiagnostics {
  let transition_count = tz.transitions.length()
  let first_transition = if transition_count == 0 {
    None
  } else {
    Some(tz.transitions[0].utc_time)
  }
  let last_transition = if transition_count == 0 {
    None
  } else {
    Some(tz.transitions[transition_count - 1].utc_time)
  }
  let standard_indicator_count = match tz.standard_indicators {
    None => 0
    Some(values) => values.length()
  }
  let utc_indicator_count = match tz.utc_indicators {
    None => 0
    Some(values) => values.length()
  }
  let has_posix_footer = tz.posix_rule is Some(_)
  {
    version: tz.version,
    transition_count,
    time_type_count: tz.time_types.length(),
    leap_second_count: tz.leap_seconds.length(),
    standard_indicator_count,
    utc_indicator_count,
    first_transition,
    last_transition,
    has_posix_footer,
    post_transition_behavior: if has_posix_footer {
      PosixFooter
    } else {
      LastExplicitType
    },
  }
}

///|
/// Return the transition at `index`, or `None` when the index is invalid.
pub fn transition_at(tz : @types.TzifData, index : Int) -> @types.Transition? {
  if index < 0 || index >= tz.transitions.length() {
    None
  } else {
    Some(tz.transitions[index])
  }
}

///|
/// Return the latest transition strictly before `utc_time`.
pub fn previous_transition(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.Transition? {
  let transitions = tz.transitions
  if transitions.length() == 0 || transitions[0].utc_time >= utc_time {
    return None
  }
  let mut low = 0
  let mut high = transitions.length() - 1
  while low < high {
    let middle = low + (high - low + 1) / 2
    if transitions[middle].utc_time < utc_time {
      low = middle
    } else {
      high = middle - 1
    }
  }
  Some(transitions[low])
}

///|
/// Return the earliest transition strictly after `utc_time`.
pub fn next_transition(
  tz : @types.TzifData,
  utc_time : Int64,
) -> @types.Transition? {
  let transitions = tz.transitions
  let length = transitions.length()
  if length == 0 || transitions[length - 1].utc_time <= utc_time {
    return None
  }
  let mut low = 0
  let mut high = length - 1
  while low < high {
    let middle = low + (high - low) / 2
    if transitions[middle].utc_time > utc_time {
      high = middle
    } else {
      low = middle + 1
    }
  }
  Some(transitions[low])
}

///|
/// Resolve a time-type index from user-constructible `TzifData` without
/// permitting a malformed in-memory table to panic an inspection tool.
fn query_time_type(
  tz : @types.TzifData,
  index : Int,
) -> @types.TzifResult[@types.TimeType] {
  if index < 0 || index >= tz.time_types.length() {
    Err(
      InvalidTransitionTable(
        "transition references missing local time type \{index}",
      ),
    )
  } else {
    Ok(tz.time_types[index])
  }
}

///|
fn query_local_boundary(
  utc_time : Int64,
  utoff : Int,
) -> @types.TzifResult[Int64] {
  let delta = utoff.to_int64()
  if (delta > 0L && utc_time > 9_223_372_036_854_775_807L - delta) ||
    (delta < 0L && utc_time < -9_223_372_036_854_775_808L - delta) {
    Err(TimestampOutOfRange(utc_time))
  } else {
    Ok(utc_time + delta)
  }
}

///|
/// Return a fully interpreted explicit transition, including both offsets and
/// the local timeline discontinuity.  The initial pre-transition type is
/// TZif time type zero by specification.
pub fn transition_detail(
  tz : @types.TzifData,
  index : Int,
) -> @types.TzifResult[@types.TransitionDetail] {
  if index < 0 || index >= tz.transitions.length() {
    return Err(
      InvalidTransitionTable("transition index \{index} is out of range"),
    )
  }
  let transition = tz.transitions[index]
  let before_index = if index == 0 {
    0
  } else {
    tz.transitions[index - 1].type_index
  }
  let before = match query_time_type(tz, before_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let after = match query_time_type(tz, transition.type_index) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let offset_change64 = after.utoff.to_int64() - before.utoff.to_int64()
  let offset_change = offset_change64.to_int()
  if offset_change.to_int64() != offset_change64 {
    return Err(TimestampOutOfRange(transition.utc_time))
  }
  let clock_change = if offset_change64 > 0L {
    @types.ClockChange::ClockForward
  } else if offset_change64 < 0L {
    ClockBackward
  } else {
    NoClockChange
  }
  let local_before = match
    query_local_boundary(transition.utc_time, before.utoff) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let local_after = match
    query_local_boundary(transition.utc_time, after.utoff) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    index,
    utc_time: transition.utc_time,
    before,
    after,
    offset_change,
    clock_change,
    local_before,
    local_after,
  })
}

///|
/// Return interpreted explicit transitions in the inclusive UTC range
/// `[start_utc, end_utc]`, ordered by timestamp.  POSIX footer rules are
/// synthetic and therefore intentionally excluded from this explicit-table
/// inspection API.
pub fn transition_details_between(
  tz : @types.TzifData,
  start_utc : Int64,
  end_utc : Int64,
) -> @types.TzifResult[Array[@types.TransitionDetail]] {
  if start_utc > end_utc {
    return Err(
      InvalidTransitionTable("transition range start must not be after its end"),
    )
  }
  let output : Array[@types.TransitionDetail] = []
  let mut low = 0
  let mut high = tz.transitions.length()
  while low < high {
    let middle = low + (high - low) / 2
    if tz.transitions[middle].utc_time < start_utc {
      low = middle + 1
    } else {
      high = middle
    }
  }
  for index in low..<tz.transitions.length() {
    if tz.transitions[index].utc_time > end_utc {
      return Ok(output)
    }
    let detail = match transition_detail(tz, index) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    output.push(detail)
  }
  Ok(output)
}
