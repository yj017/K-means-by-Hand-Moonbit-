///|
/// Preserve the actual scalar produced by the retained list or ndarray.
priv enum NamedFormatValue {
  PythonFloat(Double)
  PythonInteger(@bigint.BigInt)
  NumpyFloat64(Double)
  NumpyInt64(Int64)
}

///|
fn named_format_error(
  kind : String,
  message : String,
) -> String raise @core.DataError {
  raise @core.DataError::InvalidTicks(message=kind + ": " + message)
}

///|
fn named_format_value_double(
  value : NamedFormatValue,
) -> Double raise @core.DataError {
  match value {
    PythonFloat(number) | NumpyFloat64(number) => number
    PythonInteger(number) => percent_python_integer_double(number)
    NumpyInt64(number) => number.to_double()
  }
}

///|
fn named_format_value_str(
  value : NamedFormatValue,
) -> String raise @core.DataError {
  match value {
    PythonFloat(number) | NumpyFloat64(number) =>
      named_format_float_repr(number)
    PythonInteger(number) => scalar_percent_integer_str(number)
    NumpyInt64(number) => number.to_string()
  }
}

///|
fn named_format_value_repr(
  value : NamedFormatValue,
) -> String raise @core.DataError {
  match value {
    PythonFloat(number) => named_format_float_repr(number)
    PythonInteger(number) => scalar_percent_integer_str(number)
    NumpyFloat64(number) =>
      "np.float64(" + named_format_float_repr(number) + ")"
    NumpyInt64(number) => "np.int64(" + number.to_string() + ")"
  }
}

///|
/// Core Ryu (and JS Number::toString) supplies shortest round-trip digits.
/// Reposition those digits using Python's -4/16 notation thresholds, retaining
/// signed zero, a fractional digit for fixed integers and two exponent digits.
fn named_format_float_repr(value : Double) -> String {
  if numeric_special(value) is Some(text) {
    return text
  }
  if value == 0.0 {
    return numeric_sign(value) + "0.0"
  }
  let shortest = Double::abs(value).to_string()
  let exponent_index = shortest.find("e").unwrap_or(shortest.length())
  let coefficient = shortest[:exponent_index].to_owned()
  let explicit_exponent = if exponent_index < shortest.length() {
    try! @string.parse_int(shortest[exponent_index + 1:])
  } else {
    0
  }
  let point = coefficient.find(".").unwrap_or(coefficient.length())
  let raw_digits = coefficient.replace_all(old=".", new="")
  let mut start = 0
  while start < raw_digits.length() - 1 && raw_digits[start] == 48 {
    start += 1
  }
  let mut end = raw_digits.length()
  while end > start + 1 && raw_digits[end - 1] == 48 {
    end -= 1
  }
  let digits = raw_digits[start:end].to_owned()
  let exponent = explicit_exponent + point - start - 1
  let scientific = exponent < -4 || exponent >= 16
  let mantissa = decimal_point(
    digits,
    if scientific {
      1
    } else {
      exponent + 1
    },
  )
  let mantissa = if !scientific && !mantissa.contains(".") {
    mantissa + ".0"
  } else {
    mantissa
  }
  numeric_sign(value) +
  mantissa +
  (if scientific { decimal_exponent_suffix(exponent) } else { "" })
}

///|
/// Represent a Double with the existing Python shortest-number profile.
pub fn python_float_repr(value : Double) -> String {
  named_format_float_repr(value)
}

///|
/// Add the alternate decimal point before a possible scientific exponent.
fn named_format_decimal_point(text : String) -> String {
  let index = text.find("e").unwrap_or(text.length())
  if text[:index].contains(".") {
    text
  } else {
    text[:index].to_owned() + "." + text[index:].to_owned()
  }
}

///|
fn named_format_within_budget(
  text : String,
  available : Int64,
) -> String raise @core.DataError {
  if Int64::from_int(text.length()) > available {
    return named_format_error(
      "ResourceError", "formatted text exceeds String addressability",
    )
  }
  text
}

///|
/// Exact binary64 rounding, without the legacy convenience precision limit.
/// This layer supplies ASCII digits/sign only; each caller owns its padding,
/// grouping, explicit sign and rounded-negative-zero policies.
fn named_format_float_digits(
  input : Double,
  code : Char,
  precision : Int32?,
  alternate : Bool,
  available~ : Int64 = 2147483647L,
) -> String raise @core.DataError {
  let percent = code == '%'
  let value = if percent { input * 100.0 } else { input }
  let uppercase = code == 'E' || code == 'F' || code == 'G'
  let suffix = if percent { "%" } else { "" }
  if numeric_special(value) is Some(text) {
    return named_format_within_budget(
      (if uppercase { text.to_upper() } else { text }) + suffix,
      available,
    )
  }
  let empty_type = code == '\u0000'
  if empty_type && precision is None {
    let text = named_format_float_repr(value)
    return named_format_within_budget(
      if alternate {
        named_format_decimal_point(text)
      } else {
        text
      },
      available,
    )
  }
  let places = precision.unwrap_or(6)
  if places < 0 {
    return named_format_error("ValueError", "negative format precision")
  }
  // At these precisions every finite binary64 is already exact, so its decimal
  // exponent cannot change by rounding. Preflight before allocating precision
  // padding, including any output budget reserved by the enclosing formatter.
  // Do not reject a huge non-alternate g:
  // it can have a short result after removing the exact decimal's trailing zeros.
  if places >= 1075 &&
    (
      alternate ||
      code == 'f' ||
      code == 'F' ||
      code == 'e' ||
      code == 'E' ||
      percent
    ) {
    let exponent = decimal_exponent(value)
    let sign_length = Int64::from_int(numeric_sign(value).length())
    let required = if code == 'f' || code == 'F' || percent {
      sign_length +
      Int64::from_int(Int32::max(1, exponent + 1)) +
      1L +
      Int64::from_int(places) +
      (if percent { 1L } else { 0L })
    } else if code == 'e' || code == 'E' || exponent < -4 {
      sign_length +
      Int64::from_int(places) +
      (if code == 'e' || code == 'E' { 2L } else { 1L }) +
      Int64::from_int(decimal_exponent_suffix(exponent).length())
    } else {
      sign_length +
      Int64::from_int(places) +
      1L +
      Int64::from_int(Int32::max(0, -exponent))
    }
    if required > available {
      return named_format_error(
        "ResourceError", "formatted text exceeds String addressability",
      )
    }
  }
  let body = if code == 'f' || code == 'F' || percent {
    let digits = decimal_round(value, places)
      .to_string()
      .pad_start(places + 1, '0')
    let text = decimal_point(digits, digits.length() - places)
    if alternate {
      named_format_decimal_point(text)
    } else {
      text
    }
  } else if code == 'e' || code == 'E' {
    let (digits, exponent) = decimal_significant(value, places + 1)
    let text = decimal_point(digits, 1)
    (if alternate { named_format_decimal_point(text) } else { text }) +
    decimal_exponent_suffix(exponent)
  } else if empty_type || code == 'g' || code == 'G' || code == 'n' {
    let count = Int32::max(1, places)
    // A binary64 is an integer divided by at most 2^1074. Its terminating
    // decimal has fewer than 1075 significant digits. Beyond that point the
    // extra digits are all zeros, which this non-alternate branch removes.
    let work_count = if alternate { count } else { Int32::min(count, 1075) }
    let (digits, exponent) = decimal_significant(value, work_count)
    // Python's omitted presentation reserves one significant place for '.0'.
    let scientific = exponent < -4 ||
      exponent >= count - (if empty_type { 1 } else { 0 })
    let text = decimal_point(digits, if scientific { 1 } else { exponent + 1 })
    let text = if alternate {
      named_format_decimal_point(text)
    } else {
      trim_decimal(text)
    }
    let text = if empty_type && !scientific && !text.contains(".") {
      text + ".0"
    } else {
      text
    }
    text + (if scientific { decimal_exponent_suffix(exponent) } else { "" })
  } else {
    return named_format_error("ValueError", "unsupported floating presentation")
  }
  let text = numeric_sign(value) + body + suffix
  named_format_within_budget(
    if uppercase {
      text.to_upper()
    } else {
      text
    },
    available,
  )
}
