///|
fn scalar_percent_double(value : ScalarNumber) -> Double raise @core.DataError {
  match value {
    Number(value) | NumpyFloat64(value) => value
    Integer(value) => percent_python_integer_double(value)
    NumpyInt64(value) => value.to_double()
    Boolean(value) | NumpyBool(value) => if value { 1.0 } else { 0.0 }
  }
}

///|
fn scalar_percent_integer_str(
  value : @bigint.BigInt,
) -> String raise @core.DataError {
  let magnitude = if value < @bigint.BigInt::from_int(0) {
    value.neg()
  } else {
    value
  }
  if magnitude.bit_length() >= 14285 && magnitude >= decimal_power(4300) {
    return named_format_error(
      "ValueError", "Exceeds the limit (4300 digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit",
    )
  }
  value.to_string()
}

///|
fn scalar_percent_str(value : ScalarNumber) -> String raise @core.DataError {
  match value {
    Number(value) | NumpyFloat64(value) => named_format_float_repr(value)
    Integer(value) => scalar_percent_integer_str(value)
    NumpyInt64(value) => value.to_string()
    Boolean(value) | NumpyBool(value) => if value { "True" } else { "False" }
  }
}

///|
fn scalar_percent_repr(value : ScalarNumber) -> String raise @core.DataError {
  match value {
    NumpyFloat64(value) => "np.float64(" + named_format_float_repr(value) + ")"
    NumpyInt64(value) => "np.int64(" + value.to_string() + ")"
    NumpyBool(value) => if value { "np.True_" } else { "np.False_" }
    _ => scalar_percent_str(value)
  }
}

///|
fn scalar_percent_star(
  value : ScalarNumber,
  consumed : Bool,
  precision : Bool,
) -> Int64 raise @core.DataError {
  if consumed {
    raise @core.DataError::InvalidTicks(
      message="TypeError: not enough arguments for format string",
    )
  }
  let integer = match value {
    Integer(value) => value
    Boolean(value) => @bigint.BigInt::from_int(if value { 1 } else { 0 })
    _ => raise @core.DataError::InvalidTicks(message="TypeError: * wants int")
  }
  let lower = if precision { -2147483648L } else { -9223372036854775808L }
  let upper = if precision { 2147483647L } else { 9223372036854775807L }
  if integer < @bigint.BigInt::from_int64(lower) ||
    integer > @bigint.BigInt::from_int64(upper) {
    raise @core.DataError::InvalidTicks(
      message="OverflowError: Python int too large to convert to C " +
        (if precision { "int" } else { "ssize_t" }),
    )
  }
  integer.to_int64()
}
