///|
// Axis._set_lim validates finite inputs before the locator and actual scale.
// The scale's domain predicate must not preempt its endpoint clamp.
fn Axis::logit_limit_bounds_checked(
  self : Axis,
  lower : Double,
  upper : Double,
) -> @core.Limits raise @core.DataError {
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    raise @core.DataError::NonFiniteLimit(axis="logit view")
  }
  let descending = lower > upper
  let bounds = self.numeric_nonsingular_bounds_checked(lower, upper)
  let minpos = self.get_minpos()
  let (first, last) = self.scale.limit_range_for_scale(
    bounds.lower(),
    bounds.upper(),
    minpos,
  )
  let (first, last) = if last < first { (last, first) } else { (first, last) }
  if descending {
    @core.limits(last, first)
  } else {
    @core.limits(first, last)
  }
}
