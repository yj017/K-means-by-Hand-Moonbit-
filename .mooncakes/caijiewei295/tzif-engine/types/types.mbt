// Core types for the TZif timezone data model.

// A complete TZif local time type (`ttinfo`).
//
// Time type zero is meaningful: TZif uses it before the first transition and
// for a transition-less file without a POSIX footer.  It must therefore remain
// in the parsed model even when no transition refers to it.

///|
pub(all) struct TimeType {
  utoff : Int // offset in seconds east of UTC
  is_dst : Bool // whether this is a daylight-saving type
  abbr : String // timezone abbreviation (for example, "EST")
}

///|
// A single transition point where the active local time type changes.
pub(all) struct Transition {
  utc_time : Int64 // UTC timestamp when this transition takes effect
  type_index : Int // index into TzifData.time_types
}

///|
/// A leap-second correction record retained from the second TZif data block.
///
/// `transition_time` is expressed in UNIX leap-time seconds and `correction`
/// is the total correction after that instant, as defined by RFC 9636.
/// Civil-time conversion deliberately continues to use POSIX seconds, but
/// callers can inspect the original metadata instead of silently losing it.
pub(all) struct LeapSecond {
  transition_time : Int64
  correction : Int
}

///|
// Parsed representation of a TZif v2 or v3 file.
pub(all) struct TzifData {
  version : Byte
  time_types : Array[TimeType]
  transitions : Array[Transition]
  leap_seconds : Array[LeapSecond]
  standard_indicators : Array[Bool]?
  utc_indicators : Array[Bool]?
  posix_rule : PosixTzRule?
}

///|
/// The behavior used beyond the final explicit TZif transition.
pub(all) enum PostTransitionBehavior {
  PosixFooter
  LastExplicitType
}

///|
/// Summary information for inspection tools and operational diagnostics.
///
/// `first_transition` and `last_transition` describe only the explicit TZif
/// transition table. A POSIX footer can extend behavior past `last_transition`.
pub(all) struct TzifDiagnostics {
  version : Byte
  transition_count : Int
  time_type_count : Int
  leap_second_count : Int
  standard_indicator_count : Int
  utc_indicator_count : Int
  first_transition : Int64?
  last_transition : Int64?
  has_posix_footer : Bool
  post_transition_behavior : PostTransitionBehavior
}

// POSIX TZ rule parsed from the v3 footer string.

///|
pub(all) struct PosixTzRule {
  std_abbr : String
  std_offset : Int // offset in seconds (east of UTC = positive)
  dst_abbr : String?
  dst_offset : Int?
  start_rule : PosixTransitionRule?
  end_rule : PosixTransitionRule?
}

// The calendar date portion of a POSIX DST transition rule.
//
// `JulianNoLeap(1)` is 1 January and deliberately skips leap day;
// `DayOfYear(0)` is 1 January and includes leap day; `MonthWeekDay` is the
// `Mmonth.week.weekday` form where weekday 0 is Sunday and week 5 is last.

///|
pub(all) enum PosixDateRule {
  JulianNoLeap(Int)
  DayOfYear(Int)
  MonthWeekDay(Int, Int, Int)
}

///|
// The reference clock used by a POSIX transition time suffix.
pub(all) enum PosixTimeBasis {
  Wall
  Standard
  Utc
}

///|
// A single DST transition rule within a POSIX TZ string.
pub(all) struct PosixTransitionRule {
  date_rule : PosixDateRule
  time_of_day : Int // signed seconds from the rule date's midnight
  time_basis : PosixTimeBasis
}

// User preference for resolving ambiguous local times during fall-back.

///|
pub(all) enum AmbiguityStrategy {
  PreferEarlier
  PreferLater
}

///|
/// Complete result of resolving a local civil time against a timezone.
///
/// `Ambiguous` keeps every matching POSIX instant in ascending order.  In
/// ordinary DST fall-backs there are two candidates, but retaining an array
/// avoids making an undocumented two-candidate assumption for unusual
/// historical transition data.
pub(all) enum LocalTimeResolution {
  Unique(Int64)
  Ambiguous(Array[Int64])
  Gap
}

///|
/// Where the active offset at a UTC instant came from.
pub(all) enum OffsetSource {
  InitialType
  ExplicitTransition(Int)
  PosixFooter
}

///|
/// Offset and abbreviation effective at a UTC instant, without allocating a
/// decomposed calendar value.
pub(all) struct OffsetInfo {
  utoff : Int
  is_dst : Bool
  abbr : String
  source : OffsetSource
}

///|
/// How an explicit transition changes wall-clock time.
pub(all) enum ClockChange {
  NoClockChange
  ClockForward
  ClockBackward
}

///|
/// Fully interpreted form of an explicit TZif transition.
///
/// `local_before` and `local_after` are POSIX seconds on the local civil
/// timeline immediately at the transition boundary, calculated respectively
/// using the type before and after the transition.
pub(all) struct TransitionDetail {
  index : Int
  utc_time : Int64
  before : TimeType
  after : TimeType
  offset_change : Int
  clock_change : ClockChange
  local_before : Int64
  local_after : Int64
}

// Decomposed local date-time with timezone metadata.

///|
pub(all) struct LocalDateTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  utoff : Int // offset in seconds from UTC
  is_dst : Bool
  abbr : String
}

///|
/// A strict ISO-8601 date-time carrying a numeric UTC offset.
///
/// The `local_time` metadata contains exactly the parsed numeric offset;
/// `utc_time` is the equivalent POSIX timestamp.  It intentionally does not
/// assert that a named timezone would use that offset at that instant.
pub(all) struct OffsetDateTime {
  local_time : LocalDateTime
  utc_time : Int64
  offset : Int
}

// All errors this library can produce.

///|
pub(all) enum TzifError {
  InvalidMagic(String)
  UnsupportedVersion(Byte)
  TruncatedData
  ResourceLimitExceeded(String)
  InvalidTransitionTable(String)
  TimestampOutOfRange(Int64)
  InvalidLocalTime(LocalDateTime) // spring-forward gap
  AmbiguousLocalTime(LocalDateTime, LocalDateTime) // fall-back overlap
  PosixParseError(String)
  InvalidIso8601(String)
}

///|
pub type TzifResult[T] = Result[T, TzifError]
