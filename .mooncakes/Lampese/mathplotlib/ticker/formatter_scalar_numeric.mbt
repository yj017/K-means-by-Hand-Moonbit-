///|
fn scalar_named_call(
  base : BaseFormatter,
  state : ScalarFormatterState,
  value : ScalarNumber,
  _pos : Int32?,
) -> String raise @core.DataError {
  if base.locations.length() == 0 {
    return ""
  }
  let difference = scalar_numeric_sub_offset(value, state.offset)
  let power = scalar_math_power10(state.order, float_base=true)
  let scaled = scalar_numeric_op(difference, power, 3)
  let scaled = if scalar_numeric_less(
      scalar_numeric_abs(scaled),
      ScalarNumber::Number(1.0e-8),
    ) {
    ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  } else {
    scaled
  }
  scalar_named_format(
    state.format_pattern,
    scaled,
    state.use_locale,
    state.use_math_text,
  )
}

///|
fn scalar_named_format_data(
  state : ScalarFormatterState,
  value : ScalarNumber,
) -> String raise @core.DataError {
  let exponent = scalar_numeric_floor(
    scalar_math_log10(scalar_numeric_abs(value)),
  )
  let power = scalar_math_power10(
    ScalarNumber::Integer(exponent),
    float_base=false,
  )
  let significand = scalar_math_round_ten(scalar_numeric_op(value, power, 3))
  let number = scalar_numeric_double(significand)
  let integral = !number.is_nan() &&
    !number.is_inf() &&
    number.floor() == number
  let text = scalar_named_format(
    if integral {
      "%d"
    } else {
      "%1.10g"
    },
    significand,
    state.use_locale,
    state.use_math_text,
  )
  if exponent.is_zero() {
    return text
  }
  let exponent_text = scalar_named_format(
    "%d",
    ScalarNumber::Integer(exponent),
    state.use_locale,
    state.use_math_text,
  )
  if state.use_math_text || state.usetex {
    let power_text = "10^{" + exponent_text + "}"
    if number == 1.0 {
      power_text
    } else {
      text + " \\times " + power_text
    }
  } else {
    text + "e" + exponent_text
  }
}

///|
fn scalar_named_offset(
  base : BaseFormatter,
  state : ScalarFormatterState,
) -> String raise @core.DataError {
  if base.locations.length() == 0 {
    return ""
  }
  if !scalar_numeric_truth(Some(state.order)) &&
    !scalar_numeric_truth(state.offset) {
    return ""
  }
  let mut offset = ""
  let mut scientific = ""
  if scalar_numeric_truth(state.offset) {
    let value = state.offset.unwrap()
    offset = scalar_named_format_data(state, value)
    if scalar_numeric_less(
        ScalarNumber::Integer(@bigint.BigInt::from_int(0)),
        value,
      ) {
      offset = "+" + offset
    }
  }
  if scalar_numeric_truth(Some(state.order)) {
    scientific = if state.usetex || state.use_math_text {
      scalar_named_format_data(
        state,
        scalar_math_power10(state.order, float_base=false),
      )
    } else {
      scalar_percent_format("1e%d", state.order)
    }
  }
  let text = if state.use_math_text || state.usetex {
    if scientific != "" {
      scientific = "\\times\\mathdefault{" + scientific + "}"
    }
    "$" + scientific + "\\mathdefault{" + offset + "}$"
  } else {
    scientific + offset
  }
  BaseFormatter::fix_minus(text)
}

///|
fn scalar_named_short(
  base : BaseFormatter,
  state : ScalarFormatterState,
  value : ScalarNumber,
) -> String raise @core.DataError {
  if value is (Integer(_) | Boolean(_) | NumpyInt64(_)) {
    return scalar_named_format(
      "%d",
      value,
      state.use_locale,
      state.use_math_text,
    )
  }
  let number = scalar_numeric_double(value)
  let physical = match base.axis {
    Some(axis) => axis.short_format_delta(number)
    None => None
  }
  let mut delta = match physical {
    Some(delta) => delta
    None => {
      let (a, b) = scalar_numeric_view(base)
      scalar_numeric_double(
        scalar_numeric_op(
          scalar_numeric_op(b, a, 1),
          ScalarNumber::Number(1.0e4),
          3,
        ),
      )
    }
  }
  let precision = if number.is_nan() || number.is_inf() {
    @bigint.BigInt::from_int(0)
  } else if delta == 0.0 && number == 0.0 {
    @bigint.BigInt::from_int(3)
  } else {
    if delta == 0.0 {
      delta = Double::abs(scalar_math_spacing(value))
    }
    let before = if number != 0.0 {
      scalar_numeric_floor(
        scalar_math_log10(ScalarNumber::Number(Double::abs(number))),
      ) +
      @bigint.BigInt::from_int(1)
    } else {
      @bigint.BigInt::from_int(1)
    }
    let after = scalar_numeric_floor(
      scalar_math_log10(ScalarNumber::Number(delta)),
    )
    let result = before - after
    if result < @bigint.BigInt::from_int(0) {
      @bigint.BigInt::from_int(0)
    } else {
      result
    }
  }
  scalar_named_format(
    "%-#." + precision.to_string() + "g",
    value,
    state.use_locale,
    state.use_math_text,
  )
}
