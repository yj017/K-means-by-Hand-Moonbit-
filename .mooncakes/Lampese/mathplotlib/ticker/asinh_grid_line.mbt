///|
// The full NumPy scalar linspace, including its denormal path and final write.
// This is separate multiply/add, rather than NumPy arange's FMA fill profile.
priv struct AsinhGridLine {
  first : Double
  last : Double
  delta : Double
  step : Double
  requested : Int64
  count : Int64
}

///|
fn asinh_grid_line(
  first : Double,
  last : Double,
  count : Int64,
) -> AsinhGridLine {
  let delta = last - first
  {
    first,
    last,
    delta,
    step: delta / (count - 1L).to_double(),
    requested: count,
    // PyArray_ArangeObj uses ceil(PyNumber_TrueDivide(num-0,1)).
    count: count.to_double().to_int64(),
  }
}

///|
fn AsinhGridLine::at(self : AsinhGridLine, index : Int64) -> Double {
  if self.requested > 1L && index == self.count - 1L {
    return self.last
  }
  let index = index.to_double()
  if self.requested <= 1L {
    return index * self.delta + self.first
  }
  if self.step == 0.0 {
    index / (self.requested - 1L).to_double() * self.delta + self.first
  } else {
    index * self.step + self.first
  }
}

///|
priv struct AsinhGridRun {
  first : Int64
  length : Int64
  rank : Int64
  constant : Double?
}

///|
fn AsinhGridRun::at(
  self : AsinhGridRun,
  line : AsinhGridLine,
  position : Int64,
) -> Double {
  match self.constant {
    Some(value) => value
    None => line.at(self.first + position)
  }
}

///|
fn asinh_grid_boundary(length : Int64, predicate : (Int64) -> Bool) -> Int64 {
  let mut lower = 0L
  let mut upper = length
  while lower < upper {
    let middle = lower + (upper - lower) / 2L
    if predicate(middle) {
      upper = middle
    } else {
      lower = middle + 1L
    }
  }
  lower
}

///|
fn asinh_grid_count(raw : LogNumTicks?) -> Int64 raise @core.DataError {
  let count = match raw {
    Some(Integer(value)) => value
    _ =>
      raise log_grid_error(
        "Asinh linspace count requires Python's integer index protocol",
      )
  }
  if count < @bigint.BigInt::from_int(0) {
    raise log_grid_error("Asinh linspace number of samples must be nonnegative")
  }
  // The original np.arange(...,dtype=float64) rejects this whole byte shape.
  // Only after that exact check is it safe to use an Int64 descriptor index.
  if count >= @bigint.BigInt::from_int(1) << 60 ||
    index_round_binary(count, 0) >= 1152921504606846976.0 {
    raise log_grid_error("Asinh linspace array exceeds the NumPy byte size")
  }
  count.to_int64()
}

///|
fn asinh_grid_runs(
  line : AsinhGridLine,
) -> Array[AsinhGridRun] raise @core.DataError {
  let crossing = line.first * line.last < 0.0
  if crossing && line.requested == 0L {
    raise log_grid_error("Asinh cross-zero Python count division is zero")
  }
  let candidates : Array[AsinhGridRun] = []
  if line.count > 0L {
    let finite = !line.first.is_nan() &&
      !line.first.is_inf() &&
      !line.last.is_nan() &&
      !line.last.is_inf() &&
      !line.delta.is_inf()
    if finite && line.count > 1L {
      // Keep the forced last value separate: it can be one ULP behind the
      // rounded penultimate value even when the mathematical grid increases.
      let length = line.count - 1L
      let increasing = line.delta >= 0.0
      let first_zero = asinh_grid_boundary(length, index => {
        let value = line.at(index)
        if increasing {
          value >= 0.0
        } else {
          value <= 0.0
        }
      })
      let after_zero = asinh_grid_boundary(length, index => {
        let value = line.at(index)
        if increasing {
          value > 0.0
        } else {
          value < 0.0
        }
      })
      for
        (first, last, zero) in [
          (0L, first_zero, false),
          (first_zero, after_zero, true),
          (after_zero, length, false),
        ] {
        if last > first {
          candidates.push({
            first,
            length: last - first,
            rank: 0L,
            constant: if zero {
              Some(line.at(first))
            } else {
              None
            },
          })
        }
      }
      candidates.push({
        first: 0L,
        length: 1L,
        rank: 0L,
        constant: Some(line.last),
      })
    } else if !finite && !crossing && line.count > 1L {
      // With a NaN/Inf delta, every interior arithmetic point is the same
      // IEEE value. Count its NaNs without enumerating the full allocation.
      candidates.push({
        first: 0L,
        length: 1L,
        rank: 0L,
        constant: Some(line.at(0L)),
      })
      if line.count > 2L {
        candidates.push({
          first: 0L,
          length: line.count - 2L,
          rank: 0L,
          constant: Some(line.at(1L)),
        })
      }
      candidates.push({
        first: 0L,
        length: 1L,
        rank: 0L,
        constant: Some(line.last),
      })
    } else if finite || !crossing {
      candidates.push({
        first: 0L,
        length: line.count,
        rank: 0L,
        constant: Some(line.at(0L)),
      })
    }
    // A nonfinite crossing span gives abs(ys/span) only NaN or zero:
    // the source strict comparison drops all of them, then appends zero.
  }
  let result : Array[AsinhGridRun] = []
  let mut rank = 0L
  let threshold = 0.5 / line.requested.to_double()
  for run in candidates {
    let (first, last) = if crossing {
      let keep = fn(index : Int64) {
        Double::abs(run.at(line, index) / line.delta) > threshold
      }
      if run.constant is Some(_) {
        if keep(0L) {
          (0L, run.length)
        } else {
          (0L, 0L)
        }
      } else if Double::abs(run.at(line, 0L)) <=
        Double::abs(run.at(line, run.length - 1L)) {
        (asinh_grid_boundary(run.length, keep), run.length)
      } else {
        (0L, asinh_grid_boundary(run.length, index => !keep(index)))
      }
    } else {
      (0L, run.length)
    }
    if last > first {
      result.push({
        ..run,
        first: run.first + first,
        length: last - first,
        rank,
      })
      rank += last - first
    }
  }
  if crossing {
    result.push({ first: 0L, length: 1L, rank, constant: Some(0.0), })
  }
  result
}
