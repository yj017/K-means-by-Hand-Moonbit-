///|
/// Shared exact-bound overrides for LinearLocator. Values retain borrowed, possibly strided tick views.
pub struct LinearLocatorPresets {
  priv entries : Array[((Double, Double), TickValues)]
}

///|
pub fn LinearLocatorPresets::new() -> LinearLocatorPresets {
  { entries: [], }
}

///|
/// Replace an equal key in place, or append a new key. NaN keys do not compare equal.
pub fn LinearLocatorPresets::set(
  self : LinearLocatorPresets,
  lower : Double,
  upper : Double,
  values : Array[Double],
) -> Unit {
  self.set_view(lower, upper, TickValues::from_array(values))
}

///|
/// Store a borrowed tick view, preserving its underlying buffer and stride.
pub fn LinearLocatorPresets::set_view(
  self : LinearLocatorPresets,
  lower : Double,
  upper : Double,
  values : TickValues,
) -> Unit {
  for index, (key, _) in self.entries {
    if key.0 == lower && key.1 == upper {
      self.entries[index] = ((lower, upper), values)
      return
    }
  }
  self.entries.push(((lower, upper), values))
}

///|
/// Return the original tick view associated with an exact pair of bounds.
pub fn LinearLocatorPresets::get(
  self : LinearLocatorPresets,
  lower : Double,
  upper : Double,
) -> TickValues? {
  for (key, values) in self.entries {
    if key.0 == lower && key.1 == upper {
      return Some(values)
    }
  }
  None
}

///|
pub fn LinearLocatorPresets::length(self : LinearLocatorPresets) -> Int32 {
  self.entries.length()
}

///|
pub fn LinearLocatorPresets::clear(self : LinearLocatorPresets) -> Unit {
  self.entries.clear()
}
