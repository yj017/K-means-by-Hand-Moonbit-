///|
fn logit_is_decade(value : ScalarNumber) -> Bool raise @core.DataError {
  if !log_format_isfinite(value, "isfinite") {
    return false
  }
  if scalar_numeric_equal(
      value,
      ScalarNumber::Integer(@bigint.BigInt::from_int(0)),
    ) {
    return true
  }
  let magnitude = scalar_numeric_double(scalar_numeric_abs(value))
  let phase = log_grid_natural_log(magnitude) / log_grid_natural_log(10.0)
  let rounded = scalar_math_rint(phase)
  // np.isclose uses its default absolute tolerance1e-8 in addition to the
  // explicit rtol1e-7, and anchors relative tolerance on the rounded operand.
  Double::abs(phase - rounded) <= 1.0e-8 + 1.0e-7 * Double::abs(rounded)
}

///|
fn logit_is_half(
  value : ScalarNumber,
  numpy_round~ : Bool,
) -> Bool raise @core.DataError {
  let twice = scalar_numeric_op(
    ScalarNumber::Integer(@bigint.BigInt::from_int(2)),
    value,
    2,
  )
  if !log_format_close(scalar_numeric_double(twice)) {
    return false
  }
  if numpy_round {
    if twice is Integer(integer) {
      if integer < @bigint.BigInt::from_int64(-9223372036854775808L) ||
        integer > @bigint.BigInt::from_uint64(18446744073709551615UL) {
        raise log_format_error(
          "TypeError: loop of ufunc does not support argument 0 of type int which has no callable rint method",
        )
      }
      return integer == @bigint.BigInt::from_int(1)
    }
    if scalar_numeric_integral(twice) {
      return scalar_numeric_integer(twice) == @bigint.BigInt::from_int(1)
    }
    return scalar_math_rint(scalar_numeric_double(twice)) == 1.0
  }
  log_format_round(scalar_numeric_double(twice)) == @bigint.BigInt::from_int(1)
}

///|
fn logit_count_less(
  count : Int32,
  bound : LogValue,
) -> Bool raise @core.DataError {
  match bound {
    Numeric(bound) =>
      eng_prefix_less(
        ScalarNumber::Integer(@bigint.BigInt::from_int(count)),
        bound,
      )
    _ =>
      raise log_format_error(
        "TypeError: '<' not supported between instances of 'int' and '" +
        log_format_type(bound) +
        "'",
      )
  }
}

///|
fn logit_slice_start(
  number : LogValue,
  length : Int32,
) -> Int32 raise @core.DataError {
  // Unary negation precedes the index protocol. NPBool raises here; NPInt64.min
  // wraps, whereas a floating result survives negation and fails only slicing.
  let negative = log_format_negative(number)
  if !scalar_numeric_integral(negative) {
    raise log_format_error(
      "TypeError: slice indices must be integers or None or have an __index__ method",
    )
  }
  let start = scalar_numeric_integer(negative)
  let length_big = @bigint.BigInt::from_int(length)
  let start = if start < @bigint.BigInt::from_int(0) {
    length_big + start
  } else {
    start
  }
  if start <= @bigint.BigInt::from_int(0) {
    0
  } else if start >= length_big {
    length
  } else {
    start.to_int()
  }
}
