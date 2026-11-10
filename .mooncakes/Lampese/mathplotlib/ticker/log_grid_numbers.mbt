///|
// The original algorithm mixes Python integers/floats and strong NumPy
// scalars. The origin affects promotion, wrapping and range's index protocol.
priv enum LogGridNumber {
  PythonInteger(@bigint.BigInt)
  NumpyInteger(Int64)
  NumpyUnsigned(UInt64)
  PythonFloat(Double)
  NumpyFloat(Double)
  Text
}

///|
fn log_grid_error(message : String) -> @core.DataError {
  @core.DataError::InvalidTicks(message~)
}

///|
fn log_grid_integer(value : Int32) -> LogGridNumber {
  PythonInteger(@bigint.BigInt::from_int(value))
}

///|
fn LogGridNumber::integer(
  self : LogGridNumber,
) -> @bigint.BigInt raise @core.DataError {
  match self {
    PythonInteger(value) => value
    NumpyInteger(value) => @bigint.BigInt::from_int64(value)
    NumpyUnsigned(value) => @bigint.BigInt::from_uint64(value)
    _ => raise log_grid_error("log grid requires an integer index")
  }
}

///|
fn log_grid_float_integer(
  value : @bigint.BigInt,
) -> Double raise @core.DataError {
  let result = index_round_binary(value, 0)
  if result.is_inf() {
    raise log_grid_error("log grid integer is too large to convert to float")
  }
  result
}

///|
fn LogGridNumber::floating(
  self : LogGridNumber,
) -> Double raise @core.DataError {
  match self {
    PythonInteger(value) => log_grid_float_integer(value)
    NumpyInteger(value) => value.to_double()
    NumpyUnsigned(value) =>
      index_round_binary(@bigint.BigInt::from_uint64(value), 0)
    PythonFloat(value) | NumpyFloat(value) => value
    Text =>
      raise log_grid_error(
        "log tick count text cannot participate in arithmetic",
      )
  }
}

///|
fn log_grid_kind(
  left : LogGridNumber,
  right : LogGridNumber,
) -> Int32 raise @core.DataError {
  if left is Text || right is Text {
    raise log_grid_error("log tick count text cannot participate in arithmetic")
  }
  if left is NumpyFloat(_) || right is NumpyFloat(_) {
    return 4
  }
  if left is PythonFloat(_) || right is PythonFloat(_) {
    if left is NumpyInteger(_) ||
      left is NumpyUnsigned(_) ||
      right is NumpyInteger(_) ||
      right is NumpyUnsigned(_) {
      return 4
    }
    return 3
  }
  if (left is NumpyInteger(_) && right is NumpyUnsigned(_)) ||
    (left is NumpyUnsigned(_) && right is NumpyInteger(_)) {
    return 4
  }
  if left is NumpyInteger(_) || right is NumpyInteger(_) {
    return 1
  }
  if left is NumpyUnsigned(_) || right is NumpyUnsigned(_) {
    return 2
  }
  0
}

///|
fn log_grid_checked_integer(
  value : LogGridNumber,
  unsigned : Bool,
) -> @bigint.BigInt raise @core.DataError {
  let integer = value.integer()
  let lower = if unsigned {
    @bigint.BigInt::from_int(0)
  } else {
    @bigint.BigInt::from_int64(-9223372036854775808L)
  }
  let upper = if unsigned {
    @bigint.BigInt::from_uint64(18446744073709551615UL)
  } else {
    @bigint.BigInt::from_int64(9223372036854775807L)
  }
  if integer < lower || integer > upper {
    raise log_grid_error(
      "log grid Python integer cannot be converted to the NumPy integer dtype",
    )
  }
  integer
}

///|
fn log_grid_wrap(value : @bigint.BigInt) -> UInt64 {
  let modulus = @bigint.BigInt::from_int(1) << 64
  let remainder = value % modulus
  (if remainder < @bigint.BigInt::from_int(0) {
    remainder + modulus
  } else {
    remainder
  }).to_uint64()
}

///|
fn log_grid_int_divmod(
  left : @bigint.BigInt,
  right : @bigint.BigInt,
) -> (@bigint.BigInt, @bigint.BigInt) {
  let quotient = left / right
  let remainder = left % right
  if !remainder.is_zero() &&
    (remainder < @bigint.BigInt::from_int(0)) !=
    (right < @bigint.BigInt::from_int(0)) {
    (quotient - @bigint.BigInt::from_int(1), remainder + right)
  } else {
    (quotient, remainder)
  }
}

///|
fn log_grid_float_divmod(left : Double, right : Double) -> (Double, Double) {
  let mut remainder = left % right
  let mut quotient = (left - remainder) / right
  if remainder != 0.0 {
    if (remainder < 0.0) != (right < 0.0) {
      remainder += right
      quotient -= 1.0
    }
  } else {
    remainder = if right.reinterpret_as_uint64() >> 63 == 0UL {
      0.0
    } else {
      -0.0
    }
  }
  let floor = if quotient != 0.0 {
    let floor = quotient.floor()
    if quotient - floor > 0.5 {
      floor + 1.0
    } else {
      floor
    }
  } else {
    let divided = left / right
    if divided.reinterpret_as_uint64() >> 63 == 0UL {
      0.0
    } else {
      -0.0
    }
  }
  (floor, remainder)
}

///|
// Operations: addition, subtraction, multiplication, floor division, remainder.
fn log_grid_op(
  left : LogGridNumber,
  right : LogGridNumber,
  operation : Int32,
) -> LogGridNumber raise @core.DataError {
  let kind = log_grid_kind(left, right)
  if kind <= 2 {
    let a = if kind == 0 {
      left.integer()
    } else {
      log_grid_checked_integer(left, kind == 2)
    }
    let b = if kind == 0 {
      right.integer()
    } else {
      log_grid_checked_integer(right, kind == 2)
    }
    let result = match operation {
      0 => a + b
      1 => a - b
      2 => a * b
      _ =>
        if b.is_zero() {
          if kind == 0 {
            raise log_grid_error("log grid integer division by zero")
          }
          @bigint.BigInt::from_int(0)
        } else {
          let (quotient, remainder) = log_grid_int_divmod(a, b)
          if operation == 3 {
            quotient
          } else {
            remainder
          }
        }
    }
    if kind == 1 {
      NumpyInteger(log_grid_wrap(result).reinterpret_as_int64())
    } else if kind == 2 {
      NumpyUnsigned(log_grid_wrap(result))
    } else {
      PythonInteger(result)
    }
  } else {
    let a = left.floating()
    let b = right.floating()
    if operation >= 3 && b == 0.0 && kind == 3 {
      raise log_grid_error("log grid float division by zero")
    }
    let value = match operation {
      0 => a + b
      1 => a - b
      2 => a * b
      3 => if b == 0.0 { a / b } else { log_grid_float_divmod(a, b).0 }
      _ => log_grid_float_divmod(a, b).1
    }
    if kind == 3 {
      PythonFloat(value)
    } else {
      NumpyFloat(value)
    }
  }
}

///|
// Correctly rounded Python integer true division need not convert either
// arbitrarily large operand to binary64 first.
fn log_grid_integer_ratio(
  numerator : @bigint.BigInt,
  denominator : @bigint.BigInt,
) -> Double raise @core.DataError {
  if denominator.is_zero() {
    raise log_grid_error("log grid true division by zero")
  }
  let zero = @bigint.BigInt::from_int(0)
  let negative = (numerator < zero) != (denominator < zero)
  let a = if numerator < zero { numerator.neg() } else { numerator }
  let b = if denominator < zero { denominator.neg() } else { denominator }
  if a.is_zero() {
    return if negative { -0.0 } else { 0.0 }
  }
  let mut exponent = a.bit_length() - b.bit_length()
  if (if exponent >= 0 { a < b << exponent } else { a << -exponent < b }) {
    exponent -= 1
  }
  let unit = Int32::max(exponent - 52, -1074)
  let a = if unit < 0 { a << -unit } else { a }
  let b = if unit > 0 { b << unit } else { b }
  let quotient = a / b
  let remainder = a % b
  let twice = remainder << 1
  let rounded = if twice > b ||
    (twice == b && (quotient.to_uint64() & 1UL) != 0UL) {
    quotient + @bigint.BigInt::from_int(1)
  } else {
    quotient
  }
  let value = index_round_binary(
    if negative {
      rounded.neg()
    } else {
      rounded
    },
    unit,
  )
  if value.is_inf() {
    raise log_grid_error("log grid integer ratio overflows float")
  }
  if value == 0.0 && negative {
    -0.0
  } else {
    value
  }
}

///|
fn log_grid_divide(
  left : LogGridNumber,
  right : LogGridNumber,
) -> LogGridNumber raise @core.DataError {
  let kind = log_grid_kind(left, right)
  if kind == 0 {
    return PythonFloat(log_grid_integer_ratio(left.integer(), right.integer()))
  }
  let a = left.floating()
  let b = right.floating()
  if kind == 3 && b == 0.0 {
    raise log_grid_error("log grid float division by zero")
  }
  let value = a / b
  if kind == 3 {
    PythonFloat(value)
  } else {
    NumpyFloat(value)
  }
}

///|
fn log_grid_ceil(value : LogGridNumber) -> LogGridNumber raise @core.DataError {
  match value {
    PythonInteger(_) | NumpyInteger(_) | NumpyUnsigned(_) =>
      PythonInteger(value.integer())
    _ => PythonInteger(auto_minor_round(value.floating().ceil()))
  }
}

///|
fn log_grid_compare_integer_float(
  integer : @bigint.BigInt,
  floating : Double,
) -> Int32? {
  if floating.is_nan() {
    return None
  }
  if floating.is_inf() {
    return Some(if floating < 0.0 { 1 } else { -1 })
  }
  let (mantissa, exponent) = index_binary_parts(floating)
  let a = if exponent < 0 { integer << -exponent } else { integer }
  let b = if exponent > 0 { mantissa << exponent } else { mantissa }
  Some(if a < b { -1 } else if a > b { 1 } else { 0 })
}

///|
fn log_grid_compare(
  left : LogGridNumber,
  right : LogGridNumber,
) -> Int32? raise @core.DataError {
  if left is Text || right is Text {
    raise log_grid_error("log grid text is not ordered with numbers")
  }
  let left_float = left is PythonFloat(_) || left is NumpyFloat(_)
  let right_float = right is PythonFloat(_) || right is NumpyFloat(_)
  if !left_float && !right_float {
    let a = left.integer()
    let b = right.integer()
    return Some(if a < b { -1 } else if a > b { 1 } else { 0 })
  }
  if left is PythonInteger(integer) && right is PythonFloat(value) {
    return log_grid_compare_integer_float(integer, value)
  }
  if left is PythonFloat(value) && right is PythonInteger(integer) {
    return log_grid_compare_integer_float(integer, value).map(result => -result)
  }
  let a = left.floating()
  let b = right.floating()
  if a.is_nan() || b.is_nan() {
    return None
  }
  Some(if a < b { -1 } else if a > b { 1 } else { 0 })
}

///|
fn log_grid_max(
  left : LogGridNumber,
  right : LogGridNumber,
) -> LogGridNumber raise @core.DataError {
  if log_grid_compare(left, right) is Some(-1) {
    right
  } else {
    left
  }
}

///|
fn log_grid_min(
  left : LogGridNumber,
  right : LogGridNumber,
) -> LogGridNumber raise @core.DataError {
  if log_grid_compare(left, right) is Some(1) {
    right
  } else {
    left
  }
}

///|
fn log_grid_space(value : LogTickSpace) -> LogGridNumber {
  match value {
    Number(value) =>
      NumpyFloat(
        if value < 2.0 {
          2.0
        } else if value > 9.0 {
          9.0
        } else {
          value
        },
      )
    Integer(value) => {
      let clipped = if value < @bigint.BigInt::from_int(2) {
        2
      } else if value > @bigint.BigInt::from_int(9) {
        9
      } else {
        value.to_int()
      }
      if value >= @bigint.BigInt::from_int64(-9223372036854775808L) &&
        value <= @bigint.BigInt::from_int64(9223372036854775807L) {
        NumpyInteger(clipped.to_int64())
      } else if value >= @bigint.BigInt::from_int(0) &&
        value <= @bigint.BigInt::from_uint64(18446744073709551615UL) {
        NumpyUnsigned(clipped.to_uint64())
      } else {
        log_grid_integer(clipped)
      }
    }
  }
}
