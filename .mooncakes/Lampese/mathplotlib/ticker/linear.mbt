///|
/// Generate evenly spaced tick positions, retaining the direction of limits.
pub fn linear_ticks(limits : @core.Limits, count~ : Int32 = 6) -> Array[Double] {
  if !limits.is_finite() {
    return []
  }
  if limits.lower() == limits.upper() {
    return [limits.lower()]
  }
  let actual = if count < 2 { 2 } else { count }
  let step = (limits.upper() - limits.lower()) / Double::from_int(actual - 1)
  let values = Array(capacity=actual)
  for i in 0..<actual {
    values.push(limits.lower() + Double::from_int(i) * step)
  }
  values
}

///|
/// Format a tick value using the current binary64 decimal representation.
pub fn format_tick(value : Double) -> String {
  Double::to_string(value)
}
