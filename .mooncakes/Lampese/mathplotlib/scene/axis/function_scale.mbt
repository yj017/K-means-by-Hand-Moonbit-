///|
/// Function geometry is captured when the owner installs a scale. The stored
/// Linear/Log role supplies its default tickers and limit-range policy.
priv struct AxisFunctionScale {
  forward : (Double) -> Double
  inverse : (Double) -> Double
  logarithmic : Bool
}

///|
/// Install a numeric child function scale without borrowing parent ticker state.
/// The owner separately compares old/new default limits and performs autoscale.
pub fn Axis::configure_function_scale(
  self : Axis,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  logarithmic~ : Bool = false,
) -> Unit raise @core.DataError {
  self.scale = if logarithmic {
    @scale.Scale::Log
  } else {
    @scale.Scale::Linear
  }
  self.function_scale = Some({ forward, inverse, logarithmic, })
  self.install_scale_defaults()
  self.mark_scale_defaults()
}

///|
/// Return the installed coordinate context, independent of a live parent scale.
pub fn Axis::coordinate_scale_name(self : Axis) -> String {
  match self.function_scale {
    Some(context) =>
      if context.logarithmic {
        "functionlog"
      } else {
        "function"
      }
    None =>
      match self.scale {
        @scale.Linear => "linear"
        @scale.Log => "log"
        @scale.SymLog(..) => "symlog"
        @scale.Asinh(..) => "asinh"
        @scale.Logit(..) => "logit"
      }
  }
}

///|
/// Capture the installed transform; later owner resets cannot change this value.
pub fn Axis::coordinate_transform(self : Axis) -> (Double) -> Double {
  match self.function_scale {
    Some(context) =>
      fn(value) {
        let primary = (context.inverse)(value)
        if context.logarithmic {
          if primary <= 0.0 {
            -1000.0
          } else {
            @scale.Scale::Log.transform(primary)
          }
        } else {
          primary
        }
      }
    None => {
      let scale = self.scale
      value => scale.transform(value)
    }
  }
}

///|
/// Functionlog uses the source InvertedLogTransform's exp(x * ln(10)) chain.
pub fn Axis::coordinate_inverse(self : Axis) -> (Double) -> Double {
  match self.function_scale {
    Some(context) =>
      fn(value) {
        let primary = if context.logarithmic {
          @math.exp(value * @math.ln(10.0))
        } else {
          value
        }
        (context.forward)(primary)
      }
    None => {
      let scale = self.scale
      value => scale.inverse(value)
    }
  }
}

///|
/// The finite one-dimensional source tick-location route used by child axes.
/// View expansion is a raw interval operation, before installing FixedLocator;
/// it preserves inversion, auto-enable and pending-request state.
pub fn Axis::set_source_ticks(
  self : Axis,
  values : Array[Double],
) -> Unit raise @core.DataError {
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="tick positions must be finite",
      )
    }
  }
  let locator = @ticker.FixedLocator::new(values.copy())
  if !values.is_empty() {
    ignore(self.lifecycle_view_interval_checked())
    // The first view callback may mutate the caller's original sequence.
    // FixedLocator already copied it, but source min(ticks) still reads it now.
    if values.is_empty() {
      raise @core.DataError::InvalidTicks(
        message="min() iterable argument is empty",
      )
    }
    // Python min/max retain the first equal or unordered input, including
    // signed zero and a NaN introduced by the preceding callback.
    let mut ticks_min = values[0]
    let mut ticks_max = values[0]
    for value in values {
      if value < ticks_min {
        ticks_min = value
      }
      if value > ticks_max {
        ticks_max = value
      }
    }
    // The generated interval setter reads its raw Bbox through its captured
    // getter, independently of an overridden public get_view_interval method.
    let first = self.stored_view.lower()
    let last = self.stored_view.upper()
    let reversed = !(first < last)
    let old_lower = if reversed { last } else { first }
    let old_upper = if reversed { first } else { last }
    let lower = if old_lower < ticks_min { old_lower } else { ticks_min }
    let upper = if old_upper > ticks_max { old_upper } else { ticks_max }
    let view = if reversed {
      @core.limits(upper, lower)
    } else {
      @core.limits(lower, upper)
    }
    self.stored_view = view
    self.inverted = view.lower() > view.upper()
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
    // Original _set_tick_locations rereads the view before installing the
    // locator. A failing provider here leaves the expanded view and old slot.
    ignore(self.lifecycle_view_interval_checked())
  }
  self.set_locator(locator.as_locator())
}
