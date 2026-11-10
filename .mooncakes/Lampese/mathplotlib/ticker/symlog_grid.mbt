///|
// Source Float64 arange shape. A negative region reads the full reversed
// array before power; its first eager tick can be at an enormous index.
priv struct SymLogGridRegion {
  start : Double
  second : Double
  step : Double
  length : Int64
  negative : Bool
  base : Double
  zero_count : Int64
  zero_prefix : Bool
}

///|
fn SymLogGridRegion::exponent(
  self : SymLogGridRegion,
  position : Int64,
) -> Double {
  let index = if self.negative { self.length - 1L - position } else { position }
  if index == 0L {
    self.start
  } else if index == 1L {
    self.second
  } else {
    numeric_arange_fill(self.start, self.step, index.to_double())
  }
}

///|
fn SymLogGridRegion::value(self : SymLogGridRegion, position : Int64) -> Double {
  let value = log_grid_numpy_power(self.base, self.exponent(position))
  if self.negative {
    -1.0 * value
  } else {
    value
  }
}

///|
fn symlog_grid_region(
  start : Double,
  stop : Double,
  stride : Double,
  base : Double,
  negative : Bool,
) -> SymLogGridRegion raise @core.DataError {
  if stride == 0.0 {
    raise log_grid_error("symlog grid arange step is zero")
  }
  let delta = stop - start
  let ratio = delta / stride
  if ratio.is_nan() ||
    ratio.is_inf() ||
    ratio < -9223372036854775808.0 ||
    ratio >= 9223372036854775808.0 {
    raise log_grid_error("symlog grid arange cannot compute length")
  }
  let count = if ratio == 0.0 && delta != 0.0 {
    if ratio.reinterpret_as_uint64() >> 63 == 0UL {
      1.0
    } else {
      0.0
    }
  } else {
    ratio.ceil()
  }
  if count >= 1152921504606846976.0 {
    raise log_grid_error("symlog grid arange array exceeds supported size")
  }
  let length = if count <= 0.0 { 0L } else { count.to_int64() }
  let region : SymLogGridRegion = {
    start,
    second: start + stride,
    step: start + stride - start,
    length,
    negative,
    base,
    zero_count: 0L,
    zero_prefix: false,
  }
  if length == 0L {
    return region
  }
  let first_zero = region.value(0L) == 0.0
  let last_zero = region.value(length - 1L) == 0.0
  if first_zero && last_zero {
    return { ..region, zero_count: length, zero_prefix: true, }
  }
  if !first_zero && !last_zero {
    return region
  }
  let mut first = 0L
  let mut last = length
  while first < last {
    let middle = first + (last - first) / 2L
    let zero = region.value(middle) == 0.0
    if zero == first_zero {
      first = middle + 1L
    } else {
      last = middle
    }
  }
  {
    ..region,
    zero_count: if first_zero {
      first
    } else {
      length - first
    },
    zero_prefix: first_zero,
  }
}

///|
fn SymLogGridRegion::flat_length(
  self : SymLogGridRegion,
  subs_length : Int32,
  expand : Bool,
) -> @bigint.BigInt {
  if !expand {
    return @bigint.BigInt::from_int64(self.length)
  }
  @bigint.BigInt::from_int64(self.length - self.zero_count) *
  @bigint.BigInt::from_int(subs_length) +
  @bigint.BigInt::from_int64(self.zero_count)
}

///|
fn SymLogGridRegion::flat_position(
  self : SymLogGridRegion,
  position : Int64,
  subs_length : Int32,
  expand : Bool,
) -> (Int64, Int32) {
  if !expand {
    return (position, -1)
  }
  let size = subs_length.to_int64()
  if self.zero_prefix {
    if position < self.zero_count {
      return (position, -1)
    }
    let after = position - self.zero_count
    (self.zero_count + after / size, (after % size).to_int())
  } else {
    let raw = position / size
    let nonzero = self.length - self.zero_count
    if raw < nonzero {
      (raw, (position % size).to_int())
    } else {
      (nonzero + position - nonzero * size, -1)
    }
  }
}

///|
priv enum SymLogGridPiece {
  Region(SymLogGridRegion)
  Zero
}

///|
fn named_symlog_locator_ticks(
  locator : SymmetricalLogLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  let (lower, upper) = if upper < lower {
    (upper, lower)
  } else {
    (lower, upper)
  }
  let threshold = locator.linthresh
  // Python set insertion order chooses the first equivalent signed zero.
  if -threshold <= lower && lower < upper && upper <= threshold {
    return if lower == 0.0 {
      [lower, upper]
    } else if upper == 0.0 {
      [lower, 0.0]
    } else if lower > 0.0 {
      [0.0, lower, upper]
    } else if upper < 0.0 {
      [lower, upper, 0.0]
    } else {
      [lower, 0.0, upper]
    }
  }
  let has_a = lower < -threshold
  let has_c = upper > threshold
  let has_b = (has_a && upper > -threshold) || (has_c && lower < threshold)
  let base = locator.base
  let logarithm = log_grid_natural_log(base)
  let (a_low, a_high) = if has_a {
    let limit = if upper < -threshold { upper } else { -threshold }
    (
      (log_grid_natural_log(Double::abs(limit)) / logarithm).floor(),
      (log_grid_natural_log(Double::abs(lower) + 1.0) / logarithm).ceil(),
    )
  } else {
    (0.0, 0.0)
  }
  let (c_low, c_high) = if has_c {
    let limit = if lower > threshold { lower } else { threshold }
    (
      (log_grid_natural_log(limit) / logarithm).floor(),
      (log_grid_natural_log(upper + 1.0) / logarithm).ceil(),
    )
  } else {
    (0.0, 0.0)
  }
  let total = if has_a || has_c {
    let total = a_high - a_low + (c_high - c_low)
    LogGridNumber::NumpyFloat(if has_b { total + 1.0 } else { total })
  } else {
    log_grid_integer(0)
  }
  let requested = match locator.numticks {
    Integer(value) => LogGridNumber::PythonInteger(value)
    Number(value) => PythonFloat(value)
    Text(_) => Text
  }
  let stride = log_grid_max(
    log_grid_op(total, log_grid_op(requested, log_grid_integer(1), 1), 3),
    log_grid_integer(1),
  ).floating()
  let pieces : Array[SymLogGridPiece] = []
  if has_a {
    pieces.push(Region(symlog_grid_region(a_low, a_high, stride, base, true)))
  }
  if has_b {
    pieces.push(Zero)
  }
  if has_c {
    pieces.push(Region(symlog_grid_region(c_low, c_high, stride, base, false)))
  }
  // np.asarray is consumed only after every region's arange and power.
  let subs = match locator.subs {
    Values(values) => values
    _ =>
      raise log_grid_error(
        "symlog subdivisions are a scalar and have no length",
      )
  }
  let expand = subs.length() > 1 || subs.get(0) != 1.0
  let lengths = pieces.map(piece => {
    match piece {
      Region(region) => region.flat_length(subs.length(), expand)
      Zero => @bigint.BigInt::from_int(1)
    }
  })
  let mut full_count = @bigint.BigInt::from_int(0)
  for length in lengths {
    full_count += length
  }
  if full_count >= @bigint.BigInt::from_int(1) << 60 {
    raise log_grid_error("symlog flattened array exceeds supported size")
  }
  let length = if full_count > @bigint.BigInt::from_int(100000) {
    100000
  } else {
    full_count.to_int()
  }
  let piece_index = [0]
  let local_index = [0L]
  let cached_piece = [-1]
  let cached_index = [-1L]
  let cached_phase = [0UL]
  let cached_value = [0.0]
  Array::makei(length, _ => {
    while @bigint.BigInt::from_int64(local_index[0]) >= lengths[piece_index[0]] {
      local_index[0] -= lengths[piece_index[0]].to_int64()
      piece_index[0] += 1
    }
    let piece = piece_index[0]
    let position = local_index[0]
    local_index[0] += 1L
    match pieces[piece] {
      Zero => 0.0
      Region(region) => {
        let (raw, subdivision) = region.flat_position(
          position,
          subs.length(),
          expand,
        )
        if cached_piece[0] != piece || cached_index[0] != raw {
          let phase = region.exponent(raw)
          let different = cached_piece[0] != piece ||
            phase.reinterpret_as_uint64() != cached_phase[0]
          cached_piece[0] = piece
          cached_index[0] = raw
          if different {
            cached_phase[0] = phase.reinterpret_as_uint64()
            let value = log_grid_numpy_power(region.base, phase)
            cached_value[0] = if region.negative { -1.0 * value } else { value }
          }
        }
        let value = cached_value[0]
        if subdivision < 0 {
          value
        } else {
          subs.get(subdivision) * value
        }
      }
    }
  })
}
