///|
/// Whether automatic view updates are enabled, independently of stored limits.
pub fn Axis::autoscale_on(self : Axis) -> Bool {
  self.autoscale_enabled
}

///|
/// Enable or disable automatic updates without requesting or changing a view.
pub fn Axis::set_autoscale_on(self : Axis, enabled : Bool) -> Unit {
  self.autoscale_enabled = enabled
  // Keep the legacy explicit/provisional projection useful without conflating
  // it with the authoritative viewport or changing the pending request.
  if enabled {
    if self.limits is Some(view) {
      self.limits = None
      self.auto_view = Some(view)
    }
  } else {
    self.limits = Some(self.stored_view)
    self.auto_view = None
  }
}

///|
/// Whether this coordinate has an outstanding automatic view request.
pub fn Axis::autoscale_stale(self : Axis) -> Bool {
  self.autoscale_pending
}

///|
/// Consume a request before the checked computation, including a failing one.
pub fn Axis::clear_autoscale_request(self : Axis) -> Unit {
  self.autoscale_pending = false
}

///|
/// The stored viewport, without resolving pending updates or render projections.
pub fn Axis::stored_view_limits(self : Axis) -> @core.Limits {
  self.stored_view
}

///|
/// Compare current viewport endpoints to the initial interval, as Bbox does.
/// Returning to the original interval restores the unmutated state.
pub fn Axis::view_mutated(self : Axis) -> Bool {
  self.stored_view.lower() != 0.0 || self.stored_view.upper() != 1.0
}

///|
/// Bind the owning panel's lazy view update without changing ticker ownership.
pub fn Axis::bind_autoscale_view(
  self : Axis,
  provider : () -> Unit raise @core.DataError,
) -> Unit {
  self.autoscale_view_provider = Some(provider)
}

///|
/// Resolve the owning panel's outstanding shared view requests.
pub fn Axis::resolve_autoscale_view(self : Axis) -> Unit raise @core.DataError {
  if self.autoscale_view_provider is Some(provider) {
    provider()
  }
}

///|
/// Whether the owning panel supplies authoritative automatic view resolution.
pub fn Axis::has_autoscale_view_provider(self : Axis) -> Bool {
  self.autoscale_view_provider is Some(_)
}

///|
/// Whether installed tickers support the shared numeric-coordinate range pipeline.
pub fn Axis::uses_numeric_autoscale(_self : Axis) -> Bool {
  true
}

///|
/// Bind shared raw DataBox minima, distinct from locator/Axis minimum queries.
pub fn Axis::bind_autoscale_minpos(
  self : Axis,
  provider : () -> Array[Double] raise @core.DataError,
) -> Unit {
  self.autoscale_minpos_provider = Some(provider)
}

///|
/// Supply raw shared minima for an IR graph without replacing Scene data.
pub fn Axis::bind_render_autoscale_minpos(
  self : Axis,
  provider : () -> Array[Double] raise @core.DataError,
) -> Unit {
  self.render_autoscale_minpos_provider = Some(provider)
}

///|
fn Axis::autoscale_minpos_checked(
  self : Axis,
  fallback : (() -> Array[Double] raise @core.DataError)?,
) -> Array[Double] raise @core.DataError {
  match self.autoscale_minpos_provider {
    Some(provider) => provider()
    None =>
      match fallback {
        Some(provider) => provider()
        None =>
          match self.render_autoscale_minpos_provider {
            Some(provider) => provider()
            // Standalone Axis contexts can model both data queries with one binding.
            None => self.shared_minpos_checked()
          }
      }
  }
}

///|
fn Axis::autoscale_nonsingular(
  self : Axis,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  self.locator_nonsingular(lower, upper)
}

///|
fn autoscale_locator_view_limits(
  locator : @ticker.Locator?,
  lower : Double,
  upper : Double,
) -> @core.Limits raise @core.DataError {
  let (first, last) = match locator {
    Some(@ticker.Locator::NamedLogit(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedAsinh(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedSymLog(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedLog(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::Null(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedMaxN(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedAuto(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedLinear(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::Index(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::NamedFixed(value)) => value.view_limits(lower, upper)
    Some(@ticker.Locator::Multiple(value)) => value.view_limits(lower, upper)
    _ => @ticker.NullLocator::new().view_limits(lower, upper)
  }
  @core.limits(first, last)
}

///|
fn Axis::locator_view_limits_checked(
  self : Axis,
  lower : Double,
  upper : Double,
) -> @core.Limits raise @core.DataError {
  let locator = if self.tickers.major_locator_kind == Numeric {
    self.tickers.locator
  } else {
    None
  }
  autoscale_locator_view_limits(locator, lower, upper)
}

///|
/// Compute one selected automatic coordinate through the source range pipeline.
/// `endpoints` are shared raw data intervals, independent of views and scales.
/// The result precedes set_bound's view reads, finalization and peer propagation.
/// No-data mutated views return None before reading locators or minimum data.
pub fn Axis::autoscale_bounds_checked(
  self : Axis,
  endpoints : Array[Double],
  margin~ : Double,
  stickies~ : Array[Double],
  tight~ : Bool,
  data_minpos~ : (() -> Array[Double] raise @core.DataError)? = None,
  tight_provider~ : (() -> Bool)? = None,
  log_stickies~ : Bool? = None,
) -> @core.Limits? raise @core.DataError {
  if !self.autoscale_enabled {
    return None
  }
  let logarithmic_stickies = log_stickies.unwrap_or(
    self.coordinate_scale_name() == "log",
  )
  let mut lower = 1.0 / 0.0
  let mut upper = -1.0 / 0.0
  let mut finite = false
  for value in endpoints {
    if !value.is_nan() && !value.is_inf() {
      if !finite {
        lower = value
        upper = value
      } else {
        if value < lower {
          lower = value
        }
        if value > upper {
          upper = value
        }
      }
      finite = true
    }
  }
  if !finite {
    if self.view_mutated() {
      return None
    }
    lower = -1.0 / 0.0
    upper = 1.0 / 0.0
  }
  // The source keeps this locator object across later data/provider callbacks.
  // Final Axis._set_lim independently fetches the then-current major locator.
  let locator = if self.tickers.major_locator_kind == Numeric {
    self.tickers.locator
  } else {
    None
  }
  let (lower, upper) = self.autoscale_nonsingular(lower, upper)
  let minpos_values = self.autoscale_minpos_checked(data_minpos)
  if minpos_values.is_empty() {
    raise @core.DataError::InvalidTicks(
      message="shared axis has no minimum positive data",
    )
  }
  // Python min keeps its first value when later comparisons are unordered.
  let mut minpos = minpos_values[0]
  for value in minpos_values {
    if value < minpos {
      minpos = value
    }
  }
  let mut lower_sticky : Double? = None
  let mut upper_sticky : Double? = None
  let tolerance = 1.0e-5 * Double::abs(upper - lower)
  for value in stickies {
    // Only LogScale removes nonpositive sticky edges. Other scales keep them.
    if !logarithmic_stickies || value > 0.0 {
      if value < lower + tolerance {
        lower_sticky = Some(
          match lower_sticky {
            Some(previous) => Double::max(previous, value)
            None => value
          },
        )
      }
      if value >= upper - tolerance {
        upper_sticky = Some(
          match upper_sticky {
            Some(previous) => Double::min(previous, value)
            None => value
          },
        )
      }
    }
  }
  // Scale transforms are immutable values; acquiring their forward/inverse
  // pair has no callback. The range limiter still precedes their evaluation.
  let scale = self.scale
  let function_scale = self.function_scale
  let transform = self.coordinate_transform()
  let inverse = self.coordinate_inverse()
  let (lower, upper) = scale.limit_range_for_scale(lower, upper, minpos)
  // LogScale's default LogTransform clips nonpositive inputs at -1000.
  // Raw finite minpos overrides can reach this branch after the scale limiter.
  let transformed_lower = if function_scale is Some(_) {
    transform(lower)
  } else if scale.is_log() && lower <= 0.0 {
    -1000.0
  } else {
    scale.transform(lower)
  }
  let transformed_upper = if function_scale is Some(_) {
    transform(upper)
  } else if scale.is_log() && upper <= 0.0 {
    -1000.0
  } else {
    scale.transform(upper)
  }
  let padding = (transformed_upper - transformed_lower) * margin
  let padding = if padding.is_nan() || padding.is_inf() { 0.0 } else { padding }
  // InvertedLogTransform uses exp(x * ln(base)), with a separately rounded
  // product. Replacing that chain with pow(base, x) changes source results.
  let lower = if function_scale is Some(_) {
    inverse(transformed_lower - padding)
  } else if scale.is_log() {
    @math.exp((transformed_lower - padding) * @math.ln(10.0))
  } else {
    scale.inverse(transformed_lower - padding)
  }
  let upper = if function_scale is Some(_) {
    inverse(transformed_upper + padding)
  } else if scale.is_log() {
    @math.exp((transformed_upper + padding) * @math.ln(10.0))
  } else {
    scale.inverse(transformed_upper + padding)
  }
  let lower = match lower_sticky {
    Some(value) => if value > lower { value } else { lower }
    None => lower
  }
  let upper = match upper_sticky {
    Some(value) => if value < upper { value } else { upper }
    None => upper
  }
  let tight = match tight_provider {
    Some(provider) => provider()
    None => tight
  }
  Some(
    if tight {
      @core.limits(lower, upper)
    } else {
      autoscale_locator_view_limits(locator, lower, upper)
    },
  )
}

///|
/// Finalize already oriented set_bound endpoints while preserving auto-enable.
/// The owning panel controls lazy view reads and source-ordered sibling emits.
pub fn Axis::set_bound_limits_checked(
  self : Axis,
  lower : Double,
  upper : Double,
  automatic~ : Bool? = None,
) -> @core.Limits raise @core.DataError {
  if !@core.limits(lower, upper).is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="axis")
  }
  let (lower, upper) = if self.coordinate_scale_name() == "log" &&
    (lower <= 0.0 || upper <= 0.0) {
    let (old_lower, old_upper) = self.lifecycle_view_interval_checked()
    (
      if lower <= 0.0 {
        old_lower
      } else {
        lower
      },
      if upper <= 0.0 {
        old_upper
      } else {
        upper
      },
    )
  } else {
    (lower, upper)
  }
  let reversed = lower > upper
  let (lower, upper) = self.autoscale_nonsingular(lower, upper)
  let (lower, upper) = self.scale.limit_range_for_scale(
    lower,
    upper,
    self.get_minpos(),
  )
  let (low, high) = if upper < lower { (upper, lower) } else { (lower, upper) }
  let view = if reversed {
    @core.limits(high, low)
  } else {
    @core.limits(low, high)
  }
  self.stored_view = view
  self.inverted = reversed
  self.autoscale_pending = false
  if automatic is Some(enabled) {
    self.autoscale_enabled = enabled
  }
  if self.autoscale_enabled {
    self.limits = None
    self.auto_view = Some(view)
  } else {
    self.limits = Some(view)
    self.auto_view = None
  }
  if self.tick_layout_view is Some(_) {
    self.tick_layout_view = Some((view.lower(), view.upper()))
  }
  view
}
