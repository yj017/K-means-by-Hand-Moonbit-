///|
// NumPy's integer-array _clip first discards out-of-range *Python int*
// endpoints. This precedes ufunc promotion; converting all bounds eagerly
// would reject valid wide integer prefix tables.
fn eng_math_clip(
  phase : @bigint.BigInt,
  lower : ScalarNumber,
  upper : ScalarNumber,
) -> ScalarNumber raise @core.DataError {
  let no_lower = match lower {
    Integer(value) => value <= @bigint.BigInt::from_int64(-9223372036854775808L)
    _ => false
  }
  let no_upper = match upper {
    Integer(value) => value >= @bigint.BigInt::from_int64(9223372036854775807L)
    _ => false
  }
  let floating = (!no_lower && lower is (Number(_) | NumpyFloat64(_))) ||
    (!no_upper && upper is (Number(_) | NumpyFloat64(_)))
  if floating {
    let value = scalar_numeric_double(ScalarNumber::Integer(phase))
    let a = if no_lower { None } else { Some(scalar_numeric_double(lower)) }
    let b = if no_upper { None } else { Some(scalar_numeric_double(upper)) }
    let result = match (a, b) {
      (Some(a), Some(b)) =>
        if a.is_nan() {
          a
        } else if b.is_nan() {
          b
        } else if value < a {
          a
        } else if value > b {
          b
        } else {
          value
        }
      // One-bound paths are NumPy maximum/minimum, not the clip loop.
      // phase0 is positive zero: maximum with lower -0 keeps +0, whereas
      // minimum with upper -0 returns -0. Keep these tie rules separate.
      (Some(a), None) => if a.is_nan() || value < a { a } else { value }
      (None, Some(b)) => if b.is_nan() || value >= b { b } else { value }
      (None, None) => value
    }
    ScalarNumber::NumpyFloat64(result)
  } else {
    let value = scalar_numeric_int64(ScalarNumber::Integer(phase))
    let a = if no_lower { None } else { Some(scalar_numeric_int64(lower)) }
    let b = if no_upper { None } else { Some(scalar_numeric_int64(upper)) }
    let result = match (a, b) {
      (Some(a), Some(b)) =>
        if value < a {
          a
        } else if value > b {
          b
        } else {
          value
        }
      (Some(a), None) => if value < a { a } else { value }
      (None, Some(b)) => if value > b { b } else { value }
      (None, None) => value
    }
    ScalarNumber::NumpyInt64(result)
  }
}

///|
// Preserve math.log's PyLong path without first overflowing a Double cast.
// Round each natural logarithm independently before the base division.
fn eng_math_natural_log(value : ScalarNumber) -> Double raise @core.DataError {
  match value {
    Integer(integer) => {
      if integer <= @bigint.BigInt::from_int(0) {
        raise @core.DataError::InvalidTicks(
          message="ValueError: math domain error",
        )
      }
      for precision = 192 {
        let (lower, upper) = asinh_math_log_bounds(integer, 0, precision)
        let a = index_round_binary(lower, -precision)
        let b = index_round_binary(upper, -precision)
        if a.reinterpret_as_uint64() == b.reinterpret_as_uint64() {
          return a
        }
        continue precision * 2
      }
    }
    _ => {
      let value = scalar_numeric_double(value)
      if value <= 0.0 {
        raise @core.DataError::InvalidTicks(
          message="ValueError: math domain error",
        )
      }
      log_grid_natural_log(value)
    }
  }
}

///|
fn eng_math_order(span : ScalarNumber) -> ScalarNumber raise @core.DataError {
  let numerator = eng_math_natural_log(span)
  let denominator = log_grid_natural_log(1000.0)
  let ratio = numerator / denominator
  ScalarNumber::Integer(
    scalar_numeric_floor(ratio) * @bigint.BigInt::from_int(3),
  )
}
