///|
pub(all) enum DateFrequency {
  Year
  Month
  Day
  Hour
  Minute
  Second
  Microsecond
} derive(Debug, Eq, Compare)

///|
pub(all) enum DateMaxTicks {
  All(Int32)
  ByFrequency(Array[(DateFrequency, Int32)])
} derive(Debug, Eq)

///|
pub(all) enum AutoDateWarning {
  IntervalFallback(DateFrequency, Int32)
  DistantMicroseconds
} derive(Debug, Eq)

///|
priv struct AutoLocatorState {
  mut frequency : DateFrequency
  mut interval : Int32
  mut warnings : Array[AutoDateWarning]
}

///|
priv struct AutoLocatorSettings {
  minticks : Int32
  maxticks : Array[Int32]
  intervals : Array[Array[Int32]]
  multiples : Bool
  offset_minutes : Int32
  timezone : DateTimeZone?
  context : DateParserContext?
}

///|
pub struct AutoDateLocator {
  priv settings : AutoLocatorSettings
  priv state : AutoLocatorState
}

///|
fn DateFrequency::index(self : DateFrequency) -> Int32 {
  match self {
    Year => 0
    Month => 1
    Day => 2
    Hour => 3
    Minute => 4
    Second => 5
    Microsecond => 6
  }
}

///|
fn auto_frequency(index : Int32) -> DateFrequency {
  match index {
    0 => Year
    1 => Month
    2 => Day
    3 => Hour
    4 => Minute
    5 => Second
    _ => Microsecond
  }
}

///|
fn auto_unit(frequency : DateFrequency) -> Double {
  match frequency {
    Year => 365.0
    Month => 30.0
    Day => 1.0
    Hour => 1.0 / 24.0
    Minute => 1.0 / 1440.0
    Second => 1.0 / 86400.0
    Microsecond => 1.0 / 86_400_000_000.0
  }
}

///|
fn auto_maximums(
  current : Array[Int32],
  value : DateMaxTicks,
) -> Array[Int32] raise DateError {
  let result = current.copy()
  match value {
    All(count) => {
      if count < 1 {
        raise DateError::InvalidDate(message="maxticks must be positive")
      }
      for index in 0..<7 {
        result[index] = count
      }
    }
    ByFrequency(values) =>
      for entry in values {
        if entry.1 < 1 {
          raise DateError::InvalidDate(message="maxticks must be positive")
        }
        result[entry.0.index()] = entry.1
      }
  }
  result
}

///|
/// Construct the upstream calendar-aware automatic selector. Configuration is
/// copied; selection updates frequency/interval/warnings independently of it.
/// context supplies host-local now for the year-multiple branch only.
///
/// ```mbt check
/// test {
///   let locator = @date.AutoDateLocator::new(maxticks=@date.All(5))
///   let first = @date.datetime(2024, 1, 1).to_ordinal()
///   let last = @date.datetime(2024, 6, 1).to_ordinal()
///   assert_true(!locator.tick_values(first, last).is_empty())
///   assert_eq(locator.frequency(), @date.Month)
/// }
/// ```
/// Capture an explicit timezone or the current timezone rc at construction.
pub fn AutoDateLocator::new(
  context? : DateParserContext,
  tz? : String,
  timezone? : DateTimeZone,
  minticks~ : Int32 = 5,
  maxticks? : DateMaxTicks,
  interval_multiples~ : Bool = true,
) -> AutoDateLocator raise DateError {
  if minticks < 1 {
    raise DateError::InvalidDate(message="minticks must be positive")
  }
  let zone = selected_timezone(tz, timezone)
  let defaults = [11, 12, 11, 12, 11, 11, 8]
  {
    settings: {
      context,
      minticks,
      maxticks: match maxticks {
        Some(value) => auto_maximums(defaults, value)
        None => defaults
      },
      intervals: [
        [
          1, 2, 4, 5, 10, 20, 40, 50, 100, 200, 400, 500, 1000, 2000, 4000, 5000,
          10000,
        ],
        [1, 2, 3, 4, 6],
        if interval_multiples {
          [1, 2, 4, 7, 14]
        } else {
          [1, 2, 3, 7, 14, 21]
        },
        [1, 2, 3, 4, 6, 12],
        [1, 5, 10, 15, 30],
        [1, 5, 10, 15, 30],
        [
          1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000,
          100000, 200000, 500000, 1000000,
        ],
      ],
      multiples: interval_multiples,
      offset_minutes: zone.initial_offset_minutes(),
      timezone: Some(zone),
    },
    state: { frequency: Year, interval: 1, warnings: [], },
  }
}

///|
/// Copy configuration and the last selection without sharing mutable state.
pub fn AutoDateLocator::copy(self : AutoDateLocator) -> AutoDateLocator {
  {
    settings: {
      ..self.settings,
      maxticks: self.settings.maxticks.copy(),
      intervals: self.settings.intervals.map(values => values.copy()),
    },
    state: {
      frequency: self.state.frequency,
      interval: self.state.interval,
      warnings: self.state.warnings.copy(),
    },
  }
}

///|
pub fn AutoDateLocator::minticks(self : AutoDateLocator) -> Int32 {
  self.settings.minticks
}

///|
pub fn AutoDateLocator::max_ticks(
  self : AutoDateLocator,
  frequency : DateFrequency,
) -> Int32 {
  self.settings.maxticks[frequency.index()]
}

///|
pub fn AutoDateLocator::maxticks(
  self : AutoDateLocator,
) -> Array[(DateFrequency, Int32)] {
  Array::makei(7, index => {
    (auto_frequency(index), self.settings.maxticks[index])
  })
}

///|
pub fn AutoDateLocator::intervals(
  self : AutoDateLocator,
  frequency : DateFrequency,
) -> Array[Int32] {
  self.settings.intervals[frequency.index()].copy()
}

///|
pub fn AutoDateLocator::interval_multiples(self : AutoDateLocator) -> Bool {
  self.settings.multiples
}

///|
pub fn AutoDateLocator::frequency(self : AutoDateLocator) -> DateFrequency {
  self.state.frequency
}

///|
pub fn AutoDateLocator::unit_scale(self : AutoDateLocator) -> Double {
  auto_unit(self.state.frequency)
}

///|
/// Return the last intervald candidate, before multiples become range selectors.
pub fn AutoDateLocator::selected_interval(self : AutoDateLocator) -> Int32 {
  self.state.interval
}

///|
/// Return diagnostics from the last selection, without printing warnings.
pub fn AutoDateLocator::warnings(
  self : AutoDateLocator,
) -> Array[AutoDateWarning] {
  self.state.warnings.copy()
}

///|
pub fn AutoDateLocator::with_minticks(
  self : AutoDateLocator,
  count : Int32,
) -> AutoDateLocator raise DateError {
  if count < 1 {
    raise DateError::InvalidDate(message="minticks must be positive")
  }
  let copy = self.copy()
  { ..copy, settings: { ..copy.settings, minticks: count, }, }
}

///|
pub fn AutoDateLocator::with_maxticks(
  self : AutoDateLocator,
  value : DateMaxTicks,
) -> AutoDateLocator raise DateError {
  let copy = self.copy()
  {
    ..copy,
    settings: {
      ..copy.settings,
      maxticks: auto_maximums(copy.settings.maxticks, value),
    },
  }
}

///|
/// Keep the given order, as upstream intervald does; empty/nonpositive lists
/// raise without changing this object. Other interval tables remain unchanged.
pub fn AutoDateLocator::with_intervals(
  self : AutoDateLocator,
  frequency : DateFrequency,
  values : Array[Int32],
) -> AutoDateLocator raise DateError {
  if values.is_empty() || values.any(value => value < 1) {
    raise DateError::InvalidDate(
      message="date intervals must be a nonempty positive list",
    )
  }
  let copy = self.copy()
  copy.settings.intervals[frequency.index()] = values.copy()
  copy
}

///|
/// Change alignment while retaining intervald, including any customization.
pub fn AutoDateLocator::with_interval_multiples(
  self : AutoDateLocator,
  enabled : Bool,
) -> AutoDateLocator {
  let copy = self.copy()
  { ..copy, settings: { ..copy.settings, multiples: enabled, }, }
}

///|
pub fn AutoDateLocator::with_offset(
  self : AutoDateLocator,
  offset_minutes : Int32,
) -> AutoDateLocator raise DateError {
  validate_offset(offset_minutes)
  let copy = self.copy()
  { ..copy, settings: { ..copy.settings, offset_minutes, timezone: None, }, }
}

///|
pub fn AutoDateLocator::with_timezone(
  self : AutoDateLocator,
  timezone : DateTimeZone,
) -> AutoDateLocator {
  let copy = self.copy()
  {
    ..copy,
    settings: {
      ..copy.settings,
      offset_minutes: timezone.initial_offset_minutes(),
      timezone: Some(timezone),
    },
  }
}

///|
/// Expand a single finite value by two years each side, or supply the numeric
/// 1970-01-01/02 range for nonfinite bounds. This does not select a frequency.
pub fn AutoDateLocator::nonsingular(
  _self : AutoDateLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  if lower.is_nan() || upper.is_nan() || lower.is_inf() || upper.is_inf() {
    return (
      try! datetime(1970, 1, 1).to_ordinal(),
      try! datetime(1970, 1, 2).to_ordinal(),
    )
  }
  let first = Double::min(lower, upper)
  let last = Double::max(lower, upper)
  if first == last {
    (first - 730.0, last + 730.0)
  } else {
    (first, last)
  }
}

///|
pub extend DateFrequency with @debug.Debug::{to_repr}

///|
pub extend DateFrequency with Eq::{equal, not_equal}

///|
pub extend DateMaxTicks with @debug.Debug::{to_repr}

///|
pub extend DateMaxTicks with Eq::{equal, not_equal}

///|
pub extend AutoDateWarning with @debug.Debug::{to_repr}

///|
pub extend AutoDateWarning with Eq::{equal, not_equal}

///|
pub extend DateFrequency with Compare::{compare, op_lt, op_le, op_gt, op_ge}
