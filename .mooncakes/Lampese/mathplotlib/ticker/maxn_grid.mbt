///|
// Keep the full NumPy arange shape for step selection and range endpoints.
// Only the final tick_values call materializes the bounded prefix.
priv struct MaxNGrid {
  low : Double
  index_step : Double
  length : Int64
  step : Double
  best_min : Double
  offset : Double
}

///|
fn maxn_grid_new(
  low : Double,
  high : Double,
  step : Double,
  best_min : Double,
  offset : Double,
) -> MaxNGrid raise @core.DataError {
  let count = (high + 1.0 - low).ceil()
  if count.is_nan() ||
    count.is_inf() ||
    count < -9223372036854775808.0 ||
    count >= 1152921504606846976.0 {
    raise @core.DataError::InvalidTicks(
      message="MaxN grid cannot compute a supported array length",
    )
  }
  let length = if count <= 0.0 { 0L } else { count.to_int64() }
  { low, index_step: low + 1.0 - low, length, step, best_min, offset, }
}

///|
fn MaxNGrid::value(
  self : MaxNGrid,
  index : Int64,
  with_offset~ : Bool = true,
) -> Double {
  let unit = if index == 0L {
    self.low
  } else if index == 1L {
    self.low + 1.0
  } else {
    numeric_arange_fill(self.low, self.index_step, index.to_double())
  }
  let scaled = unit * self.step
  let shifted = scaled + self.best_min
  if with_offset {
    shifted + self.offset
  } else {
    shifted
  }
}

///|
// Locate boundaries in the complete monotone grid, including repeated values.
fn MaxNGrid::boundary(self : MaxNGrid, target : Double, strict : Bool) -> Int64 {
  let mut lower = 0L
  let mut upper = self.length
  while lower < upper {
    let middle = lower + (upper - lower) / 2L
    let value = self.value(middle, with_offset=false)
    let after = if strict { value > target } else { value >= target }
    if after {
      upper = middle
    } else {
      lower = middle + 1L
    }
  }
  lower
}

///|
fn MaxNGrid::visible_count(
  self : MaxNGrid,
  lower : Double,
  upper : Double,
) -> Int64 {
  self.boundary(upper, true) - self.boundary(lower, false)
}

///|
fn maxn_log10(value : Double) -> Double raise @core.DataError {
  if value <= 0.0 {
    raise @core.DataError::InvalidTicks(
      message="MaxN scale logarithm is outside its domain",
    )
  }
  @math.log10(value)
}

///|
fn maxn_scale_range(
  lower : Double,
  upper : Double,
  bins : Double,
) -> (Double, Double) raise @core.DataError {
  if bins == 0.0 {
    raise @core.DataError::InvalidTicks(
      message="MaxN bin count divides by zero",
    )
  }
  let difference = Double::abs(upper - lower)
  let mean = (upper + lower) / 2.0
  let offset = if Double::abs(mean) / difference < 100.0 {
    0.0
  } else {
    let power = @tick_grid.divmod(maxn_log10(Double::abs(mean)), 1.0).0
    let value = log_grid_numpy_power(10.0, power)
    if mean.reinterpret_as_uint64() >> 63 == 0UL {
      value
    } else {
      -value
    }
  }
  let power = @tick_grid.divmod(maxn_log10(difference / bins), 1.0).0
  // Decimal integer powers use the shared correctly-rounded primitive. A libm
  // error here changes the selected step and its floored grid origin.
  (log_grid_numpy_power(10.0, power), offset)
}

///|
fn MaxNLocator::grid(
  self : MaxNLocator,
  lower : Double,
  upper : Double,
  raw_step_transform? : (Double) -> Double raise @core.DataError,
  require_tick_space~ : Bool = false,
) -> MaxNGrid raise @core.DataError {
  let bins = match self.nbins {
    Count(value) => Double::from_int(value)
    Auto =>
      match self.tick_space_provider {
        None => {
          if require_tick_space {
            raise @core.DataError::InvalidTicks(
              message="bound logit locator has no tick-space provider",
            )
          }
          9.0
        }
        Some(provider) => {
          let space = provider()
          let minimum = Double::from_int(Int32::max(1, self.min_n_ticks - 1))
          // np.clip returns its upper bound when the lower bound exceeds it.
          if space.is_nan() {
            space
          } else if minimum > 9.0 {
            9.0
          } else if space < minimum {
            minimum
          } else if space > 9.0 {
            9.0
          } else {
            space
          }
        }
      }
  }
  let (scale, offset) = maxn_scale_range(lower, upper, bins)
  let first = lower - offset
  let last = upper - offset
  let steps = self.extended_steps.map(value => value * scale)
  let steps = if self.integer {
    steps.filter(value => {
      value < 1.0 || Double::abs(value - value.round()) < 0.001
    })
  } else {
    steps
  }
  let raw_step = (last - first) / bins
  let raw_step = match raw_step_transform {
    Some(transform) => transform(raw_step)
    None => raw_step
  }
  // The source reads projection after filtering, even when no step remains.
  // Earlier scale-range failures still precede this optional context read.
  if steps.is_empty() {
    raise @core.DataError::InvalidTicks(
      message="MaxN integer filtering leaves no candidate step",
    )
  }
  let round_numbers = @config.axes_autolimit_mode() == "round_numbers"
  let mut first_large = steps.length() - 1
  for index, step in steps {
    let large = step >= raw_step
    let covers = if round_numbers {
      let floored = @tick_grid.divmod(first, step).0 * step
      floored + step * bins >= last
    } else {
      true
    }
    if large && covers {
      first_large = index
      break
    }
  }
  let mut result : MaxNGrid? = None
  let mut index = first_large
  while index >= 0 {
    let original_step = steps[index]
    let enough_integers = last.floor() - first.ceil() >=
      Double::from_int(self.min_n_ticks - 1)
    let step = if self.integer && enough_integers {
      // Python max(1, NaN) keeps its first argument.
      if original_step > 1.0 {
        original_step
      } else {
        1.0
      }
    } else {
      original_step
    }
    if step <= 0.0 || step.is_nan() || step.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="MaxN candidate step cannot form a finite grid",
      )
    }
    let best_min = @tick_grid.divmod(first, step).0 * step
    let low = @tick_grid.le(first - best_min, step, offset~)
    let high = @tick_grid.ge(last - best_min, step, offset~)
    let grid = maxn_grid_new(low, high, step, best_min, offset)
    result = Some(grid)
    if grid.visible_count(first, last) >= Int64::from_int(self.min_n_ticks) {
      break
    }
    index -= 1
  }
  result.unwrap()
}
