///|
fn log_format_type(value : LogValue) -> String {
  match value {
    NoneValue => "NoneType"
    Text(_) => "str"
    Numeric(Number(_) | NumpyFloat64(_)) => "float"
    Numeric(Boolean(_) | NumpyBool(_)) => "bool"
    Numeric(_) => "int"
  }
}

///|
fn log_format_numeric(
  value : LogValue,
  unary~ : Bool = false,
) -> ScalarNumber raise @core.DataError {
  match value {
    Numeric(value) => value
    _ =>
      raise log_format_error(
        if unary {
          "TypeError: bad operand type for unary -: '" +
          log_format_type(value) +
          "'"
        } else {
          "TypeError: must be real number, not " + log_format_type(value)
        },
      )
  }
}

///|
fn log_format_negative(value : LogValue) -> ScalarNumber raise @core.DataError {
  match log_format_numeric(value, unary=true) {
    Number(value) => ScalarNumber::Number(-value)
    NumpyFloat64(value) => ScalarNumber::NumpyFloat64(-value)
    Integer(value) => ScalarNumber::Integer(value.neg())
    Boolean(value) =>
      ScalarNumber::Integer(
        @bigint.BigInt::from_int(if value { -1 } else { 0 }),
      )
    NumpyInt64(value) =>
      ScalarNumber::NumpyInt64(
        (0UL - value.reinterpret_as_uint64()).reinterpret_as_int64(),
      )
    NumpyBool(_) =>
      raise log_format_error(
        "TypeError: The numpy boolean negative, the `-` operator, is not supported, use the `~` operator or the logical_not function instead.",
      )
  }
}

///|
fn log_format_threshold_greater(
  value : ScalarNumber,
  threshold : LogValue,
) -> Bool raise @core.DataError {
  match threshold {
    Numeric(other) => eng_prefix_less(other, value)
    _ =>
      raise log_format_error(
        "TypeError: '>' not supported between instances of '" +
        log_format_type(LogValue::Numeric(value)) +
        "' and '" +
        log_format_type(threshold) +
        "'",
      )
  }
}

///|
fn log_named_prepare(
  base : BaseFormatter,
  state : LogFormatterState,
) -> Unit raise @core.DataError {
  let first = log_threshold_at(state.minor_thresholds, 0)
  let infinite = match first {
    Numeric(number) => {
      ignore(log_format_isfinite(number, "isinf"))
      match number {
        Number(value) | NumpyFloat64(value) => value.is_inf()
        _ => false
      }
    }
    _ =>
      raise log_format_error(
        "TypeError: ufunc 'isinf' not supported for the input types, and the inputs could not be safely coerced to any supported types according to the casting rule ''safe''",
      )
  }
  if infinite {
    state.sublabels = None
    return
  }
  let mut linthresh = state.linthresh
  if linthresh is NoneValue {
    let transform = try {
      match base.axis {
        Some(axis) => axis.transform_linthresh()
        None =>
          raise log_format_error(
            "AttributeError: 'NoneType' object has no attribute 'get_transform'",
          )
      }
    } catch {
      @core.DataError::InvalidTicks(message~) =>
        if message.has_prefix("AttributeError:") {
          None
        } else {
          raise log_format_error(message)
        }
      error => raise error
    }
    if transform is Some(value) {
      linthresh = LogValue::Numeric(value)
    }
  }
  let (vmin, vmax) = scalar_numeric_view(base, sort=true)
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  if linthresh is NoneValue && !eng_prefix_less(zero, vmin) {
    // Python <= is false for NaN, unlike the complement of >.
    if eng_prefix_compare(vmin, zero) is Some(order) && order <= 0 {
      state.sublabels = Some(log_cache_explicit([1.0]))
      return
    }
  }
  let b = state.base
  let mut numticks = @bigint.BigInt::from_int(0)
  let mut numdec = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  if !(linthresh is NoneValue) {
    let negative = log_format_negative(linthresh)
    if eng_prefix_less(vmin, negative) {
      let negative = log_format_negative(linthresh)
      let rhs = if eng_prefix_less(negative, vmax) { negative } else { vmax }
      numticks += scalar_numeric_floor(
          log_format_log(scalar_numeric_abs(rhs), b),
        ) -
        scalar_numeric_floor(
          log_format_next_down(log_format_log(scalar_numeric_abs(vmin), b)),
        )
      numdec = scalar_numeric_op(
        numdec,
        ScalarNumber::Number(log_format_log(scalar_numeric_op(vmin, rhs, 3), b)),
        0,
      )
    }
    let positive = log_format_numeric(linthresh)
    if eng_prefix_less(positive, vmax) {
      let positive = log_format_numeric(linthresh)
      let lhs = if eng_prefix_less(vmin, positive) { positive } else { vmin }
      numticks += scalar_numeric_floor(log_format_log(vmax, b)) -
        scalar_numeric_floor(log_format_next_down(log_format_log(lhs, b)))
      numdec = scalar_numeric_op(
        numdec,
        ScalarNumber::Number(log_format_log(scalar_numeric_op(vmax, lhs, 3), b)),
        0,
      )
    }
  } else {
    let lmin = log_format_log(vmin, b)
    let lmax = log_format_log(vmax, b)
    numticks = scalar_numeric_floor(lmax) -
      scalar_numeric_floor(log_format_next_down(lmin))
    numdec = ScalarNumber::Number(Double::abs(lmax - lmin))
  }
  if log_format_threshold_greater(
      ScalarNumber::Integer(numticks),
      log_threshold_at(state.minor_thresholds, 0),
    ) {
    state.sublabels = Some(log_cache_explicit([1.0]))
  } else if log_format_threshold_greater(
      numdec,
      log_threshold_at(state.minor_thresholds, 1),
    ) {
    let cache = log_cache_geom(b)
    state.sublabels = Some(cache)
  } else {
    let cache = log_cache_arange(b)
    state.sublabels = Some(cache)
  }
}
