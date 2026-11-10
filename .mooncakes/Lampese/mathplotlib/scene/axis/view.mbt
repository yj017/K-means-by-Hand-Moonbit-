///|
/// Set a provisional view without disabling automatic limits.
///
/// Images use this to fit their extent immediately. A later autoscale request
/// discards the provisional view and retains its direction. Explicit limits
/// take precedence. Both endpoints must be valid for this axis scale.
///
/// ```mbt check
/// test {
///   let axis = @axis.axis()
///   axis.set_auto_limits(1.5, -0.5)
///   assert_true(axis.inverted())
///   axis.request_autoscale()
///   let view = axis.view_limits(@core.limits(-2.0, 3.0))
///   assert_eq((view.lower(), view.upper()), (3.0, -2.0))
/// }
/// ```
pub fn Axis::set_auto_limits(
  self : Axis,
  lower : Double,
  upper : Double,
) -> Unit {
  if self.autoscale_enabled &&
    self.scale.is_valid(lower) &&
    self.scale.is_valid(upper) &&
    lower != upper {
    self.auto_view = Some(@core.limits(lower, upper))
    self.limits = None
    self.stored_view = @core.limits(lower, upper)
    self.autoscale_pending = false
    self.inverted = lower > upper
  }
}

///|
/// Recompute the automatic view on its next use while retaining explicit
/// limits and the axis direction.
pub fn Axis::request_autoscale(self : Axis) -> Unit {
  self.auto_view = None
  self.autoscale_pending = true
}

///|
/// Whether this axis displays larger values before smaller values.
pub fn Axis::inverted(self : Axis) -> Bool {
  self.inverted
}

///|
/// Resolve explicit or provisional limits before using an automatic range.
/// Automatic endpoints are sorted and then oriented to match the axis.
pub fn Axis::view_limits(self : Axis, automatic : @core.Limits) -> @core.Limits {
  try! self.view_limits_checked(automatic)
}

///|
/// Resolve a view while preserving named locator range errors.
pub fn Axis::view_limits_checked(
  self : Axis,
  automatic : @core.Limits,
) -> @core.Limits raise @core.DataError {
  match (self.limits, self.auto_view) {
    (Some(limits), _) | (None, Some(limits)) => limits
    (None, None) => {
      if self.tickers.major_locator_kind != Numeric {
        let bounds = self.locator_view_limits_checked(
          automatic.lower(),
          automatic.upper(),
        )
        return if self.inverted {
          @core.limits(bounds.upper(), bounds.lower())
        } else {
          bounds
        }
      }
      let (lower, upper) = match self.tickers.locator {
        Some(@ticker.Locator::NamedLogit(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedAsinh(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedSymLog(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedLog(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::Null(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedMaxN(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedAuto(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedLinear(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::Index(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::NamedFixed(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        Some(@ticker.Locator::Multiple(value)) =>
          value.view_limits(automatic.lower(), automatic.upper())
        _ =>
          (
            Double::min(automatic.lower(), automatic.upper()),
            Double::max(automatic.lower(), automatic.upper()),
          )
      }
      if self.inverted {
        @core.limits(upper, lower)
      } else {
        @core.limits(lower, upper)
      }
    }
  }
}

///|
/// Store a resolved view while retaining explicit or automatic limit selection.
/// Invalid endpoints raise DataError before changing the view. In automatic
/// mode a later request_autoscale() discards this provisional range.
///
/// ```mbt check
/// test {
///   let axis = @axis.axis()
///   try! axis.set_view_limits(-1.0, 2.0)
///   assert_true(axis.limits() is None)
///   assert_eq(axis.current_view_limits().unwrap().lower(), -1.0)
///   axis.request_autoscale()
///   assert_true(axis.current_view_limits() is None)
/// }
/// ```
pub fn Axis::set_view_limits(
  self : Axis,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  if self.scale.is_logit() {
    let view = self.logit_limit_bounds_checked(lower, upper)
    if self.limits is Some(_) {
      self.limits = Some(view)
      self.auto_view = None
    } else {
      self.auto_view = Some(view)
    }
    self.inverted = view.lower() > view.upper()
    self.stored_view = view
    self.autoscale_pending = false
    if self.tick_layout_view is Some(_) {
      self.tick_layout_view = Some((view.lower(), view.upper()))
    }
    return
  }
  if !self.scale.is_valid(lower) || !self.scale.is_valid(upper) {
    raise @core.DataError::NonFiniteLimit(axis="view")
  }
  let view = @core.limits(lower, upper)
  if self.limits is Some(_) {
    self.limits = Some(view)
    self.auto_view = None
  } else {
    self.auto_view = Some(view)
  }
  self.inverted = lower > upper
  self.stored_view = view
  self.autoscale_pending = false
  if self.tick_layout_view is Some(_) {
    self.tick_layout_view = Some((lower, upper))
  }
}

///|
/// Return a stored explicit/provisional view without computing automatic limits.
///
/// ```mbt check
/// test {
///   let axis = @axis.axis()
///   assert_true(axis.current_view_limits() is None)
///   try! axis.set_limits(2.0, -1.0)
///   assert_eq(axis.current_view_limits().unwrap().upper(), -1.0)
/// }
/// ```
pub fn Axis::current_view_limits(self : Axis) -> @core.Limits? {
  match self.limits {
    Some(_) => self.limits
    None => self.auto_view
  }
}

///|
/// Apply named numeric locators' inherited nonsingular policy before margins.
/// Other locator families retain their existing range policy.
pub fn Axis::numeric_nonsingular_bounds(
  self : Axis,
  lower : Double,
  upper : Double,
) -> @core.Limits {
  match self.tickers.locator {
    Some(@ticker.Locator::NamedLogit(value)) => {
      let (first, last) = value.nonsingular(lower, upper) catch {
        _ => (lower, upper)
      }
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedAsinh(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedSymLog(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedLog(value)) => {
      let (first, last) = value.nonsingular(lower, upper) catch {
        _ => (lower, upper)
      }
      @core.limits(first, last)
    }
    Some(@ticker.Locator::Null(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedMaxN(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedAuto(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedLinear(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::Index(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::NamedFixed(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    Some(@ticker.Locator::Multiple(value)) => {
      let (first, last) = value.nonsingular(lower, upper)
      @core.limits(first, last)
    }
    _ => @core.limits(lower, upper)
  }
}
