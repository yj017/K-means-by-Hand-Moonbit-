///|
/// A UTC instant at which a fixed-offset time zone changes its offset.
///
/// The transition instant is stored as exact UTC microseconds, independent of
/// the selected epoch. The seconds offset applies at and after that instant.
pub struct TimeZoneTransition {
  priv at_microseconds : Int64
  priv offset_seconds : Int32
  priv abbreviation : String?
}

///|
/// Construct a transition at the instant represented by `at`.
///
/// The local fields and offset on `at` are converted to an instant first, so
/// callers may pass either a UTC value or a value carrying another fixed
/// offset.
pub fn timezone_transition(
  at : DateTime,
  offset_minutes : Int32,
) -> TimeZoneTransition raise DateError {
  validate_offset(offset_minutes)
  timezone_transition_seconds(at, offset_minutes * 60)
}

///|
/// Return the UTC ordinal at which this transition takes effect.
pub fn TimeZoneTransition::at(self : TimeZoneTransition) -> Double {
  unix_microseconds_to_ordinal(self.at_microseconds)
}

///|
/// Return whole offset minutes, truncated toward zero. Use `offset_seconds` for precision.
pub fn TimeZoneTransition::offset_minutes(self : TimeZoneTransition) -> Int32 {
  self.offset_seconds / 60
}

///|
/// A transition-aware zone, optionally loaded from caller-supplied IANA TZif bytes.
///
/// The transition array must be strictly increasing in UTC time. Before the first
/// transition, `initial_offset_seconds` applies; each transition then replaces
/// the previous offset.
pub struct DateTimeZone {
  priv initial_offset_seconds : Int32
  priv initial_abbreviation : String?
  priv transitions : Array[TimeZoneTransition]
  priv footer : @tztypes.PosixTzRule?
  priv dateutil_footer : Bool
  priv footer_start_seconds : Int64?
}

///|
/// Construct a transition-aware date zone.
///
/// ```mbt check
/// test {
///   let zone = try! @date.timezone(-300, transitions=[
///     try! @date.timezone_transition(@date.datetime(2024, 3, 10, hour=7), -240),
///   ])
///   let before = try! zone.to_datetime(
///     @date.datetime(2024, 3, 10, hour=6, minute=59).to_ordinal(),
///   )
///   let after = try! zone.to_datetime(
///     @date.datetime(2024, 3, 10, hour=7).to_ordinal(),
///   )
///   assert_eq((before.hour(), before.offset_minutes()), (1, -300))
///   assert_eq((after.hour(), after.offset_minutes()), (3, -240))
/// }
/// ```
pub fn timezone(
  initial_offset_minutes : Int32,
  transitions? : Array[TimeZoneTransition],
) -> DateTimeZone raise DateError {
  validate_offset(initial_offset_minutes)
  timezone_seconds(initial_offset_minutes * 60, transitions?)
}

///|
/// Construct an exact seconds-offset transition zone.
///
/// ```mbt check
/// test {
///   let zone = @date.timezone_seconds(561, transitions=[
///     @date.timezone_transition_seconds(@date.datetime(1911, 3, 11), 0),
///   ])
///   assert_eq(
///     zone.offset_seconds_at(@date.datetime(1900, 1, 1).to_ordinal()),
///     561,
///   )
/// }
/// ```
pub fn timezone_seconds(
  initial_offset_seconds : Int32,
  transitions? : Array[TimeZoneTransition],
) -> DateTimeZone raise DateError {
  validate_offset_seconds(initial_offset_seconds)
  let copied = match transitions {
    Some(values) => values.copy()
    None => []
  }
  let mut previous : Int64? = None
  for transition in copied {
    validate_offset_seconds(transition.offset_seconds)
    if transition.at_microseconds < -62_135_596_800_000_000L ||
      transition.at_microseconds >= 253_402_300_800_000_000L {
      raise DateError::InvalidDate(
        message="timezone transition is outside years 1..9999",
      )
    }
    match previous {
      Some(value) if transition.at_microseconds <= value =>
        raise DateError::InvalidDate(
          message="timezone transitions must be strictly increasing",
        )
      _ => ()
    }
    previous = Some(transition.at_microseconds)
  }
  {
    initial_offset_seconds,
    initial_abbreviation: None,
    transitions: copied,
    footer: None,
    dateutil_footer: false,
    footer_start_seconds: None,
  }
}

///|
/// Construct a zone with one fixed UTC offset and no transitions.
pub fn fixed_timezone(offset_minutes : Int32) -> DateTimeZone raise DateError {
  timezone(offset_minutes)
}

///|
/// Return initial whole minutes, truncated toward zero; use `initial_offset_seconds` for precision.
pub fn DateTimeZone::initial_offset_minutes(self : DateTimeZone) -> Int32 {
  self.initial_offset_seconds / 60
}

///|
/// Return a copy of the explicit transition table within years 1..9999.
/// POSIX footer events are evaluated on demand and are not materialized here.
pub fn DateTimeZone::transitions(
  self : DateTimeZone,
) -> Array[TimeZoneTransition] {
  self.transitions.copy()
}

///|
/// Resolve whole offset minutes, truncated toward zero. Use `offset_seconds_at` for precision.
pub fn DateTimeZone::offset_at(
  self : DateTimeZone,
  value : Double,
) -> Int32 raise DateError {
  self.offset_seconds_at(value) / 60
}

///|
/// Resolve the exact seconds offset for a UTC ordinal.
pub fn DateTimeZone::offset_seconds_at(
  self : DateTimeZone,
  value : Double,
) -> Int32 raise DateError {
  let (offset, _) = self.offset_info_at(value)
  offset
}

///|
fn DateTimeZone::offset_info_at(
  self : DateTimeZone,
  value : Double,
) -> (Int32, String?) raise DateError {
  self.offset_info_at_microseconds(ordinal_to_unix_microseconds(value))
}

///|
/// Convert a UTC ordinal to local Gregorian fields using this zone.
pub fn DateTimeZone::to_datetime(
  self : DateTimeZone,
  value : Double,
) -> DateTime raise DateError {
  let (offset_seconds, abbreviation) = self.offset_info_at(value)
  let date = from_ordinal(value, offset_seconds~)
  self.from_utc_calendar(date, offset_seconds, abbreviation)
}

///|
// Calendar generators emit date2num coordinates, whose origin is whole seconds.
// They must not acquire the public num2date subsecond-epoch displacement.
fn DateTimeZone::generated_datetime(
  self : DateTimeZone,
  value : Double,
) -> DateTime raise DateError {
  let instant = ordinal_to_unix_microseconds(value, generated=true)
  let (offset, abbreviation) = self.offset_info_at_microseconds(instant)
  let date = decoded_ordinal(value, offset, true)
  self.from_utc_calendar(date, offset, abbreviation)
}

///|
/// Convert local fields to a UTC ordinal using this zone's transition rules.
///
/// The local value's offset selects one side of an ambiguous fall transition.
/// A local time inside a skipped spring transition raises `DateError`.
pub fn DateTimeZone::to_ordinal(
  self : DateTimeZone,
  value : DateTime,
) -> Double raise DateError {
  let candidates = self.local_ordinal_candidates(value)
  if candidates.is_empty() {
    raise DateError::InvalidDate(
      message="local time does not exist in timezone",
    )
  }
  let preferred = value.to_ordinal()
  if candidates.contains(preferred) {
    preferred
  } else {
    candidates[0]
  }
}

///|
// Return every UTC instant that has these local fields in this zone. The
// result is empty for a spring-forward gap and contains two values for a
// fall-back fold.
fn DateTimeZone::local_ordinal_candidates(
  self : DateTimeZone,
  value : DateTime,
) -> Array[Double] {
  let offsets = self.offsets()
  if !offsets.contains(value.offset_seconds) {
    offsets.push(value.offset_seconds)
  }
  let result : Array[Double] = []
  for offset in offsets {
    let instant = locator_microseconds(value) -
      Int64::from_int(offset) * 1_000_000L
    if instant < -62_135_596_800_000_000L || instant >= 253_402_300_800_000_000L {
      continue
    }
    let (active, _) = self.offset_info_at_microseconds(instant) catch {
      _ => continue
    }
    if active == offset {
      let ordinal = unix_microseconds_to_ordinal(instant)
      if !result.contains(ordinal) {
        result.push(ordinal)
      }
    }
  }
  result.sort()
  result
}

///|
/// Convert an instant represented by this value to a transition-aware zone.
pub fn DateTime::with_timezone(
  self : DateTime,
  zone : DateTimeZone,
) -> DateTime raise DateError {
  let instant = rruleset_instant(self)
  if instant < -62_135_596_800_000_000L || instant >= 253_402_300_800_000_000L {
    raise DateError::InvalidDate(message="instant is outside years 1..9999")
  }
  let (offset, name) = zone.offset_info_at_microseconds(instant)
  zone.from_utc_calendar(
    datetime_from_microseconds(
      instant + Int64::from_int(offset) * 1_000_000L,
      offset,
    ),
    offset,
    name,
  )
}

///|
fn validate_timezone_ordinal(value : Double) -> Unit raise DateError {
  ignore(ordinal_to_unix_microseconds(value))
}

///|
/// Construct a transition using an exact seconds offset east of UTC.
pub fn timezone_transition_seconds(
  at : DateTime,
  offset_seconds : Int32,
) -> TimeZoneTransition raise DateError {
  validate_offset_seconds(offset_seconds)
  { at_microseconds: rruleset_instant(at), offset_seconds, abbreviation: None, }
}

///|
/// Return the exact offset that takes effect at this transition.
pub fn TimeZoneTransition::offset_seconds(self : TimeZoneTransition) -> Int32 {
  self.offset_seconds
}

///|
/// Construct a fixed zone with an exact seconds offset east of UTC.
pub fn fixed_timezone_seconds(
  offset_seconds : Int32,
) -> DateTimeZone raise DateError {
  timezone_seconds(offset_seconds)
}

///|
/// Return the exact initial offset east of UTC, in seconds.
pub fn DateTimeZone::initial_offset_seconds(self : DateTimeZone) -> Int32 {
  self.initial_offset_seconds
}

///|
// All possible offsets supply local conversion candidates and a safe heap
// watermark, including historical and POSIX future-rule offsets.
fn DateTimeZone::offsets(self : DateTimeZone) -> Array[Int32] {
  let offsets = [self.initial_offset_seconds]
  for transition in self.transitions {
    if !offsets.contains(transition.offset_seconds) {
      offsets.push(transition.offset_seconds)
    }
  }
  match self.footer {
    Some(rule) => {
      if !offsets.contains(rule.std_offset) {
        offsets.push(rule.std_offset)
      }
      match rule.dst_offset {
        Some(offset) => if !offsets.contains(offset) { offsets.push(offset) }
        None => ()
      }
    }
    None => ()
  }
  offsets
}

///|
// Exact datetime arithmetic uses integer instants. Its sub-microsecond
// classification must not round through Matplotlib's floating day ordinals.
fn DateTimeZone::offset_info_at_microseconds(
  self : DateTimeZone,
  value : Int64,
) -> (Int32, String?) raise DateError {
  // Local years 1..9999 can temporarily map just outside the UTC calendar
  // during aware arithmetic. Keep lookup available there, as datetime does;
  // public numeric conversions retain their own supported-range validation.
  let seconds = locator_floor_div64(value, 1_000_000L)
  if self.dateutil_footer && self.footer is Some(rule) {
    return dateutil_posix_info(rule, seconds)
  }
  match self.footer {
    Some(rule) if self.footer_start_seconds is None ||
      seconds >= self.footer_start_seconds.unwrap() =>
      match @tzposix.apply_posix_rule(rule, seconds) {
        Ok((offset, _, name)) => return (offset, Some(name))
        Err(_) =>
          raise DateError::InvalidDate(
            message="cannot resolve TZif future rule",
          )
      }
    _ => ()
  }
  let mut low = 0
  let mut high = self.transitions.length()
  while low < high {
    let middle = low + (high - low) / 2
    if self.transitions[middle].at_microseconds <= value {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low == 0 {
    (self.initial_offset_seconds, self.initial_abbreviation)
  } else {
    let transition = self.transitions[low - 1]
    (transition.offset_seconds, transition.abbreviation)
  }
}

///|
/// Unit equality for retained rule-zone identities and fixed-offset snapshots.
/// Fixed offsets compare by seconds, including independently constructed values;
/// rule-based zones retain their object identity.
pub fn DateTimeZone::unit_equal(
  self : DateTimeZone,
  other : DateTimeZone,
) -> Bool {
  physical_equal(self, other) ||
  (
    self.footer is None &&
    other.footer is None &&
    self.transitions.is_empty() &&
    other.transitions.is_empty() &&
    self.initial_offset_seconds == other.initial_offset_seconds
  )
}
