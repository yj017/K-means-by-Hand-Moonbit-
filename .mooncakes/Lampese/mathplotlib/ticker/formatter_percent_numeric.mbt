///|
fn percent_python_integer_double(
  value : @bigint.BigInt,
) -> Double raise @core.DataError {
  let number = index_round_binary(value, 0)
  if number.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="OverflowError: int too large to convert to float",
    )
  }
  number
}

///|
// Only construction evaluates the original xmax + 0.0 operation.
fn percent_xmax_normalize(
  value : PercentXMax,
) -> PercentXMax raise @core.DataError {
  match value {
    Number(number) =>
      PercentXMax::Number(if number == 0.0 { 0.0 } else { number + 0.0 })
    Integer(integer) =>
      PercentXMax::Number(percent_python_integer_double(integer) + 0.0)
    Boolean(boolean) => PercentXMax::Number(if boolean { 1.0 } else { 0.0 })
    NumpyFloat64(number) =>
      PercentXMax::NumpyFloat64(if number == 0.0 { 0.0 } else { number + 0.0 })
    NumpyInt64(number) => PercentXMax::NumpyFloat64(number.to_double() + 0.0)
  }
}

///|
// Scalar origin is needed at zero even though all successful quotients are
// binary64. Keep the source division and following multiplication separate.
fn percent_convert_to_pct(
  xmax : PercentXMax,
  value : NamedFormatValue,
) -> Double raise @core.DataError {
  if value is PythonInteger(integer) {
    // Integer true division can be finite even when neither operand fits a
    // Double. For floating xmax the helper converts the numerator first, just
    // as Python does before checking floating zero division.
    return percent_integer_range_to_pct(xmax, integer)
  }
  let denominator = match xmax {
    Number(number) | NumpyFloat64(number) => number
    Integer(integer) => percent_python_integer_double(integer)
    Boolean(boolean) => if boolean { 1.0 } else { 0.0 }
    NumpyInt64(number) => number.to_double()
  }
  let numpy = !(value is (PythonFloat(_) | PythonInteger(_))) ||
    xmax is (PercentXMax::NumpyFloat64(_) | PercentXMax::NumpyInt64(_))
  if denominator == 0.0 && !numpy {
    raise @core.DataError::InvalidTicks(
      message="ZeroDivisionError: float division by zero",
    )
  }
  let quotient = named_format_value_double(value) / denominator
  100.0 * quotient
}

///|
fn percent_auto_decimals(
  xmax : PercentXMax,
  display_range : PercentDisplayRange,
) -> Int32 raise @core.DataError {
  let scaled = match display_range {
    Scalar(value) => percent_convert_to_pct(xmax, value)
    PythonInteger(value) => percent_integer_range_to_pct(xmax, value)
  }
  if scaled <= 0.0 {
    return 0
  }
  // Preserve every source rounding, including overflow in the factor of two.
  let exponent = 2.0 - asinh_math_log10(2.0 * scaled)
  if exponent.is_nan() {
    raise @core.DataError::InvalidTicks(
      message="ValueError: cannot convert float NaN to integer",
    )
  }
  if exponent.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="OverflowError: cannot convert float infinity to integer",
    )
  }
  Int32::max(0, Int32::min(5, exponent.ceil().to_int()))
}

///|
// Escaping only adds one unit per ORIGINAL reserved ASCII character. Checking
// this size reserves symbol space without materializing an oversized symbol.
fn percent_symbol_units(state : PercentFormatterState) -> Int64 {
  let symbol = state.symbol.unwrap_or("")
  let mut units = Int64::from_int(symbol.length())
  if !state.is_latex && @config.text_usetex() {
    for character in symbol {
      if character
        is ('\\' | '#' | '$' | '%' | '&' | '~' | '_' | '^' | '{' | '}') {
        units += 1L
      }
    }
  }
  units
}

///|
fn percent_format_pct(
  state : PercentFormatterState,
  value : NamedFormatValue,
  display_range : NamedFormatValue,
) -> String raise @core.DataError {
  percent_format_pct_with_range(
    state,
    value,
    PercentDisplayRange::Scalar(display_range),
  )
}

///|
priv enum PercentDisplayRange {
  Scalar(NamedFormatValue)
  PythonInteger(@bigint.BigInt)
}

///|
// Python integer values and axis intervals retain integer true division with a
// raw Integer/Boolean xmax. Huge operands can have a finite quotient without
// either operand being representable as a Double.
fn percent_integer_range_to_pct(
  xmax : PercentXMax,
  numerator : @bigint.BigInt,
) -> Double raise @core.DataError {
  let denominator = match xmax {
    Integer(integer) => Some(integer)
    Boolean(boolean) =>
      Some(@bigint.BigInt::from_int(if boolean { 1 } else { 0 }))
    _ => None
  }
  match denominator {
    None =>
      percent_convert_to_pct(
        xmax,
        PythonFloat(percent_python_integer_double(numerator)),
      )
    Some(denominator) => {
      if denominator.is_zero() {
        raise @core.DataError::InvalidTicks(
          message="ZeroDivisionError: division by zero",
        )
      }
      let quotient = log_grid_integer_ratio(numerator, denominator) catch {
        @core.DataError::InvalidTicks(
          message="log grid integer ratio overflows float"
        ) =>
          raise @core.DataError::InvalidTicks(
            message="OverflowError: integer division result too large for a float",
          )
        error => raise error
      }
      100.0 * quotient
    }
  }
}

///|
fn percent_format_pct_with_range(
  state : PercentFormatterState,
  value : NamedFormatValue,
  display_range : PercentDisplayRange,
) -> String raise @core.DataError {
  let converted = percent_convert_to_pct(state.xmax, value)
  let decimals = match state.decimals {
    Automatic => percent_auto_decimals(state.xmax, display_range)
    explicit => percent_explicit_decimals(explicit)
  }
  // Source precision conversion/grammar errors precede symbol handling. The
  // symbol getter is pure in this typed model; reserve its exact size only now.
  let symbol_units = percent_symbol_units(state)
  let number = named_format_float_digits(
    converted,
    'f',
    Some(decimals),
    false,
    available=2147483647L - symbol_units,
  )
  number + percent_symbol(state)
}
