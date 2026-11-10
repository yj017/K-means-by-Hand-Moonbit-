///|
/// A contour/tick level generator modeled after Matplotlib's Locator family.
///
/// The adapter supports immutable configurations and a live MultipleLocator.
/// Callers can choose fixed spacing with an offset, evenly
/// spaced linear levels, a MaxN-style "nice" level set, an explicit fixed set,
/// or logarithmic levels.
pub(all) enum Locator {
  NamedLogit(LogitLocator)
  NamedAsinh(AsinhLocator)
  NamedSymLog(SymmetricalLogLocator)
  NamedLog(LogLocator)
  Null(NullLocator)
  NamedMaxN(MaxNLocator)
  NamedAuto(AutoLocator)
  NamedLinear(LinearLocator)
  Index(IndexLocator)
  NamedFixed(FixedLocator)
  Multiple(MultipleLocator)
  Linear(count~ : Int32)
  MaxN(count~ : Int32, integer~ : Bool, symmetric~ : Bool, prune~ : String)
  Fixed(Array[Double])
  Log(count~ : Int32, base~ : Double)
  LogWithSubs(
    count~ : Int32,
    base~ : Double,
    subs~ : Array[Double],
    numdecs~ : Int32
  )
}

///|
/// A minor tick generator used between major locator values.
pub(all) enum MinorLocator {
  NamedLogit(LogitLocator)
  NamedAsinh(AsinhLocator)
  NamedSymLog(SymmetricalLogLocator)
  NamedLog(LogLocator)
  Null(NullLocator)
  NamedAutoMinor(AutoMinorLocator)
  NamedMaxN(MaxNLocator)
  NamedAuto(AutoLocator)
  NamedLinear(LinearLocator)
  Index(IndexLocator)
  NamedFixed(FixedLocator)
  Multiple(MultipleLocator)
  Auto(subdivisions~ : Int32)
  Fixed(Array[Double])
  Log(subdivisions~ : Int32, base~ : Double)
}

///|
/// Construct a linear locator with at least two requested levels.
pub fn linear_locator(count~ : Int32 = 7) -> Locator {
  let actual = if count < 2 { 2 } else { count }
  Locator::Linear(count=actual)
}

///|
/// Construct a MaxN-style locator with human-readable step sizes.
///
/// `count` is the requested number of visible ticks. The generator chooses
/// steps from the familiar 1/2/2.5/5 decade sequence, optionally restricts
/// them to integer values, mirrors the range around zero, and can prune one
/// or both endpoints.
pub fn maxn_locator(
  count~ : Int32 = 7,
  integer~ : Bool = false,
  symmetric~ : Bool = false,
  prune~ : String = "",
) -> Locator raise @core.DataError {
  if count < 2 {
    raise @core.DataError::InvalidTicks(
      message="maxn locator count must be at least two",
    )
  }
  if prune != "" && prune != "lower" && prune != "upper" && prune != "both" {
    raise @core.DataError::InvalidTicks(
      message="maxn locator prune must be empty, lower, upper, or both",
    )
  }
  Locator::MaxN(count~, integer~, symmetric~, prune~)
}

///|
/// Construct an automatic minor locator that subdivides each major interval.
pub fn auto_minor_locator(
  subdivisions~ : Int32 = 4,
) -> MinorLocator raise @core.DataError {
  if subdivisions < 1 {
    raise @core.DataError::InvalidTicks(
      message="minor locator subdivisions must be positive",
    )
  }
  MinorLocator::Auto(subdivisions~)
}

///|
/// Construct a logarithmic minor locator.
pub fn log_minor_locator(
  subdivisions~ : Int32 = 9,
  base~ : Double = 10.0,
) -> MinorLocator raise @core.DataError {
  if subdivisions < 1 {
    raise @core.DataError::InvalidTicks(
      message="log minor locator subdivisions must be positive",
    )
  }
  if base.is_nan() || base.is_inf() || base <= 1.0 {
    raise @core.DataError::InvalidTicks(
      message="log minor locator base must be finite and greater than one",
    )
  }
  MinorLocator::Log(subdivisions~, base~)
}

///|
/// Construct a fixed minor locator from finite values.
pub fn fixed_minor_locator(
  values : Array[Double],
) -> MinorLocator raise @core.DataError {
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="fixed minor locator values must be finite",
      )
    }
  }
  MinorLocator::Fixed(values.copy())
}

///|
/// Construct a fixed locator from a finite, strictly increasing level list.
pub fn fixed_locator(values : Array[Double]) -> Locator raise @core.DataError {
  if values.length() == 0 {
    raise @core.DataError::InvalidTicks(
      message="fixed locator requires at least one value",
    )
  }
  for index, value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="fixed locator values must be finite",
      )
    }
    if index > 0 && value <= values[index - 1] {
      raise @core.DataError::InvalidTicks(
        message="fixed locator values must be strictly increasing",
      )
    }
  }
  Locator::Fixed(values.copy())
}

///|
/// Construct a logarithmic locator with a finite base greater than one.
pub fn log_locator(
  count~ : Int32 = 7,
  base~ : Double = 10.0,
  subs~ : Array[Double] = [1.0],
  numdecs~ : Int32 = 4,
) -> Locator raise @core.DataError {
  if count < 2 {
    raise @core.DataError::InvalidTicks(
      message="log locator count must be at least two",
    )
  }
  if base.is_nan() || base.is_inf() || base <= 1.0 {
    raise @core.DataError::InvalidTicks(
      message="log locator base must be finite and greater than one",
    )
  }
  if numdecs < 1 {
    raise @core.DataError::InvalidTicks(
      message="log locator numdecs must be positive",
    )
  }
  if subs.length() == 0 {
    raise @core.DataError::InvalidTicks(
      message="log locator subs must not be empty",
    )
  }
  let normalized_subs = subs.copy()
  for value in normalized_subs {
    if value.is_nan() || value.is_inf() || value <= 0.0 {
      raise @core.DataError::InvalidTicks(
        message="log locator subs must be finite and positive",
      )
    }
  }
  normalized_subs.sort()
  if normalized_subs.length() == 1 && normalized_subs[0] == 1.0 && numdecs == 4 {
    Locator::Log(count~, base~)
  } else {
    Locator::LogWithSubs(count~, base~, subs=normalized_subs, numdecs~)
  }
}

///|
/// Return evenly spaced levels in the requested range.
pub fn Locator::tick_values(
  self : Locator,
  lower : Double,
  upper : Double,
) -> Array[Double] {
  match self {
    Null(value) => return value.call()
    NamedLogit(_)
    | NamedAsinh(_)
    | NamedSymLog(_)
    | NamedLog(_)
    | NamedMaxN(_)
    | NamedAuto(_)
    | NamedLinear(_)
    | Index(_)
    | NamedFixed(_) =>
      return self.checked_tick_values(lower, upper) catch { _ => [] }
    _ => ()
  }
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    return []
  }
  let first = Double::min(lower, upper)
  let last = Double::max(lower, upper)
  let ascending = lower <= upper
  match self {
    Locator::NamedLogit(_)
    | Locator::NamedAsinh(_)
    | Locator::NamedSymLog(_)
    | Locator::NamedLog(_)
    | Locator::Null(_)
    | Locator::NamedMaxN(_)
    | Locator::NamedAuto(_)
    | Locator::NamedLinear(_)
    | Locator::Index(_)
    | Locator::NamedFixed(_) => []
    Locator::Multiple(value) => {
      let values = value.tick_values(first, last) catch { _ => [] }
      if ascending {
        values
      } else {
        values.rev()
      }
    }
    Locator::Linear(count~) => {
      let values = linear_ticks(@core.limits(first, last), count~)
      if ascending {
        values
      } else {
        values.rev()
      }
    }
    Locator::MaxN(count~, integer~, symmetric~, prune~) => {
      let values = maxn_ticks(
        @core.limits(first, last),
        count,
        integer,
        symmetric,
        prune,
      )
      if ascending {
        values
      } else {
        values.rev()
      }
    }
    Locator::Fixed(values) => {
      let result : Array[Double] = []
      for value in values {
        if value >= first && value <= last {
          result.push(value)
        }
      }
      result
    }
    Locator::Log(count~, base~) =>
      log_locator_ticks(first, last, count, base, [1.0], 4, false, ascending)
    Locator::LogWithSubs(count~, base~, subs~, numdecs~) =>
      log_locator_ticks(
        first, last, count, base, subs, numdecs, true, ascending,
      )
  }
}

///|
/// Generate logarithmic ticks with optional per-decade subdivisions.
fn log_locator_ticks(
  first : Double,
  last : Double,
  count : Int32,
  base : Double,
  subs : Array[Double],
  numdecs : Int32,
  limit_decades : Bool,
  ascending : Bool,
) -> Array[Double] {
  if first <= 0.0 || last <= 0.0 {
    return []
  }
  let lower_power = (@math.log10(first) / @math.log10(base)).floor().to_int()
  let upper_power = (@math.log10(last) / @math.log10(base)).ceil().to_int()
  let span = Int32::max(0, upper_power - lower_power)
  let actual_count = Int32::max(2, count)
  if subs.length() == 1 && subs[0] == 1.0 {
    let decade_stride = if limit_decades {
      Int32::max(
        1,
        (span + Int32::max(1, numdecs) - 1) / Int32::max(1, numdecs),
      )
    } else {
      1
    }
    let values = if span <= 0 {
      [first]
    } else if decade_stride > 1 {
      let result : Array[Double] = []
      let mut power = lower_power
      while power <= upper_power {
        let value = @math.pow(base, Double::from_int(power))
        if value >= first && value <= last {
          result.push(value)
        }
        power += decade_stride
      }
      if result.length() == 0 {
        [first, last]
      } else {
        result
      }
    } else if span + 1 <= actual_count {
      let result : Array[Double] = []
      for power in lower_power..<=upper_power {
        let value = @math.pow(base, Double::from_int(power))
        if value >= first && value <= last {
          result.push(value)
        }
      }
      if result.length() == 0 {
        [first, last]
      } else {
        result
      }
    } else {
      let result = Array(capacity=actual_count)
      for index in 0..<actual_count {
        let fraction = Double::from_int(index) /
          Double::from_int(actual_count - 1)
        result.push(
          @math.pow(
            base,
            Double::from_int(lower_power) + Double::from_int(span) * fraction,
          ),
        )
      }
      result
    }
    if ascending {
      values
    } else {
      values.rev()
    }
  } else {
    let requested_decades = Int32::max(1, numdecs)
    let stride = Int32::max(
      1,
      (span + requested_decades - 1) / requested_decades,
    )
    let result : Array[Double] = []
    let mut power = lower_power
    while power <= upper_power {
      let decade = @math.pow(base, Double::from_int(power))
      for sub in subs {
        let value = decade * sub
        if value >= first && value <= last && !contains_tick(result, value) {
          result.push(value)
        }
      }
      power += stride
    }
    result.sort()
    let values = if result.length() == 0 { [first, last] } else { result }
    if ascending {
      values
    } else {
      values.rev()
    }
  }
}

///|
/// Return minor tick positions for a major tick list and data range.
pub fn MinorLocator::tick_values(
  self : MinorLocator,
  major : Array[Double],
  lower : Double,
  upper : Double,
) -> Array[Double] {
  match self {
    Null(value) => return value.call()
    NamedAutoMinor(value) =>
      return value.tick_values(lower, upper) catch { _ => [] }
    NamedLogit(_)
    | NamedAsinh(_)
    | NamedSymLog(_)
    | NamedLog(_)
    | NamedMaxN(_)
    | NamedAuto(_)
    | NamedLinear(_)
    | Index(_)
    | NamedFixed(_) =>
      return self.checked_tick_values(major, lower, upper) catch { _ => [] }
    _ => ()
  }
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    return []
  }
  let first = Double::min(lower, upper)
  let last = Double::max(lower, upper)
  let result : Array[Double] = []
  match self {
    MinorLocator::NamedLogit(_)
    | MinorLocator::NamedAsinh(_)
    | MinorLocator::NamedSymLog(_)
    | MinorLocator::NamedLog(_)
    | MinorLocator::Null(_)
    | MinorLocator::NamedAutoMinor(_)
    | MinorLocator::NamedMaxN(_)
    | MinorLocator::NamedAuto(_)
    | MinorLocator::NamedLinear(_)
    | MinorLocator::Index(_)
    | MinorLocator::NamedFixed(_) => ()
    MinorLocator::Multiple(value) => {
      let values = value.tick_values(first, last) catch { _ => [] }
      for value in values {
        if value >= first && value <= last && !contains_tick(major, value) {
          result.push(value)
        }
      }
    }
    MinorLocator::Fixed(values) =>
      for value in values {
        if value >= first && value <= last && !contains_tick(major, value) {
          result.push(value)
        }
      }
    MinorLocator::Auto(subdivisions~) => {
      let actual = Int32::max(1, subdivisions)
      if major.length() >= 2 {
        for index in 0..<(major.length() - 1) {
          let start = major[index]
          let end = major[index + 1]
          for part in 1..<actual {
            let fraction = Double::from_int(part) / Double::from_int(actual)
            let value = start + (end - start) * fraction
            if value >= first && value <= last && !contains_tick(major, value) {
              result.push(value)
            }
          }
        }
      }
    }
    MinorLocator::Log(subdivisions~, base~) => {
      if first <= 0.0 || last <= 0.0 {
        return []
      }
      let lower_power = (@math.log10(first) / @math.log10(base))
        .floor()
        .to_int()
      let upper_power = (@math.log10(last) / @math.log10(base)).ceil().to_int()
      let actual = Int32::max(1, subdivisions)
      for power in lower_power..<=upper_power {
        let decade = @math.pow(base, Double::from_int(power))
        for part in 1..<=actual {
          let value = decade * Double::from_int(part)
          if value >= first && value <= last && !contains_tick(major, value) {
            result.push(value)
          }
        }
      }
    }
  }
  result.sort()
  if lower <= upper {
    result
  } else {
    result.rev()
  }
}

///|
/// Copy arrays while retaining live named locator handles.
/// Use the named object copy() method for a separate parameter configuration.
pub fn Locator::copy(self : Locator) -> Locator {
  match self {
    Locator::NamedLogit(value) => Locator::NamedLogit(value)
    Locator::NamedAsinh(value) => Locator::NamedAsinh(value)
    Locator::NamedSymLog(value) => Locator::NamedSymLog(value)
    Locator::NamedLog(value) => Locator::NamedLog(value)
    Locator::Null(value) => Locator::Null(value)
    Locator::NamedMaxN(value) => Locator::NamedMaxN(value)
    Locator::NamedAuto(value) => Locator::NamedAuto(value)
    Locator::NamedLinear(value) => Locator::NamedLinear(value)
    Locator::Index(value) => Locator::Index(value)
    Locator::NamedFixed(value) => Locator::NamedFixed(value)
    Locator::Multiple(value) => Locator::Multiple(value)
    Locator::Linear(count~) => Locator::Linear(count~)
    Locator::MaxN(count~, integer~, symmetric~, prune~) =>
      Locator::MaxN(count~, integer~, symmetric~, prune~)
    Locator::Fixed(values) => Locator::Fixed(values.copy())
    Locator::Log(count~, base~) => Locator::Log(count~, base~)
    Locator::LogWithSubs(count~, base~, subs~, numdecs~) =>
      Locator::LogWithSubs(count~, base~, subs=subs.copy(), numdecs~)
  }
}

///|
/// Copy arrays while retaining live named locator handles.
pub fn MinorLocator::copy(self : MinorLocator) -> MinorLocator {
  match self {
    MinorLocator::NamedLogit(value) => MinorLocator::NamedLogit(value)
    MinorLocator::NamedAsinh(value) => MinorLocator::NamedAsinh(value)
    MinorLocator::NamedSymLog(value) => MinorLocator::NamedSymLog(value)
    MinorLocator::NamedLog(value) => MinorLocator::NamedLog(value)
    MinorLocator::Null(value) => MinorLocator::Null(value)
    MinorLocator::NamedAutoMinor(value) => MinorLocator::NamedAutoMinor(value)
    MinorLocator::NamedMaxN(value) => MinorLocator::NamedMaxN(value)
    MinorLocator::NamedAuto(value) => MinorLocator::NamedAuto(value)
    MinorLocator::NamedLinear(value) => MinorLocator::NamedLinear(value)
    MinorLocator::Index(value) => MinorLocator::Index(value)
    MinorLocator::NamedFixed(value) => MinorLocator::NamedFixed(value)
    MinorLocator::Multiple(value) => MinorLocator::Multiple(value)
    MinorLocator::Auto(subdivisions~) => MinorLocator::Auto(subdivisions~)
    MinorLocator::Fixed(values) => MinorLocator::Fixed(values.copy())
    MinorLocator::Log(subdivisions~, base~) =>
      MinorLocator::Log(subdivisions~, base~)
  }
}

///|
/// Return a copy of fixed levels, or an empty array for generated locators.
pub fn Locator::fixed_values(self : Locator) -> Array[Double] {
  match self {
    Locator::NamedFixed(value) => value.locations().to_array() catch { _ => [] }
    Locator::Fixed(values) => values.copy()
    _ => []
  }
}

///|
/// Return whether a tick list already contains a value.
fn contains_tick(values : Array[Double], value : Double) -> Bool {
  for candidate in values {
    if candidate == value {
      return true
    }
  }
  false
}

///|
/// Choose a MaxN step from a stable decimal sequence.
fn maxn_step(span : Double, count : Int32, integer : Bool) -> Double {
  let raw = span / Double::from_int(Int32::max(1, count - 1))
  if raw <= 0.0 || raw.is_nan() || raw.is_inf() {
    return 1.0
  }
  let exponent = @math.log10(raw).floor()
  let scale = @math.pow(10.0, exponent)
  let fraction = raw / scale
  let base_step = if fraction <= 1.0 {
    1.0
  } else if fraction <= 2.0 {
    2.0
  } else if fraction <= 2.5 {
    2.5
  } else if fraction <= 5.0 {
    5.0
  } else {
    10.0
  }
  let step = base_step * scale
  if integer && step < 1.0 {
    1.0
  } else {
    step
  }
}

///|
/// Generate MaxN-style ticks while retaining the requested direction.
fn maxn_ticks(
  limits : @core.Limits,
  count : Int32,
  integer : Bool,
  symmetric : Bool,
  prune : String,
) -> Array[Double] {
  if !limits.is_finite() {
    return []
  }
  if limits.lower() == limits.upper() {
    return [limits.lower()]
  }
  let ascending = limits.lower() <= limits.upper()
  let original_lower = Double::min(limits.lower(), limits.upper())
  let original_upper = Double::max(limits.lower(), limits.upper())
  let (lower, upper) = if symmetric {
    let radius = Double::max(
      Double::abs(original_lower),
      Double::abs(original_upper),
    )
    (-radius, radius)
  } else {
    (original_lower, original_upper)
  }
  let step = maxn_step(upper - lower, count, integer)
  let first_index = (lower / step).ceil().to_int()
  let last_index = (upper / step).floor().to_int()
  let values : Array[Double] = []
  for index in first_index..<=last_index {
    let value = Double::from_int(index) * step
    if value >= lower - step * 1.0e-12 && value <= upper + step * 1.0e-12 {
      values.push(if Double::abs(value) < step * 1.0e-12 { 0.0 } else { value })
    }
  }
  if values.length() < 2 {
    values.clear()
    values.push(lower)
    values.push(upper)
  }
  let pruned = Array(capacity=values.length())
  for index, value in values {
    let remove_lower = (prune == "lower" || prune == "both") && index == 0
    let remove_upper = (prune == "upper" || prune == "both") &&
      index == values.length() - 1
    if !remove_lower && !remove_upper {
      pruned.push(value)
    }
  }
  if ascending {
    pruned
  } else {
    pruned.rev()
  }
}
