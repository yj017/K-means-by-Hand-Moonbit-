///|
fn scalar_numeric_integer(
  value : ScalarNumber,
) -> @bigint.BigInt raise @core.DataError {
  match value {
    Integer(value) => value
    Boolean(value) | NumpyBool(value) =>
      @bigint.BigInt::from_int(if value { 1 } else { 0 })
    NumpyInt64(value) => @bigint.BigInt::from_int64(value)
    Number(value) | NumpyFloat64(value) => {
      if value.is_nan() {
        raise @core.DataError::InvalidTicks(
          message="ValueError: cannot convert float NaN to integer",
        )
      }
      if value.is_inf() {
        raise @core.DataError::InvalidTicks(
          message="OverflowError: cannot convert float infinity to integer",
        )
      }
      let (n, d) = decimal_ratio(value)
      if value < 0.0 {
        (n / d).neg()
      } else {
        n / d
      }
    }
  }
}

///|
fn scalar_numeric_double(value : ScalarNumber) -> Double raise @core.DataError {
  match value {
    Number(value) | NumpyFloat64(value) => value
    Integer(value) => percent_python_integer_double(value)
    NumpyInt64(value) => value.to_double()
    Boolean(value) | NumpyBool(value) => if value { 1.0 } else { 0.0 }
  }
}

///|
fn scalar_numeric_numpy(value : ScalarNumber) -> Bool {
  value is (NumpyFloat64(_) | NumpyInt64(_) | NumpyBool(_))
}

///|
fn scalar_numeric_integral(value : ScalarNumber) -> Bool {
  !(value is (Number(_) | NumpyFloat64(_)))
}

///|
fn scalar_numeric_truth(value : ScalarNumber?) -> Bool {
  match value {
    None => false
    Some(Integer(value)) => !value.is_zero()
    Some(Boolean(value) | NumpyBool(value)) => value
    Some(NumpyInt64(value)) => value != 0L
    Some(Number(value) | NumpyFloat64(value)) => value != 0.0
  }
}

///|
fn scalar_numeric_int64(value : ScalarNumber) -> Int64 raise @core.DataError {
  let value = scalar_numeric_integer(value)
  if value < @bigint.BigInt::from_int64(-9223372036854775808L) ||
    value > @bigint.BigInt::from_int64(9223372036854775807L) {
    raise @core.DataError::InvalidTicks(
      message="OverflowError: Python int too large to convert to C long",
    )
  }
  value.to_int64()
}

///|
// Operation order and scalar origin follow Python/NumPy, not a universal cast.
// op0 addition, op1 subtraction, op2 multiplication, op3 true division.
fn scalar_numeric_op(
  left : ScalarNumber,
  right : ScalarNumber,
  op : Int32,
) -> ScalarNumber raise @core.DataError {
  let numpy = scalar_numeric_numpy(left) || scalar_numeric_numpy(right)
  let integral = scalar_numeric_integral(left) && scalar_numeric_integral(right)
  if op == 3 && integral && !numpy {
    let a = scalar_numeric_integer(left)
    let b = scalar_numeric_integer(right)
    if b.is_zero() {
      raise @core.DataError::InvalidTicks(
        message="ZeroDivisionError: division by zero",
      )
    }
    let result = log_grid_integer_ratio(a, b) catch {
      @core.DataError::InvalidTicks(
        message="log grid integer ratio overflows float"
      ) =>
        raise @core.DataError::InvalidTicks(
          message="OverflowError: integer division result too large for a float",
        )
      error => raise error
    }
    return ScalarNumber::Number(result)
  }
  if op != 3 && integral {
    if numpy {
      let boolean = left is (Boolean(_) | NumpyBool(_)) &&
        right is (Boolean(_) | NumpyBool(_))
      if boolean {
        if op == 1 {
          raise @core.DataError::InvalidTicks(
            message="TypeError: numpy boolean subtract, the `-` operator, is not supported, use the bitwise_xor, the `^` operator, or the logical_xor function instead.",
          )
        }
        let a = scalar_numeric_truth(Some(left))
        let b = scalar_numeric_truth(Some(right))
        return ScalarNumber::NumpyBool(if op == 0 { a || b } else { a && b })
      }
      let a = scalar_numeric_int64(left).reinterpret_as_uint64()
      let b = scalar_numeric_int64(right).reinterpret_as_uint64()
      return ScalarNumber::NumpyInt64(
        (if op == 0 { a + b } else if op == 1 { a - b } else { a * b }).reinterpret_as_int64(),
      )
    }
    let a = scalar_numeric_integer(left)
    let b = scalar_numeric_integer(right)
    return ScalarNumber::Integer(
      if op == 0 {
        a + b
      } else if op == 1 {
        a - b
      } else {
        a * b
      },
    )
  }
  let a = scalar_numeric_double(left)
  let b = scalar_numeric_double(right)
  if op == 3 && b == 0.0 && !numpy {
    raise @core.DataError::InvalidTicks(
      message="ZeroDivisionError: float division by zero",
    )
  }
  let result = if op == 0 {
    a + b
  } else if op == 1 {
    a - b
  } else if op == 2 {
    a * b
  } else {
    a / b
  }
  if numpy {
    ScalarNumber::NumpyFloat64(result)
  } else {
    ScalarNumber::Number(result)
  }
}

///|
fn scalar_numeric_sub_offset(
  left : ScalarNumber,
  offset : ScalarNumber?,
) -> ScalarNumber raise @core.DataError {
  match offset {
    Some(offset) => scalar_numeric_op(left, offset, 1)
    None => {
      let name = match left {
        Number(_) | NumpyFloat64(_) => "float"
        Boolean(_) | NumpyBool(_) => "bool"
        _ => "int"
      }
      raise @core.DataError::InvalidTicks(
        message="TypeError: unsupported operand type(s) for -: '" +
          name +
          "' and 'NoneType'",
      )
    }
  }
}

///|
fn scalar_numeric_abs(value : ScalarNumber) -> ScalarNumber {
  match value {
    Number(value) => ScalarNumber::Number(Double::abs(value))
    NumpyFloat64(value) => ScalarNumber::NumpyFloat64(Double::abs(value))
    Integer(value) =>
      ScalarNumber::Integer(
        if value < @bigint.BigInt::from_int(0) {
          value.neg()
        } else {
          value
        },
      )
    Boolean(value) =>
      ScalarNumber::Integer(@bigint.BigInt::from_int(if value { 1 } else { 0 }))
    NumpyBool(value) => ScalarNumber::NumpyBool(value)
    NumpyInt64(value) =>
      ScalarNumber::NumpyInt64(
        if value < 0L {
          (0UL - value.reinterpret_as_uint64()).reinterpret_as_int64()
        } else {
          value
        },
      )
  }
}

///|
fn scalar_numeric_compare(
  left : ScalarNumber,
  right : ScalarNumber,
) -> Int32? raise @core.DataError {
  let a_integral = scalar_numeric_integral(left)
  let b_integral = scalar_numeric_integral(right)
  if a_integral && b_integral {
    let a = scalar_numeric_integer(left)
    let b = scalar_numeric_integer(right)
    return Some(if a < b { -1 } else if a > b { 1 } else { 0 })
  }
  if !scalar_numeric_numpy(left) && !scalar_numeric_numpy(right) {
    if a_integral {
      return log_grid_compare_integer_float(
        scalar_numeric_integer(left),
        scalar_numeric_double(right),
      )
    }
    if b_integral {
      return log_grid_compare_integer_float(
        scalar_numeric_integer(right),
        scalar_numeric_double(left),
      ).map(value => -value)
    }
  }
  let a = scalar_numeric_double(left)
  let b = scalar_numeric_double(right)
  if a.is_nan() || b.is_nan() {
    None
  } else {
    Some(if a < b { -1 } else if a > b { 1 } else { 0 })
  }
}

///|
fn scalar_numeric_less(
  left : ScalarNumber,
  right : ScalarNumber,
) -> Bool raise @core.DataError {
  scalar_numeric_compare(left, right) == Some(-1)
}

///|
fn scalar_numeric_equal(
  left : ScalarNumber,
  right : ScalarNumber,
) -> Bool raise @core.DataError {
  scalar_numeric_compare(left, right) == Some(0)
}

///|
fn scalar_numeric_floor(value : Double) -> @bigint.BigInt raise @core.DataError {
  if value.is_nan() {
    raise @core.DataError::InvalidTicks(
      message="ValueError: cannot convert float NaN to integer",
    )
  }
  if value.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="OverflowError: cannot convert float infinity to integer",
    )
  }
  auto_minor_round(value.floor())
}

///|
fn scalar_numeric_float_floor_divide(left : Double, right : Double) -> Double {
  if right == 0.0 {
    left / right
  } else {
    log_grid_float_divmod(left, right).0
  }
}

///|
fn scalar_numeric_location(
  locations : FormatterLocations,
  index : Int32,
) -> ScalarNumber raise @core.DataError {
  match locations {
    Sequence(values) => ScalarNumber::NumpyFloat64(values[index])
    Integers(values) =>
      LogitInput::from_keys(
        values.map(value => LogitKey::new(ScalarNumber::Integer(value))),
      )
      .snapshot()
      .get_value(index)
    NdArray(values) =>
      if values.is_int64() {
        ScalarNumber::NumpyInt64(values.get_int64(index))
      } else {
        ScalarNumber::NumpyFloat64(values.get(index))
      }
    Typed(values) => values.get_value(index)
  }
}

///|
fn scalar_numeric_view(
  base : BaseFormatter,
  sort~ : Bool = false,
) -> (ScalarNumber, ScalarNumber) raise @core.DataError {
  let view = match base.axis {
    Some(axis) => axis.view_interval()
    None =>
      raise @core.DataError::InvalidTicks(
        message="AttributeError: 'NoneType' object has no attribute 'get_view_interval'",
      )
  }
  let length = view.length()
  if length < 2 {
    raise @core.DataError::InvalidTicks(
      message="ValueError: not enough values to unpack (expected 2, got " +
        length.to_string() +
        ")",
    )
  }
  if length > 2 {
    raise @core.DataError::InvalidTicks(
      message="ValueError: too many values to unpack (expected 2)",
    )
  }
  let (a, b) = match view {
    Sequence(values) =>
      (ScalarNumber::Number(values[0]), ScalarNumber::Number(values[1]))
    Integers(values) =>
      (ScalarNumber::Integer(values[0]), ScalarNumber::Integer(values[1]))
    NdArray(values) =>
      if values.is_int64() {
        (
          ScalarNumber::NumpyInt64(values.get_int64(0)),
          ScalarNumber::NumpyInt64(values.get_int64(1)),
        )
      } else {
        (
          ScalarNumber::NumpyFloat64(values.get(0)),
          ScalarNumber::NumpyFloat64(values.get(1)),
        )
      }
  }
  if sort && scalar_numeric_less(b, a) {
    (b, a)
  } else {
    (a, b)
  }
}
