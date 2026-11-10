///|
priv struct AsinhGridPoint {
  xs : Double
  pows : Double
  value : Double
}

///|
priv struct AsinhGridContext {
  line : AsinhGridLine
  width : Double
  base : Double
  logarithm : Double
  cache : Map[UInt64, AsinhGridPoint]
}

///|
fn asinh_grid_round(value : Double) -> Double {
  if value.is_nan() ||
    value.is_inf() ||
    Double::abs(value) >= 4503599627370496.0 {
    return value
  }
  let lower = value.floor()
  let fraction = value - lower
  let rounded = if fraction > 0.5 ||
    (fraction == 0.5 && (lower.to_int64() & 1L) != 0L) {
    lower + 1.0
  } else {
    lower
  }
  if rounded == 0.0 {
    0.0 * value
  } else {
    rounded
  }
}

///|
fn AsinhGridContext::point(
  self : AsinhGridContext,
  y : Double,
) -> AsinhGridPoint {
  let key = y.reinterpret_as_uint64()
  if self.cache.get(key) is Some(value) {
    return value
  }
  let xs = self.width * asinh_math_sinh(y / self.width)
  let point = if self.base > 1.0 {
    let sign = if xs.is_nan() {
      xs
    } else if xs > 0.0 {
      1.0
    } else if xs < 0.0 {
      -1.0
    } else {
      0.0
    }
    let phase = (log_grid_natural_log(Double::abs(xs)) / self.logarithm).floor()
    let pows = sign * log_grid_numpy_power(self.base, phase)
    { xs, pows, value: pows, }
  } else {
    // np.where's zero predicate is ys==0, not the possibly underflowed xs.
    let pows = if y == 0.0 {
      1.0
    } else {
      log_grid_numpy_power(10.0, asinh_math_log10(Double::abs(xs)).floor())
    }
    { xs, pows, value: pows * asinh_grid_round(xs / pows), }
  }
  self.cache[key] = point
  point
}

///|
fn AsinhGridContext::value(
  self : AsinhGridContext,
  run : AsinhGridRun,
  offset : Int64,
  factor : Double,
) -> Double {
  let point = self.point(run.at(self.line, offset))
  if self.base > 1.0 {
    point.pows * factor
  } else {
    point.value
  }
}

///|
// The source's late truth test distinguishes numeric sequences, ndarrays,
// and scalar inputs. Only the selected np.outer path consumes truthy text.
fn asinh_grid_subs(
  raw : AsinhSubs?,
) -> (Array[Double], Bool) raise @core.DataError {
  match raw {
    None => ([1.0], false)
    Some(Sequence(values)) =>
      if values.is_empty() {
        ([1.0], false)
      } else {
        (values, true)
      }
    Some(Tuple(values)) =>
      if values.length() == 0 {
        ([1.0], false)
      } else {
        (values.values(), true)
      }
    Some(NdArray(values)) => {
      if values.length() != 1 {
        raise log_grid_error("Asinh ndarray truth value is ambiguous")
      }
      let value = values.get(0)
      if value == 0.0 {
        ([1.0], false)
      } else {
        ([value], true)
      }
    }
    Some(Number(value)) =>
      if value == 0.0 {
        ([1.0], false)
      } else {
        ([value], true)
      }
    Some(Text(value)) =>
      if value == "" {
        ([1.0], false)
      } else {
        raise log_grid_error(
          "Asinh outer product cannot multiply numeric values by text",
        )
      }
  }
}

///|
// On a finite same-sign ys run, abs(ys) increases in the selected direction.
// Class0/1/2 means NaN below / numeric / NaN above its contiguous numeric
// interval. Special bases and Inf/zero subs retain their distinct IEEE cases.
fn AsinhGridContext::classify(
  self : AsinhGridContext,
  run : AsinhGridRun,
  offset : Int64,
  factor : Double,
) -> Int32 {
  let point = self.point(run.at(self.line, offset))
  if self.base > 1.0 {
    if self.base.is_inf() {
      if point.xs == 0.0 {
        0
      } else if point.xs.is_inf() {
        2
      } else {
        1
      }
    } else if factor.is_inf() {
      if point.pows == 0.0 {
        0
      } else {
        1
      }
    } else if factor == 0.0 {
      if point.pows.is_inf() {
        2
      } else {
        1
      }
    } else {
      1
    }
  } else if point.xs.is_inf() {
    2
  } else if point.value.is_nan() {
    0
  } else {
    1
  }
}

///|
fn named_asinh_locator_ticks(
  locator : AsinhLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  let width = locator.linear_width
  // Preserve the source's two separate divisions and width multiplications.
  let first = width * asinh_math_asinh(lower / width)
  let last = width * asinh_math_asinh(upper / width)
  let count = asinh_grid_count(locator.numticks)
  let line = asinh_grid_line(first, last, count)
  let runs = asinh_grid_runs(line)
  let context : AsinhGridContext = {
    line,
    width,
    base: locator.base,
    logarithm: log_grid_natural_log(locator.base),
    cache: Map([]),
  }
  let (factors, outer) = if locator.base > 1.0 {
    asinh_grid_subs(locator.subs)
  } else {
    ([1.0], false)
  }
  let mut row_count = 0L
  for run in runs {
    row_count += run.length
  }
  let full_shape = @bigint.BigInt::from_int64(row_count) *
    @bigint.BigInt::from_int(factors.length())
  if full_shape >= @bigint.BigInt::from_int(1) << 60 {
    raise log_grid_error("Asinh full outer array exceeds the NumPy byte size")
  }
  ignore(outer)
  let heap : Array[AsinhGridCursor] = []
  let mut nan_count = 0L
  for run in runs {
    for subdivision, factor in factors {
      let multiplier = factors.length().to_int64()
      if run.constant is Some(_) {
        let value = context.value(run, 0L, factor)
        if value.is_nan() {
          nan_count += run.length
        } else {
          asinh_grid_heap_push(
            heap,
            asinh_grid_cursor(
              context, run, 0L, 1L, false, factor, subdivision, multiplier, 0L,
            ),
          )
        }
      } else if factor.is_nan() && locator.base > 1.0 {
        nan_count += run.length
      } else {
        let increasing = Double::abs(run.at(line, 0L)) <=
          Double::abs(run.at(line, run.length - 1L))
        let position = fn(index : Int64) {
          if increasing {
            index
          } else {
            run.length - 1L - index
          }
        }
        let first_numeric = asinh_grid_boundary(run.length, index => {
          context.classify(run, position(index), factor) >= 1
        })
        let after_numeric = asinh_grid_boundary(run.length, index => {
          context.classify(run, position(index), factor) >= 2
        })
        nan_count += first_numeric + run.length - after_numeric
        if after_numeric > first_numeric {
          let (first, last) = if increasing {
            (first_numeric, after_numeric)
          } else {
            (run.length - after_numeric, run.length - first_numeric)
          }
          asinh_grid_push_numeric(
            heap, context, run, first, last, factor, subdivision, multiplier,
          )
        }
      }
    }
  }
  let values : Array[Double] = []
  while !heap.is_empty() && values.length() < 100000 {
    let cursor = asinh_grid_heap_pop(heap)
    if values.is_empty() || values[values.length() - 1] != cursor.value {
      values.push(cursor.value)
    }
    if cursor.next < cursor.last - cursor.first {
      asinh_grid_heap_push(
        heap,
        asinh_grid_cursor(
          context,
          cursor.run,
          cursor.first,
          cursor.last,
          cursor.reverse,
          cursor.factor,
          cursor.subdivision,
          cursor.multiplier,
          cursor.next,
        ),
      )
    }
  }
  if values.length().to_int64() + nan_count < 2L {
    let fallback = asinh_grid_line(lower, upper, count)
    return Array::makei(
      if fallback.count > 100000L {
        100000
      } else {
        fallback.count.to_int()
      },
      index => fallback.at(index.to_int64()),
    )
  }
  // Deterministic profile for Python's genuinely nondeterministic NaN set order:
  // numeric ascending, earliest flattened zero, all individual NaNs last.
  let remaining = Int64::min(nan_count, (100000 - values.length()).to_int64()).to_int()
  for _ in 0..<remaining {
    values.push(0.0 / 0.0)
  }
  values
}
