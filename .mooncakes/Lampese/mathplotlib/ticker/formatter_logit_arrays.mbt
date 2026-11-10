///|
// Evaluate the original ndarray complement before entering _format_value.
// The fresh inherited locations container is a Python list, not an ndarray.
fn logit_array_complement(
  locations : FormatterLocations,
) -> FormatterLocations raise @core.DataError {
  match locations {
    Sequence(_) | Integers(_) =>
      raise log_format_error(
        "TypeError: unsupported operand type(s) for -: 'int' and 'list'",
      )
    NdArray(values) =>
      if values.is_int64() {
        let result : Array[Int64] = []
        for index in 0..<values.length() {
          result.push(
            (1UL - values.get_int64(index).reinterpret_as_uint64()).reinterpret_as_int64(),
          )
        }
        FormatterLocations::NdArray(TickValues::from_int64_array(result))
      } else {
        let result : Array[Double] = []
        for index in 0..<values.length() {
          result.push(1.0 - values.get(index))
        }
        FormatterLocations::NdArray(TickValues::from_array(result))
      }
    Typed(array) =>
      match array.storage {
        Boolean(values) =>
          FormatterLocations::NdArray(
            TickValues::from_int64_array(
              values.map(value => if value { 0L } else { 1L }),
            ),
          )
        Unsigned64(values) =>
          FormatterLocations::Typed({
            storage: NumericArrayStorage::Unsigned64(
              values.map(value => 1UL - value),
            ),
          })
        Objects(values) => {
          let result : Array[ScalarNumber] = []
          for value in values {
            result.push(
              scalar_numeric_op(
                ScalarNumber::Integer(@bigint.BigInt::from_int(1)),
                value,
                1,
              ),
            )
          }
          FormatterLocations::Typed({
            storage: NumericArrayStorage::Objects(result),
          })
        }
      }
  }
}

///|
fn logit_array_second_distance(
  locations : FormatterLocations,
  value : ScalarNumber,
) -> Double raise @core.DataError {
  let x = scalar_numeric_double(value)
  let distances : Array[Double] = []
  match locations {
    Sequence(values) => {
      if !scalar_numeric_numpy(value) {
        raise log_format_error(
          "TypeError: unsupported operand type(s) for -: 'list' and 'float'",
        )
      }
      for other in values {
        distances.push(Double::abs(other - x))
      }
    }
    Integers(values) => {
      if !scalar_numeric_numpy(value) {
        let kind = if value is Integer(_) { "int" } else { "float" }
        raise log_format_error(
          "TypeError: unsupported operand type(s) for -: 'list' and '" +
          kind +
          "'",
        )
      }
      let input = LogitInput::from_keys(
        values.map(value => LogitKey::new(ScalarNumber::Integer(value))),
      ).snapshot()
      for index in 0..<input.length() {
        distances.push(Double::abs(input.get(index) - x))
      }
    }
    NdArray(values) =>
      for index in 0..<values.length() {
        distances.push(Double::abs(values.get(index) - x))
      }
    Typed(array) =>
      match array.storage {
        Boolean(values) =>
          for other in values {
            distances.push(Double::abs((if other { 1.0 } else { 0.0 }) - x))
          }
        Unsigned64(values) =>
          for other in values {
            distances.push(Double::abs(other.to_double() - x))
          }
        Objects(values) => {
          // Object ufunc loops complete subtraction before the absolute pass.
          // A floating ufunc scalar is boxed as a Python float in this loop.
          let subtracted : Array[ScalarNumber] = []
          for other in values {
            subtracted.push(
              scalar_numeric_op(other, ScalarNumber::Number(x), 1),
            )
          }
          let absolute : Array[ScalarNumber] = subtracted.map(
            scalar_numeric_abs,
          )
          // Object quicksort uses partial Python comparison, including NaNs.
          // Its second rank is not the numeric NaN-last rank below.
          let sorted = logit_object_sort(absolute)
          return scalar_numeric_double(sorted[1])
        }
      }
  }
  // np.sort places NaNs after numeric values. Only the second rank is needed;
  // consume every arithmetic result before this scan, preserving late errors.
  let mut first = 0.0 / 0.0
  let mut second = 0.0 / 0.0
  for distance in distances {
    if !distance.is_nan() {
      if first.is_nan() || distance < first {
        second = first
        first = distance
      } else if second.is_nan() || distance < second {
        second = distance
      }
    }
  }
  second
}

///|
fn logit_array_logits(
  locations : FormatterLocations,
) -> Array[Double] raise @core.DataError {
  let values : Array[Double] = []
  match locations {
    Sequence(_) | Integers(_) =>
      raise log_format_error(
        "TypeError: unsupported operand type(s) for /: 'int' and 'list'",
      )
    NdArray(array) =>
      for index in 0..<array.length() {
        values.push(array.get(index))
      }
    Typed(array) =>
      match array.storage {
        Boolean(array) =>
          for value in array {
            values.push(if value { 1.0 } else { 0.0 })
          }
        Unsigned64(array) =>
          for value in array {
            values.push(value.to_double())
          }
        Objects(array) => {
          let reciprocals : Array[ScalarNumber] = []
          for value in array {
            reciprocals.push(
              scalar_numeric_op(
                ScalarNumber::Integer(@bigint.BigInt::from_int(1)),
                value,
                3,
              ),
            )
          }
          let arguments : Array[ScalarNumber] = []
          for value in reciprocals {
            arguments.push(
              scalar_numeric_op(
                value,
                ScalarNumber::Integer(@bigint.BigInt::from_int(1)),
                1,
              ),
            )
          }
          if arguments.length() > 0 {
            let name = if scalar_numeric_numpy(arguments[0]) {
              "numpy.float64"
            } else {
              "float"
            }
            raise log_format_error(
              "TypeError: loop of ufunc does not support argument 0 of type " +
              name +
              " which has no callable log method",
            )
          }
          return []
        }
      }
  }
  // Preserve reciprocal, subtract, NumPy ln, unary negative as separate rounded
  // operations. A stable analytic logit transform has different source behavior.
  let reciprocals = values.map(value => 1.0 / value)
  let arguments = reciprocals.map(value => value - 1.0)
  let logs = arguments.map(log_grid_natural_log)
  logs.map(value => -value)
}
