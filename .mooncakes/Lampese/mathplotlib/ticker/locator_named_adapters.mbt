///|
pub fn LinearLocator::as_locator(self : LinearLocator) -> Locator {
  NamedLinear(self)
}

///|
pub fn LinearLocator::as_minor_locator(self : LinearLocator) -> MinorLocator {
  NamedLinear(self)
}

///|
pub fn IndexLocator::as_locator(self : IndexLocator) -> Locator {
  Index(self)
}

///|
pub fn IndexLocator::as_minor_locator(self : IndexLocator) -> MinorLocator {
  Index(self)
}

///|
pub fn FixedLocator::as_locator(self : FixedLocator) -> Locator {
  NamedFixed(self)
}

///|
pub fn FixedLocator::as_minor_locator(self : FixedLocator) -> MinorLocator {
  NamedFixed(self)
}

///|
pub fn Locator::linear_locator(self : Locator) -> LinearLocator? {
  match self {
    NamedLinear(value) => Some(value)
    _ => None
  }
}

///|
pub fn Locator::index_locator(self : Locator) -> IndexLocator? {
  match self {
    Index(value) => Some(value)
    _ => None
  }
}

///|
pub fn Locator::fixed_locator(self : Locator) -> FixedLocator? {
  match self {
    NamedFixed(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::linear_locator(self : MinorLocator) -> LinearLocator? {
  match self {
    NamedLinear(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::index_locator(self : MinorLocator) -> IndexLocator? {
  match self {
    Index(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::fixed_locator(self : MinorLocator) -> FixedLocator? {
  match self {
    NamedFixed(value) => Some(value)
    _ => None
  }
}

///|
/// Materialize named results while preserving source errors. Linear adapters
/// follow the requested direction; Index and Fixed retain their source order.
pub fn Locator::checked_tick_values(
  self : Locator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  match self {
    NamedLogit(value) => value.tick_values(lower, upper)
    NamedAsinh(value) => value.tick_values(lower, upper)
    NamedSymLog(value) => value.tick_values(lower, upper)
    NamedLog(value) => value.tick_values(lower, upper)
    Null(value) => value.tick_values(lower, upper)
    NamedMaxN(value) => {
      let ticks = value.tick_values(lower, upper)
      if lower > upper {
        ticks.rev()
      } else {
        ticks
      }
    }
    NamedAuto(value) =>
      value.as_maxn_locator().as_locator().checked_tick_values(lower, upper)
    NamedLinear(value) => {
      let ticks = value.tick_values(lower, upper).eager_prefix()
      if lower > upper {
        ticks.rev()
      } else {
        ticks
      }
    }
    Index(value) => value.tick_values(lower, upper)
    NamedFixed(value) => value.tick_values(lower, upper).eager_prefix()
    _ => self.tick_values(lower, upper)
  }
}

///|
/// Axis calls use the IndexLocator's bound data interval, independent of view.
pub fn Locator::tick_values_for_axis(
  self : Locator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  match self {
    NamedLogit(value) => value.call()
    NamedAsinh(value) => value.call()
    NamedSymLog(value) => value.call()
    NamedLog(value) => value.call()
    Index(value) => value.call()
    NamedMaxN(value) => value.call()
    NamedAuto(value) => value.call()
    _ => self.checked_tick_values(lower, upper)
  }
}

///|
fn named_minor_values(
  values : Array[Double],
  major : Array[Double],
  lower : Double,
  upper : Double,
) -> Array[Double] {
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    return []
  }
  let first = Double::min(lower, upper)
  let last = Double::max(lower, upper)
  values.filter(value => {
    value >= first && value <= last && !contains_tick(major, value)
  })
}

///|
pub fn MinorLocator::checked_tick_values(
  self : MinorLocator,
  major : Array[Double],
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  let values = match self {
    NamedLogit(value) => return value.tick_values(lower, upper)
    NamedAsinh(value) => return value.tick_values(lower, upper)
    NamedSymLog(value) => return value.tick_values(lower, upper)
    NamedLog(value) => return value.tick_values(lower, upper)
    Null(value) => return value.tick_values(lower, upper)
    NamedAutoMinor(value) => return value.tick_values(lower, upper)
    NamedMaxN(value) => value.as_locator().checked_tick_values(lower, upper)
    NamedAuto(value) => value.as_locator().checked_tick_values(lower, upper)
    NamedLinear(value) => value.as_locator().checked_tick_values(lower, upper)
    Index(value) => value.tick_values(lower, upper)
    NamedFixed(value) => value.tick_values(lower, upper).eager_prefix()
    _ => return self.tick_values(major, lower, upper)
  }
  named_minor_values(values, major, lower, upper)
}

///|
pub fn MinorLocator::tick_values_for_axis(
  self : MinorLocator,
  major : Array[Double],
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  match self {
    NamedLogit(value) => value.call()
    NamedAsinh(value) => value.call()
    NamedSymLog(value) => value.call()
    NamedLog(value) => value.call()
    Null(value) => value.call()
    NamedAutoMinor(value) => value.call()
    Index(value) => named_minor_values(value.call(), major, lower, upper)
    NamedMaxN(value) => named_minor_values(value.call(), major, lower, upper)
    NamedAuto(value) => named_minor_values(value.call(), major, lower, upper)
    _ => self.checked_tick_values(major, lower, upper)
  }
}

///|
pub fn NullLocator::as_locator(self : NullLocator) -> Locator {
  Null(self)
}

///|
pub fn NullLocator::as_minor_locator(self : NullLocator) -> MinorLocator {
  Null(self)
}

///|
pub fn AutoMinorLocator::as_minor_locator(
  self : AutoMinorLocator,
) -> MinorLocator {
  NamedAutoMinor(self)
}

///|
pub fn Locator::null_locator(self : Locator) -> NullLocator? {
  match self {
    Null(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::null_locator(self : MinorLocator) -> NullLocator? {
  match self {
    Null(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::auto_minor_locator(
  self : MinorLocator,
) -> AutoMinorLocator? {
  match self {
    NamedAutoMinor(value) => Some(value)
    _ => None
  }
}

///|
/// Preserve the source dtype and order for a major getter consumed by AutoMinor.
pub fn Locator::tick_view_for_axis(
  self : Locator,
  lower : Double,
  upper : Double,
) -> TickValues raise @core.DataError {
  match self {
    Null(_) => TickValues::from_array([])
    NamedFixed(value) => value.tick_values(lower, upper)
    NamedLinear(value) => value.tick_values(lower, upper)
    _ => TickValues::from_array(self.tick_values_for_axis(lower, upper))
  }
}

///|
pub fn LogLocator::as_locator(self : LogLocator) -> Locator {
  NamedLog(self)
}

///|
pub fn LogLocator::as_minor_locator(self : LogLocator) -> MinorLocator {
  NamedLog(self)
}

///|
pub fn Locator::log_locator(self : Locator) -> LogLocator? {
  match self {
    NamedLog(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::log_locator(self : MinorLocator) -> LogLocator? {
  match self {
    NamedLog(value) => Some(value)
    _ => None
  }
}

///|
pub fn SymmetricalLogLocator::as_locator(
  self : SymmetricalLogLocator,
) -> Locator {
  NamedSymLog(self)
}

///|
pub fn SymmetricalLogLocator::as_minor_locator(
  self : SymmetricalLogLocator,
) -> MinorLocator {
  NamedSymLog(self)
}

///|
pub fn Locator::symlog_locator(self : Locator) -> SymmetricalLogLocator? {
  match self {
    NamedSymLog(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::symlog_locator(
  self : MinorLocator,
) -> SymmetricalLogLocator? {
  match self {
    NamedSymLog(value) => Some(value)
    _ => None
  }
}

///|
pub fn AsinhLocator::as_locator(self : AsinhLocator) -> Locator {
  NamedAsinh(self)
}

///|
pub fn AsinhLocator::as_minor_locator(self : AsinhLocator) -> MinorLocator {
  NamedAsinh(self)
}

///|
pub fn Locator::asinh_locator(self : Locator) -> AsinhLocator? {
  match self {
    NamedAsinh(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::asinh_locator(self : MinorLocator) -> AsinhLocator? {
  match self {
    NamedAsinh(value) => Some(value)
    _ => None
  }
}

///|
pub fn LogitLocator::as_locator(self : LogitLocator) -> Locator {
  NamedLogit(self)
}

///|
pub fn LogitLocator::as_minor_locator(self : LogitLocator) -> MinorLocator {
  NamedLogit(self)
}

///|
pub fn Locator::logit_locator(self : Locator) -> LogitLocator? {
  match self {
    NamedLogit(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::logit_locator(self : MinorLocator) -> LogitLocator? {
  match self {
    NamedLogit(value) => Some(value)
    _ => None
  }
}
