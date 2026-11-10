///|
fn logit_wrap_math(text : String) -> String raise @core.DataError {
  let prefix = "$\\mathdefault{"
  let suffix = "}$"
  if Int64::from_int(prefix.length()) +
    Int64::from_int(text.length()) +
    Int64::from_int(suffix.length()) >
    2147483647L {
    raise log_format_error(
      "ResourceError: LogitFormatter label exceeds String addressability",
    )
  }
  prefix + text + suffix
}

///|
fn logit_one_minus(state : LogitFormatterState, text : String) -> String {
  if log_value_truth(state.use_overline) {
    "\\overline{" + text + "}"
  } else {
    "1-" + text
  }
}

///|
fn logit_format_value(
  value : ScalarNumber,
  locations : FormatterLocations,
  scientific~ : Bool,
) -> String raise @core.DataError {
  let exponent = if scientific {
    scalar_numeric_floor(asinh_math_log10(scalar_numeric_double(value)))
  } else {
    @bigint.BigInt::from_int(0)
  }
  let minimum = if scientific {
    @bigint.BigInt::from_int(0)
  } else {
    @bigint.BigInt::from_int(1)
  }
  // Python int-base exponentiation is exact before multiplication's scalar
  // conversion. This can fail for tiny x before the locations length is read.
  let power = scalar_math_power10(
    ScalarNumber::Integer(exponent.neg()),
    float_base=false,
  )
  let scaled = scalar_numeric_op(value, power, 2)
  let mut precision = minimum
  if locations.length() >= 2 {
    let diff = logit_array_second_distance(locations, value)
    let raw = -asinh_math_log10(diff) + index_round_binary(exponent, 0)
    precision = if log_format_close(raw) {
      log_format_round(scalar_math_rint(raw))
    } else {
      scalar_numeric_floor(raw.ceil())
    }
    if precision < minimum {
      precision = minimum
    }
  }
  // A public binary64 probability has a binary64 second distance. Its decimal
  // precision is bounded by that finite range (<=324), after the source's
  // nonfinite errors above; no arbitrary precision cap is introduced here.
  let mantissa = named_format_float_digits(
    scalar_numeric_double(scaled),
    'f',
    Some(precision.to_int()),
    false,
  )
  if scientific {
    mantissa + "\\cdot10^{" + scalar_percent_integer_str(exponent) + "}"
  } else {
    mantissa
  }
}

///|
fn logit_named_call(
  base : BaseFormatter,
  state : LogitFormatterState,
  key : LogitKey,
  _pos : Int32?,
) -> String raise @core.DataError {
  if log_value_truth(state.minor) && !state.labelled.contains(key) {
    return ""
  }
  let value = key.value()
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  let one = ScalarNumber::Integer(@bigint.BigInt::from_int(1))
  let at_zero = eng_prefix_compare(value, zero)
  if at_zero is Some(comparison) && comparison <= 0 {
    return ""
  }
  let at_one = eng_prefix_compare(value, one)
  if at_one is Some(comparison) && comparison >= 0 {
    return ""
  }
  let text = if logit_is_half(value, numpy_round=false) {
    match state.one_half {
      Text(text) => text
      NoneValue => "None"
      Numeric(number) => scalar_percent_format("%s", number)
    }
  } else if eng_prefix_less(value, ScalarNumber::Number(0.5)) &&
    logit_is_decade(value) {
    "10^{" +
    scalar_percent_integer_str(log_format_round(scalar_math_log10(value))) +
    "}"
  } else if eng_prefix_less(ScalarNumber::Number(0.5), value) &&
    logit_is_decade(scalar_numeric_op(one, value, 1)) {
    let complement = scalar_numeric_op(one, value, 1)
    logit_one_minus(
      state,
      "10^{" +
      scalar_percent_integer_str(
        log_format_round(scalar_math_log10(complement)),
      ) +
      "}",
    )
  } else if eng_prefix_less(value, ScalarNumber::Number(0.1)) {
    logit_format_value(value, base.locations, scientific=true)
  } else if eng_prefix_less(ScalarNumber::Number(0.9), value) {
    let complement = scalar_numeric_op(one, value, 1)
    let locations = logit_array_complement(base.locations)
    logit_one_minus(
      state,
      logit_format_value(complement, locations, scientific=true),
    )
  } else {
    logit_format_value(value, base.locations, scientific=false)
  }
  logit_wrap_math(text)
}

///|
fn logit_named_short(value : ScalarNumber) -> String raise @core.DataError {
  if eng_prefix_less(value, ScalarNumber::Number(0.1)) {
    method_format_float(
      scalar_numeric_double(value),
      method_parse_spec("e", "float"),
    )
  } else if eng_prefix_less(value, ScalarNumber::Number(0.9)) {
    method_format_float(
      scalar_numeric_double(value),
      method_parse_spec("f", "float"),
    )
  } else {
    let complement = scalar_numeric_op(
      ScalarNumber::Integer(@bigint.BigInt::from_int(1)),
      value,
      1,
    )
    "1-" +
    method_format_float(
      scalar_numeric_double(complement),
      method_parse_spec("e", "float"),
    )
  }
}
