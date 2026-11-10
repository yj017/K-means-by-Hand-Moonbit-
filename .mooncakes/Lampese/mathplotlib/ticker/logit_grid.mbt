///|
// range() supplies Python integers in the original ideal list comprehension.
// The accepted portable profile evaluates their powers with exact-input,
// correctly rounded integer power, then preserves the source subtraction.
fn logit_grid_ideal(phase : Int32) -> Double {
  if phase < 0 {
    log_grid_numpy_power(10.0, phase.to_double())
  } else if phase > 0 {
    1.0 - log_grid_numpy_power(10.0, -phase.to_double())
  } else {
    0.5
  }
}

///|
fn logit_grid_phase(value : Double) -> Int32 raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise log_grid_error("Logit integer phase cannot convert NaN or infinity")
  }
  // A finite specialized log10 of a binary64 argument has magnitude <=324.
  // Invalid probability bounds reach the NaN/Inf check above, not a phase cap.
  value.to_int()
}

///|
fn named_logit_locator_ticks(
  locator : LogitLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  match locator.projection_provider {
    Some(provider) =>
      if provider() == "polar" {
        raise log_grid_error("Polar axis cannot be logit scaled yet")
      }
    None => ()
  }
  let bins = match locator.maxn.nbins() {
    Count(value) => value.to_double()
    Auto =>
      match locator.maxn.tick_space_provider() {
        Some(provider) => {
          let value = provider()
          // The first Logit read has no upper clip and preserves NaN/fractions.
          if value < 2.0 {
            2.0
          } else {
            value
          }
        }
        None =>
          if locator.is_bound() {
            raise log_grid_error(
              "bound Logit auto ticks have no tick-space provider",
            )
          } else {
            9.0
          }
      }
  }
  let (lower, upper) = locator.nonsingular(lower, upper)
  let first = logit_grid_phase(
    if lower < 0.5 {
      asinh_math_log10(lower).floor()
    } else if lower < 0.9 {
      0.0
    } else {
      -asinh_math_log10(1.0 - lower).ceil()
    },
  )
  let last = logit_grid_phase(
    if upper <= 0.5 {
      asinh_math_log10(upper).ceil()
    } else if upper <= 0.9 {
      1.0
    } else {
      -asinh_math_log10(1.0 - upper).floor()
    },
  )
  let ideal_count = last - first - 1
  if ideal_count >= 2 {
    let values : Array[Double] = []
    if ideal_count.to_double() > bins {
      if bins == 0.0 {
        raise log_grid_error("Logit ideal subsampling divides by zero")
      }
      let factor = (ideal_count.to_double() / bins).ceil().to_int()
      if factor == 0 {
        raise log_grid_error("Logit ideal subsampling has zero modulo divisor")
      }
      for phase in first..<=last {
        if (phase % factor == 0) != locator.minor {
          values.push(logit_grid_ideal(phase))
        }
      }
    } else if locator.minor {
      for phase in first..<last {
        if phase < -1 {
          let power = log_grid_numpy_power(10.0, phase.to_double())
          for multiple in 2..<10 {
            values.push(multiple.to_double() * power)
          }
        } else if phase == -1 {
          for multiple in 2..<5 {
            values.push(multiple.to_double() / 10.0)
          }
        } else if phase == 0 {
          for multiple in 6..<9 {
            values.push(multiple.to_double() / 10.0)
          }
        } else {
          let power = log_grid_numpy_power(10.0, (-phase - 1).to_double())
          for index in 0..<8 {
            let scaled = (9 - index).to_double() * power
            values.push(1.0 - scaled)
          }
        }
      }
    } else {
      for phase in first..<=last {
        values.push(logit_grid_ideal(phase))
      }
    }
    // The complete legal-Double ideal/minor shapes are at most341/2710.
    // Preserve neighbors, repetitions and underflow zeros; this is no set.
    return values
  }
  if locator.minor {
    []
  } else {
    locator.maxn_fallback_ticks(lower, upper)
  }
}
