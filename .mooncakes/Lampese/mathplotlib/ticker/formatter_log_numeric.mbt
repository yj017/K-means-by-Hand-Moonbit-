///|
fn log_format_trim(value : String) -> String {
  let characters = value.to_array()
  let mut last = characters.length()
  while last > 0 && characters[last - 1] == '0' {
    last -= 1
  }
  if last > 0 && characters[last - 1] == '.' {
    last -= 1
  }
  String::from_array(characters[:last])
}

///|
fn log_format_pretty(
  value : ScalarNumber,
  delta : Double,
) -> String raise @core.DataError {
  if scalar_numeric_less(
      scalar_numeric_abs(value),
      ScalarNumber::Integer(@bigint.BigInt::from_int(10000)),
    ) {
    let integer = scalar_numeric_integer(value)
    if scalar_numeric_equal(value, ScalarNumber::Integer(integer)) {
      return scalar_percent_format("%d", value)
    }
  }
  let format = if delta < 1.0e-2 {
    "%1.3e"
  } else if delta <= 1.0 {
    "%1.3f"
  } else if delta <= 10.0 {
    "%1.2f"
  } else if delta <= 1.0e5 {
    "%1.1f"
  } else {
    "%1.1e"
  }
  let text = scalar_percent_format(format, value)
  let chars = text.to_array()
  let mut split = -1
  for index in 0..<chars.length() {
    if chars[index] == 'e' {
      split = index
      break
    }
  }
  if split >= 0 {
    let mantissa = log_format_trim(String::from_array(chars[:split]))
    let exponent = percent_precision_text_integer(
      String::from_array(chars[split + 1:]),
    )
    if exponent.is_zero() {
      mantissa
    } else {
      mantissa + "e" + scalar_percent_integer_str(exponent)
    }
  } else {
    log_format_trim(text)
  }
}

///|
fn log_format_view(
  base : BaseFormatter,
) -> (Double, Double) raise @core.DataError {
  let (lower, upper) = scalar_numeric_view(base)
  if !log_format_isfinite(lower, "isfinite") ||
    !log_format_isfinite(upper, "isfinite") {
    return (-0.05, 0.05)
  }
  locator_nonsingular(
    scalar_numeric_double(lower),
    scalar_numeric_double(upper),
    0.05,
  )
}

///|
fn log_named_call(
  base : BaseFormatter,
  state : LogFormatterState,
  value : ScalarNumber,
  _pos : Int32?,
) -> String raise @core.DataError {
  let mathtext = state.style is (Mathtext | SciNotation)
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  if scalar_numeric_equal(value, zero) {
    return if mathtext { "$\\mathdefault{0}$" } else { "0" }
  }
  let sign = if mathtext && scalar_numeric_less(value, zero) { "-" } else { "" }
  let value = scalar_numeric_abs(value)
  let fx = log_format_log(value, state.base)
  let decade = log_format_close(fx)
  let exponent = if decade {
    ScalarNumber::Integer(log_format_round(fx))
  } else {
    ScalarNumber::NumpyFloat64(fx.floor())
  }
  let coefficient = log_format_round(
    log_format_power(
      state.base,
      scalar_numeric_op(ScalarNumber::Number(fx), exponent, 1),
    ),
  )
  if log_value_truth(state.label_only_base) && !decade {
    return ""
  }
  if state.sublabels is Some(cache) &&
    !log_cache_contains(cache, index_round_binary(coefficient, 0)) {
    return ""
  }
  if !mathtext {
    let (lower, upper) = log_format_view(base)
    let text = if state.style is Exponent {
      let fx = log_format_log(value, state.base)
      if Double::abs(fx) >= 1.0 && Double::abs(fx) <= 10000.0 {
        let delta = log_format_log(
          ScalarNumber::Number(upper - lower),
          state.base,
        )
        log_format_pretty(ScalarNumber::Number(fx), delta)
      } else {
        method_format_float(fx, method_parse_spec("1.0g", "float"))
      }
    } else if !scalar_numeric_less(
        value,
        ScalarNumber::Integer(@bigint.BigInt::from_int(1)),
      ) &&
      !scalar_numeric_less(
        ScalarNumber::Integer(@bigint.BigInt::from_int(10000)),
        value,
      ) {
      log_format_pretty(value, upper - lower)
    } else {
      method_format_float(
        scalar_numeric_double(value),
        method_parse_spec("1.0e", "float"),
      )
    }
    return BaseFormatter::fix_minus(text)
  }
  let phase = if decade {
    ScalarNumber::Integer(log_format_round(fx))
  } else {
    ScalarNumber::Number(fx)
  }
  let base_text = scalar_percent_format(
    if state.base % 1.0 == 0.0 {
      "%d"
    } else {
      "%s"
    },
    ScalarNumber::Number(state.base),
  )
  if scalar_numeric_less(
      scalar_numeric_abs(phase),
      ScalarNumber::Integer(@config.formatter_min_exponent()),
    ) {
    return "$\\mathdefault{" + sign + scalar_percent_format("%g", value) + "}$"
  }
  if decade {
    return "$\\mathdefault{" +
      sign +
      base_text +
      "^{" +
      scalar_percent_format("%d", phase) +
      "}}$"
  }
  // The source reads this live setting before the virtual non-decade method.
  ignore(@config.text_usetex())
  if state.style is Mathtext {
    return "$\\mathdefault{" +
      sign +
      base_text +
      "^{" +
      scalar_percent_format("%.2f", phase) +
      "}}$"
  }
  let exponent = scalar_numeric_floor(fx)
  let exponent_value = ScalarNumber::Integer(exponent)
  let b = log_text_float(base_text)
  let coeff = log_format_power(
    b,
    scalar_numeric_op(ScalarNumber::Number(fx), exponent_value, 1),
  )
  let coeff = if log_format_close(coeff) {
    ScalarNumber::Integer(log_format_round(coeff))
  } else {
    ScalarNumber::Number(coeff)
  }
  "$\\mathdefault{" +
  sign +
  scalar_percent_format("%g", coeff) +
  "\\times" +
  base_text +
  "^{" +
  scalar_percent_integer_str(exponent) +
  "}}$"
}

///|
fn log_format_replace(
  text : String,
  token : String,
  replacement : String,
) -> String {
  let chars = text.to_array()
  let find = token.to_array()
  let out = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    let mut matches = index + find.length() <= chars.length()
    if matches {
      for offset in 0..<find.length() {
        if chars[index + offset] != find[offset] {
          matches = false
          break
        }
      }
    }
    if matches {
      out.write_string(replacement)
      index += find.length()
    } else {
      out.write_char(chars[index])
      index += 1
    }
  }
  out.to_string()
}

///|
fn log_named_data(
  base : BaseFormatter,
  state : LogFormatterState,
  value : ScalarNumber,
) -> String raise @core.DataError {
  let previous = state.label_only_base
  state.label_only_base = LogValue::Numeric(ScalarNumber::Boolean(false))
  defer {
    state.label_only_base = previous
  }
  let text = log_named_call(base, state, value, None)
  let chars = text.to_array()
  if chars.length() < 2 || chars[0] != '$' || chars[chars.length() - 1] != '$' {
    return text
  }
  let mut text = String::from_array(chars[1:chars.length() - 1])
  for
    (token, replacement) in [
      ("\\times", "x"),
      ("\\mathdefault", ""),
      ("\\rm", ""),
      ("\\cal", ""),
      ("\\tt", ""),
      ("\\it", ""),
      ("\\", ""),
      ("{", ""),
      ("}", ""),
    ] {
    text = log_format_replace(text, token, replacement)
  }
  text
}

///|
fn log_named_short(value : ScalarNumber) -> String raise @core.DataError {
  let text = scalar_percent_format("%-12g", value)
  let chars = text.to_array()
  let mut last = chars.length()
  while last > 0 && chars[last - 1] == ' ' {
    last -= 1
  }
  String::from_array(chars[:last])
}
