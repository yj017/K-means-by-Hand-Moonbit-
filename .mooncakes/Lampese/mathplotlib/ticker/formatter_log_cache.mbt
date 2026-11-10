///|
// Opaque, immutable generated-set descriptor. Query coefficients are rounded
// binary64 values, hence exactly representable as Double; exact comparisons
// reproduce Python set membership without arbitrary-key weak-equality rules.
priv enum LogSublabelCache {
  Explicit(Array[Double])
  Arange(Int64)
  Geom(AsinhGridLine, Double)
}

///|
fn log_cache_explicit(values : Array[Double]) -> LogSublabelCache {
  LogSublabelCache::Explicit(values)
}

///|
fn log_cache_geom_point(
  line : AsinhGridLine,
  base : Double,
  index : Int64,
) -> Double {
  if index == 0L {
    return 1.0
  }
  if index == line.count - 1L && line.requested > 1L {
    return base
  }
  scalar_math_pow10(line.at(index))
}

///|
fn log_cache_at(cache : LogSublabelCache, index : Int64) -> Double {
  match cache {
    Explicit(values) => values[index.to_int()]
    Arange(_) => numeric_arange_fill(1.0, 1.0, index.to_double())
    Geom(line, base) =>
      scalar_math_rint(log_cache_geom_point(line, base, index))
  }
}

///|
fn log_cache_contains(cache : LogSublabelCache, value : Double) -> Bool {
  match cache {
    Explicit(values) => values.contains(value)
    Arange(length) => {
      let first = asinh_grid_boundary(length, index => {
        log_cache_at(cache, index) >= value
      })
      first < length && log_cache_at(cache, first) == value
    }
    Geom(line, _) => {
      if line.count == 0L {
        return false
      }
      if value == log_cache_at(cache, line.count - 1L) {
        return true
      }
      let length = if line.requested > 1L {
        line.count - 1L
      } else {
        line.count
      }
      let first = asinh_grid_boundary(length, index => {
        log_cache_at(cache, index) >= value
      })
      first < length && log_cache_at(cache, first) == value
    }
  }
}

///|
fn log_cache_values(
  cache : LogSublabelCache,
) -> Array[Double] raise @core.DataError {
  let result : Array[Double] = []
  match cache {
    Explicit(values) => {
      for value in values {
        if !result.contains(value) {
          result.push(value)
        }
      }
      result.sort()
    }
    Arange(length) => {
      // Until 2^53 all entries are distinct. A longer arange already contains
      // more than Int32.MAX distinct entries, regardless of later plateaus.
      if length > 2147483647L {
        raise log_format_error(
          "ResourceError: log sublabel snapshot exceeds Array addressability",
        )
      }
      for index = 0L; index < length; index = index + 1L {
        result.push(log_cache_at(cache, index))
      }
    }
    Geom(line, base) => {
      // Only a low-coefficient prefix is used for this addressability proof.
      // For base>2^40, n>=2^39 and L=RN(log10(base))<19. The next phase
      // increment is bounded by 20/(n-1)+20*2^-52*n/(n-1)+2^-48 <2^-34.
      // Below coefficient 2^32+1 this gives a rounded-power increment <0.577,
      // hence a rounded-integer jump at most1. The monotone prefix therefore
      // contains every integer1..2^31+1: more than Array.MAX distinct values.
      // There is deliberately no claim about jumps near the large endpoint.
      if base > 1099511627776.0 {
        raise log_format_error(
          "ResourceError: log sublabel snapshot exceeds Array addressability",
        )
      }
      let length = if line.requested > 1L {
        line.count - 1L
      } else {
        line.count
      }
      let mut index = 0L
      while index < length {
        let value = log_cache_at(cache, index)
        if result.length() == 2147483647 {
          raise log_format_error(
            "ResourceError: log sublabel snapshot exceeds Array addressability",
          )
        }
        result.push(value)
        // Exponential search keeps common short plateaus local; the final
        // binary search still respects the complete logical shape.
        let mut distance = 1L
        while distance < length - index &&
              log_cache_at(cache, index + distance) <= value {
          distance = Int64::min(distance * 2L, length - index)
        }
        let after = asinh_grid_boundary(
          Int64::min(distance + 1L, length - index),
          offset => log_cache_at(cache, index + offset) > value,
        )
        index += after
      }
      if line.count > 0L && line.requested > 1L {
        let last = scalar_math_rint(base)
        if !result.contains(last) {
          if result.length() == 2147483647 {
            raise log_format_error(
              "ResourceError: log sublabel snapshot exceeds Array addressability",
            )
          }
          result.push(last)
          result.sort()
        }
      }
    }
  }
  result
}

///|
fn log_cache_arange(base : Double) -> LogSublabelCache raise @core.DataError {
  let stop = base + 1.0
  let length = (stop - 1.0).ceil()
  if length.is_nan() {
    raise log_format_error("ValueError: arange: cannot compute length")
  }
  if length.is_inf() ||
    length >= 9223372036854775808.0 ||
    length < -9223372036854775808.0 {
    raise log_format_error("ValueError: Maximum allowed size exceeded")
  }
  if length >= 1152921504606846976.0 {
    raise log_format_error(
      "ValueError: array is too big; `arr.size * arr.dtype.itemsize` is larger than the maximum possible size.",
    )
  }
  LogSublabelCache::Arange(if length <= 0.0 { 0L } else { length.to_int64() })
}

///|
fn log_cache_geom(base : Double) -> LogSublabelCache raise @core.DataError {
  // geomspace checks zero, then computes its log endpoints before linspace
  // validates num. Native RuntimeWarning routing remains a host boundary.
  if base == 0.0 {
    raise log_format_error("ValueError: Geometric sequence cannot include zero")
  }
  let integer = scalar_numeric_integer(ScalarNumber::Number(base))
  let two = @bigint.BigInt::from_int(2)
  let requested = log_format_floor_div(integer, two) +
    @bigint.BigInt::from_int(1)
  if requested < @bigint.BigInt::from_int(0) {
    raise log_format_error(
      "ValueError: Number of samples, " +
      scalar_percent_integer_str(requested) +
      ", must be non-negative.",
    )
  }
  let count = index_round_binary(requested, 0)
  if count >= 9223372036854775808.0 {
    raise log_format_error("ValueError: Maximum allowed size exceeded")
  }
  if count >= 1152921504606846976.0 {
    raise log_format_error(
      "ValueError: array is too big; `arr.size * arr.dtype.itemsize` is larger than the maximum possible size.",
    )
  }
  // Negative-base source branches that reach a nonnegative count have only
  // 0 or 1 points; the forced initial endpoint is the sole surviving value.
  if requested <= @bigint.BigInt::from_int(1) {
    return log_cache_explicit(if requested.is_zero() { [] } else { [1.0] })
  }
  LogSublabelCache::Geom(
    asinh_grid_line(0.0, asinh_math_log10(base), requested.to_int64()),
    base,
  )
}
