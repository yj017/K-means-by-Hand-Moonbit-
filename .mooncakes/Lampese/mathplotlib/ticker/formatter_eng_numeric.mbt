///|
fn eng_numeric_prefix_bound(
  state : EngFormatterState,
  maximum~ : Bool,
) -> ScalarNumber raise @core.DataError {
  let keys = eng_state_prefixes(state).keys()
  if keys.is_empty() {
    raise @core.DataError::InvalidTicks(
      message=if maximum {
        "ValueError: max() iterable argument is empty"
      } else {
        "ValueError: min() iterable argument is empty"
      },
    )
  }
  let mut bound = keys[0].value()
  for index in 1..<keys.length() {
    let value = keys[index].value()
    if (if maximum {
        eng_prefix_less(bound, value)
      } else {
        eng_prefix_less(value, bound)
      }) {
      bound = value
    }
  }
  bound
}

///|
fn eng_named_format_data(
  state : EngFormatterState,
  value : ScalarNumber,
) -> String raise @core.DataError {
  let format = eng_places_format(state.places)
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  let mut value = value
  let mut sign = ScalarNumber::Integer(@bigint.BigInt::from_int(1))
  if scalar_numeric_less(value, zero) {
    sign = ScalarNumber::Integer(@bigint.BigInt::from_int(-1))
    value = scalar_numeric_op(zero, value, 1)
  }
  let phase = if scalar_numeric_truth(Some(value)) {
    scalar_numeric_floor(scalar_math_log10(value) / 3.0) *
    @bigint.BigInt::from_int(3)
  } else {
    value = ScalarNumber::Number(0.0)
    @bigint.BigInt::from_int(0)
  }
  let lower = eng_numeric_prefix_bound(state, maximum=false)
  let upper = eng_numeric_prefix_bound(state, maximum=true)
  let mut power = eng_math_clip(phase, lower, upper)
  let signed = scalar_numeric_op(sign, value, 2)
  let denominator = scalar_math_power10(power, float_base=true)
  let mut mantissa = scalar_numeric_op(signed, denominator, 3)
  let rendered = method_format_float(
    scalar_numeric_double(mantissa),
    method_parse_spec(format, "float"),
  )
  let rounded = if rendered == "inf" || rendered == "-inf" {
    1.0 / 0.0
  } else if rendered == "nan" {
    0.0 / 0.0
  } else {
    Double::abs(try! @string.parse_double(rendered[:]))
  }
  if rounded >= 1000.0 &&
    eng_prefix_less(power, eng_numeric_prefix_bound(state, maximum=true)) {
    mantissa = scalar_numeric_op(
      mantissa,
      ScalarNumber::Integer(@bigint.BigInt::from_int(1000)),
      3,
    )
    power = scalar_numeric_op(
      power,
      ScalarNumber::Integer(@bigint.BigInt::from_int(3)),
      0,
    )
  }
  let key = scalar_numeric_integer(power)
  let prefix = match eng_state_prefixes(state).get(ScalarNumber::Integer(key)) {
    Some(prefix) => prefix
    None =>
      raise @core.DataError::InvalidTicks(
        message="KeyError: " + scalar_percent_integer_str(key),
      )
  }
  let suffix = if state.unit != "" || prefix != "" {
    state.sep + prefix + state.unit
  } else {
    ""
  }
  let delimiters = if state.scalar.usetex || state.scalar.use_math_text {
    2L
  } else {
    0L
  }
  let reserved = Int64::from_int(suffix.length()) + delimiters
  let text = method_format_float(
    scalar_numeric_double(mantissa),
    method_parse_spec(format, "float"),
    available=2147483647L - reserved,
  )
  if state.scalar.usetex || state.scalar.use_math_text {
    "$" + text + "$" + suffix
  } else {
    text + suffix
  }
}

///|
fn eng_named_call(
  base : BaseFormatter,
  state : EngFormatterState,
  value : ScalarNumber,
  pos : Int32?,
) -> String raise @core.DataError {
  if base.locations.length() == 0 ||
    scalar_numeric_equal(
      state.scalar.offset.unwrap_or(ScalarNumber::Number(0.0 / 0.0)),
      ScalarNumber::Integer(@bigint.BigInt::from_int(0)),
    ) {
    BaseFormatter::fix_minus(eng_named_format_data(state, value))
  } else {
    scalar_named_call(base, state.scalar, value, pos)
  }
}

///|
fn eng_named_prepare(
  base : BaseFormatter,
  state : EngFormatterState,
) -> Unit raise @core.DataError {
  if base.locations.length() == 0 {
    return
  }
  let (lower, upper) = scalar_numeric_view(base, sort=true)
  if state.scalar.use_offset {
    scalar_prepare_offset(base, state.scalar)
    if !scalar_numeric_equal(
        state.scalar.offset.unwrap_or(ScalarNumber::Number(0.0 / 0.0)),
        ScalarNumber::Integer(@bigint.BigInt::from_int(0)),
      ) {
      let sum = scalar_numeric_op(lower, upper, 0)
      let midpoint = scalar_numeric_op(
        sum,
        ScalarNumber::Integer(@bigint.BigInt::from_int(2)),
        3,
      )
      state.scalar.offset = Some(scalar_math_round_digits(midpoint, 3))
    }
  }
  state.scalar.order = eng_math_order(scalar_numeric_op(upper, lower, 1))
  scalar_prepare_format(base, state.scalar)
}

///|
fn eng_named_offset(
  base : BaseFormatter,
  state : EngFormatterState,
) -> String raise @core.DataError {
  if base.locations.length() == 0 || !scalar_numeric_truth(state.scalar.offset) {
    return ""
  }
  let offset = state.scalar.offset.unwrap()
  let mut offset_text = eng_named_format_data(state, offset)
  if scalar_numeric_less(
      ScalarNumber::Integer(@bigint.BigInt::from_int(0)),
      offset,
    ) {
    offset_text = "+" + offset_text
  }
  let scientific = eng_named_format_data(
    state,
    scalar_math_power10(state.scalar.order, float_base=false),
  )
  let text = if state.scalar.use_math_text || state.scalar.usetex {
    "$" +
    (if scientific != "" { "\\times" + scientific } else { "" }) +
    offset_text +
    "$"
  } else {
    scientific + offset_text
  }
  BaseFormatter::fix_minus(text)
}
