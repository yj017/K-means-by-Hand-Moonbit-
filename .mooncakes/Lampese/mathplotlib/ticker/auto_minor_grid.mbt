///|
// Preserve integer dtype through unique: its first subtraction is an Int64
// NumPy scalar subtraction, including two's-complement overflow.
fn auto_minor_unique(major : TickValues) -> TickValues raise @core.DataError {
  if major.is_int64() {
    let values = Array::makei(major.length(), index => major.get_int64(index))
    values.sort()
    let unique : Array[Int64] = []
    for value in values {
      if unique.is_empty() || value != unique[unique.length() - 1] {
        unique.push(value)
      }
    }
    return TickValues::from_int64_array(unique)
  }
  let values = major.to_array()
  let mut zero_count = 0
  let mut negative_zero = false
  let mut first_zero = 0.0
  for value in values {
    if value == 0.0 {
      if zero_count == 0 {
        first_zero = value
      }
      zero_count += 1
      if value.reinterpret_as_uint64() >> 63 != 0UL {
        negative_zero = true
      }
    }
  }
  values.sort_by((left, right) => {
    if left.is_nan() {
      if right.is_nan() {
        0
      } else {
        1
      }
    } else if right.is_nan() {
      -1
    } else if left < right {
      -1
    } else if left > right {
      1
    } else {
      0
    }
  })
  let unique : Array[Double] = []
  for value in values {
    if unique.is_empty() ||
      (
        value != unique[unique.length() - 1] &&
        !(value.is_nan() && unique[unique.length() - 1].is_nan())
      ) {
      let value = if value == 0.0 {
        // The pinned NEON sorting networks select -0. Large equal partitions
        // can keep either representative: source VQSort randomizes its pivot.
        if negative_zero && zero_count <= 16 {
          -0.0
        } else {
          first_zero
        }
      } else if value.is_nan() {
        0x7fffffffffffffffUL.reinterpret_as_int64().reinterpret_as_double()
      } else {
        value
      }
      unique.push(value)
    }
  }
  TickValues::from_array(unique)
}

///|
fn auto_minor_step(
  unique : TickValues,
  ndivs : @config.MinorTickDivisions,
) -> Double raise @core.DataError {
  let majorstep = if unique.is_int64() {
    let first = unique.get_int64(0).reinterpret_as_uint64()
    let second = unique.get_int64(1).reinterpret_as_uint64()
    (second - first).reinterpret_as_int64().to_double()
  } else {
    unique.get(1) - unique.get(0)
  }
  let divisions = match ndivs {
    Text("auto") => {
      let logarithm = @math.log10(majorstep)
      let mantissa = @math.pow(10.0, @tick_grid.divmod(logarithm, 1.0).1)
      let mut close = false
      for reference in [1.0, 2.5, 5.0, 10.0] {
        if Double::abs(mantissa - reference) <= 1.0e-8 + 1.0e-5 * reference {
          close = true
        }
      }
      if close {
        5.0
      } else {
        4.0
      }
    }
    Text(_) =>
      raise @core.DataError::InvalidTicks(
        message="AutoMinor subdivisions text is not the exact auto token",
      )
    Number(value) => value
    Integer(value) => {
      let converted = index_round_binary(value, 0)
      if converted.is_inf() {
        raise @core.DataError::InvalidTicks(
          message="AutoMinor integer subdivisions are too large to convert to float",
        )
      }
      converted
    }
  }
  majorstep / divisions
}

///|
// Python round(x) returns an arbitrary-precision integer, ties to even.
fn auto_minor_round(value : Double) -> @bigint.BigInt raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="AutoMinor grid cannot round a non-finite phase",
    )
  }
  let (integer, exponent) = index_binary_parts(value)
  if exponent >= 0 {
    return integer << exponent
  }
  let negative = integer < @bigint.BigInt::from_int(0)
  let magnitude = if negative { integer.neg() } else { integer }
  let quotient = magnitude >> -exponent
  let remainder = magnitude - (quotient << -exponent)
  let half = @bigint.BigInt::from_int(1) << (-exponent - 1)
  let rounded = if remainder > half ||
    (remainder == half && (quotient.to_uint64() & 1UL) != 0UL) {
    quotient + @bigint.BigInt::from_int(1)
  } else {
    quotient
  }
  if negative {
    rounded.neg()
  } else {
    rounded
  }
}

///|
fn auto_minor_grid(
  unique : TickValues,
  minorstep : Double,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  // Python sorted preserves incoming NaN order: it swaps only on upper<lower.
  let (lower, upper) = if upper < lower {
    (upper, lower)
  } else {
    (lower, upper)
  }
  let origin = unique.get(0)
  let first = auto_minor_round((lower - origin) / minorstep)
  let stop = auto_minor_round((upper - origin) / minorstep) +
    @bigint.BigInt::from_int(1)
  let difference = stop - first
  // NumPy's Python-int arange computes its full length before dtype fill.
  // Conversion is independently rounded; neither a huge phase nor equal
  // binary64 endpoints means an empty integer interval.
  let count = index_round_binary(difference, 0)
  if count.is_inf() ||
    count < -9223372036854775808.0 ||
    count >= 1152921504606846976.0 {
    raise @core.DataError::InvalidTicks(
      message="AutoMinor grid array exceeds supported size",
    )
  }
  if count <= 0.0 {
    return []
  }
  let length = Double::min(count, 100000.0).to_int()
  let int_min = @bigint.BigInt::from_int64(-9223372036854775808L)
  let int_max = @bigint.BigInt::from_int64(9223372036854775807L)
  let uint_max = @bigint.BigInt::from_uint64(18446744073709551615UL)
  let integer_dtype = first >= int_min &&
    first <= int_max &&
    stop >= int_min &&
    stop <= int_max
  let float_dtype = !integer_dtype &&
    first >= int_min &&
    first <= uint_max &&
    stop >= int_min &&
    stop <= uint_max
  let start_float = index_round_binary(first, 0)
  let second_float = index_round_binary(first + @bigint.BigInt::from_int(1), 0)
  let float_step = second_float - start_float
  Array::makei(length, index => {
    let phase = if float_dtype {
      if index == 0 {
        start_float
      } else if index == 1 {
        second_float
      } else {
        numeric_arange_fill(start_float, float_step, index.to_double())
      }
    } else {
      // Both int64 and object arange enumerate exact Python integers here.
      // The float multiplication converts each element separately.
      index_round_binary(first + @bigint.BigInt::from_int(index), 0)
    }
    let scaled = phase * minorstep
    scaled + origin
  })
}
