///|
fn scalar_prepare_locations(
  base : BaseFormatter,
) -> Array[ScalarNumber] raise @core.DataError {
  let locations = scalar_numpy_locations(base.locations)
  Array::makei(locations.length(), index => {
    scalar_numeric_location(locations, index)
  })
}

///|
fn scalar_prepare_visible(
  locations : FormatterLocations,
  lower : ScalarNumber,
  upper : ScalarNumber,
) -> Array[ScalarNumber] raise @core.DataError {
  let locations = scalar_numpy_locations(locations)
  let result = []
  for index in 0..<locations.length() {
    let value = scalar_numeric_location(locations, index)
    let left = scalar_numeric_compare(lower, value)
    let right = scalar_numeric_compare(value, upper)
    if (left is Some(-1) || left is Some(0)) &&
      (right is Some(-1) || right is Some(0)) {
      result.push(value)
    }
  }
  result
}

///|
fn scalar_prepare_extrema(
  values : Array[ScalarNumber],
  object~ : Bool = false,
) -> (ScalarNumber, ScalarNumber) raise @core.DataError {
  let mut lower = values[0]
  let mut upper = values[0]
  for index in 1..<values.length() {
    let value = values[index]
    if object {
      let low = scalar_numeric_compare(lower, value)
      let high = scalar_numeric_compare(upper, value)
      if low != Some(-1) && low != Some(0) {
        lower = value
      }
      if high != Some(1) && high != Some(0) {
        upper = value
      }
    } else {
      if scalar_numeric_less(value, lower) ||
        (match value {
          Number(v) | NumpyFloat64(v) => v.is_nan()
          _ => false
        }) {
        lower = value
      }
      if scalar_numeric_less(upper, value) ||
        (match value {
          Number(v) | NumpyFloat64(v) => v.is_nan()
          _ => false
        }) {
        upper = value
      }
    }
  }
  (lower, upper)
}

///|
fn scalar_prepare_offset(
  base : BaseFormatter,
  state : ScalarFormatterState,
) -> Unit raise @core.DataError {
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  let locations = base.locations
  let (vmin, vmax) = scalar_numeric_view(base, sort=true)
  let values = scalar_prepare_visible(locations, vmin, vmax)
  if values.is_empty() {
    state.offset = Some(zero)
    return
  }
  let (lmin, lmax) = scalar_prepare_extrema(values)
  if scalar_numeric_equal(lmin, lmax) ||
    (!scalar_numeric_less(zero, lmin) && !scalar_numeric_less(lmax, zero)) {
    state.offset = Some(zero)
    return
  }
  let first = scalar_numeric_double(lmin)
  let last = scalar_numeric_double(lmax)
  let a = Double::abs(first)
  let b = Double::abs(last)
  let abs_min = if b < a { b } else { a }
  let abs_max = if b < a { a } else { b }
  if abs_min == abs_max && !scalar_numeric_equal(lmin, lmax) {
    raise @core.DataError::InvalidTicks(
      message="Unsupported: unequal integer extrema collapse to one float; upstream offset search does not terminate",
    )
  }
  let sign = if first.reinterpret_as_uint64() >> 63 != 0UL { -1.0 } else { 1.0 }
  let maximum = scalar_math_log10(ScalarNumber::Number(abs_max)).ceil()
  let mut phase = maximum
  while true {
    let power = scalar_math_pow10(phase)
    if scalar_numeric_float_floor_divide(abs_min, power) !=
      scalar_numeric_float_floor_divide(abs_max, power) {
      break
    }
    phase -= 1.0
  }
  let mut oom = 1.0 + phase
  if (abs_max - abs_min) / scalar_math_pow10(oom) <= 1.0e-2 {
    phase = maximum
    while true {
      let power = scalar_math_pow10(phase)
      if scalar_numeric_float_floor_divide(abs_max, power) -
        scalar_numeric_float_floor_divide(abs_min, power) >
        1.0 {
        break
      }
      phase -= 1.0
    }
    oom = 1.0 + phase
  }
  let power = scalar_math_pow10(oom)
  let prefix = scalar_numeric_float_floor_divide(abs_max, power)
  let threshold = scalar_math_power10(
    ScalarNumber::Integer(state.offset_threshold - @bigint.BigInt::from_int(1)),
    float_base=false,
  )
  if !scalar_numeric_less(ScalarNumber::NumpyFloat64(prefix), threshold) &&
    !prefix.is_nan() {
    let signed = sign * prefix
    state.offset = Some(ScalarNumber::NumpyFloat64(signed * power))
  } else {
    state.offset = Some(zero)
  }
}

///|
fn scalar_prepare_order(
  base : BaseFormatter,
  state : ScalarFormatterState,
) -> Unit raise @core.DataError {
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  if !state.scientific {
    state.order = zero
    return
  }
  let first = scalar_power_limit_at(state.power_limits, 0)
  let second = scalar_power_limit_at(state.power_limits, 1)
  if scalar_numeric_equal(first, second) && scalar_numeric_truth(Some(second)) {
    state.order = scalar_power_limit_at(state.power_limits, 0)
    return
  }
  let (vmin, vmax) = scalar_numeric_view(base, sort=true)
  let values = scalar_prepare_visible(base.locations, vmin, vmax).map(
    scalar_numeric_abs,
  )
  if values.is_empty() {
    state.order = zero
    return
  }
  let oom = if scalar_numeric_truth(state.offset) {
    scalar_numeric_floor(scalar_math_log10(scalar_numeric_op(vmax, vmin, 1)))
  } else {
    let value = scalar_prepare_extrema(values).1
    if scalar_numeric_equal(value, zero) {
      @bigint.BigInt::from_int(0)
    } else {
      scalar_numeric_floor(scalar_math_log10(value))
    }
  }
  let order = ScalarNumber::Integer(oom)
  let low = scalar_numeric_compare(
    order,
    scalar_power_limit_at(state.power_limits, 0),
  )
  if low == Some(-1) || low == Some(0) {
    state.order = order
  } else {
    let high = scalar_numeric_compare(
      order,
      scalar_power_limit_at(state.power_limits, 1),
    )
    state.order = if high == Some(1) || high == Some(0) { order } else { zero }
  }
}

///|
// np.asarray of the temporary Python list chooses object only outside both
// fixed-width integer domains. Signed/unsigned mixing promotes to float64.
fn scalar_prepare_promote(
  values : Array[ScalarNumber],
) -> (Array[ScalarNumber], Bool) raise @core.DataError {
  let mut floating = false
  let mut unsigned = false
  let mut object = false
  for value in values {
    match value {
      Number(_) | NumpyFloat64(_) => floating = true
      Integer(integer) =>
        if integer < @bigint.BigInt::from_int64(-9223372036854775808L) ||
          integer > @bigint.BigInt::from_uint64(18446744073709551615UL) {
          object = true
        } else if integer > @bigint.BigInt::from_int64(9223372036854775807L) {
          unsigned = true
        }
      _ => ()
    }
  }
  if object {
    return (values, true)
  }
  if floating || unsigned {
    (
      values.map(value => {
        ScalarNumber::NumpyFloat64(scalar_numeric_double(value))
      }),
      false,
    )
  } else {
    (
      values.map(value => ScalarNumber::NumpyInt64(scalar_numeric_int64(value))),
      false,
    )
  }
}

///|
fn scalar_prepare_format(
  base : BaseFormatter,
  state : ScalarFormatterState,
) -> Unit raise @core.DataError {
  let short = base.locations.length() < 2
  let mut locations = if short {
    match base.locations {
      Sequence(values) => values.map(value => ScalarNumber::Number(value))
      Integers(values) => values.map(value => ScalarNumber::Integer(value))
      NdArray(_) | Typed(_) => scalar_prepare_locations(base)
    }
  } else {
    scalar_prepare_locations(base)
  }
  let mut object = false
  if short {
    let view = match base.axis {
      Some(axis) => axis.view_interval()
      None =>
        raise @core.DataError::InvalidTicks(
          message="AttributeError: 'NoneType' object has no attribute 'get_view_interval'",
        )
    }
    for index in 0..<view.length() {
      locations.push(
        match view {
          Sequence(values) => ScalarNumber::Number(values[index])
          Integers(values) => ScalarNumber::Integer(values[index])
          NdArray(values) =>
            if values.is_int64() {
              ScalarNumber::NumpyInt64(values.get_int64(index))
            } else {
              ScalarNumber::NumpyFloat64(values.get(index))
            }
        },
      )
    }
    let (promoted, is_object) = scalar_prepare_promote(locations)
    locations = promoted
    object = is_object
  }
  let subtracted = locations.map(value => {
    scalar_numeric_sub_offset(value, state.offset)
  })
  let power = scalar_math_power10(state.order, float_base=true)
  locations = subtracted.map(value => scalar_numeric_op(value, power, 3))
  let (lower, upper) = scalar_prepare_extrema(locations, object~)
  let mut range = scalar_numeric_op(upper, lower, 1)
  let zero = ScalarNumber::Integer(@bigint.BigInt::from_int(0))
  if scalar_numeric_equal(range, zero) {
    range = scalar_prepare_extrema(locations.map(scalar_numeric_abs), object~).1
  }
  if scalar_numeric_equal(range, zero) {
    range = ScalarNumber::Integer(@bigint.BigInt::from_int(1))
  }
  if base.locations.length() < 2 {
    let length = Int32::max(0, locations.length() - 2)
    locations = Array::makei(length, index => locations[index])
  }
  let oom = scalar_numeric_floor(scalar_math_log10(range))
  let mut precision = Int32::max(0, 3 - oom.to_int())
  let threshold = scalar_numeric_double(
    scalar_numeric_op(
      ScalarNumber::Number(1.0e-3),
      scalar_math_power10(ScalarNumber::Integer(oom), float_base=false),
      2,
    ),
  )
  while precision >= 0 {
    if locations.is_empty() {
      raise @core.DataError::InvalidTicks(
        message="ValueError: zero-size array to reduction operation maximum which has no identity",
      )
    }
    if object {
      let name = if scalar_numeric_numpy(locations[0]) {
        "numpy.float64"
      } else {
        "float"
      }
      raise @core.DataError::InvalidTicks(
        message="TypeError: loop of ufunc does not support argument 0 of type " +
          name +
          " which has no callable rint method",
      )
    }
    let errors = locations.map(value => {
      let value = scalar_numeric_double(value)
      Double::abs(value - scalar_math_numpy_round(value, precision))
    })
    let mut maximum = errors[0]
    for index in 1..<errors.length() {
      if errors[index].is_nan() || errors[index] > maximum {
        maximum = errors[index]
      }
    }
    if maximum < threshold {
      precision -= 1
    } else {
      break
    }
  }
  precision += 1
  let pattern = "%1." + precision.to_string() + "f"
  state.format_pattern = if state.usetex || state.use_math_text {
    "$\\mathdefault{" + pattern + "}$"
  } else {
    pattern
  }
}

///|
fn scalar_named_prepare(
  base : BaseFormatter,
  state : ScalarFormatterState,
) -> Unit raise @core.DataError {
  if base.locations.length() > 0 {
    if state.use_offset {
      scalar_prepare_offset(base, state)
    }
    scalar_prepare_order(base, state)
    scalar_prepare_format(base, state)
  }
}

///|
fn scalar_numpy_locations(
  locations : FormatterLocations,
) -> FormatterLocations raise @core.DataError {
  match locations {
    Integers(values) =>
      LogitInput::from_keys(
        values.map(value => LogitKey::new(ScalarNumber::Integer(value))),
      ).snapshot()
    _ => locations
  }
}
