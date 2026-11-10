///|
fn log_grid_numpy_power(base : Double, exponent : Double) -> Double {
  if exponent == 0.0 || base == 1.0 || (base == -1.0 && exponent.is_inf()) {
    1.0
  } else if !base.is_nan() &&
    !base.is_inf() &&
    base != 0.0 &&
    !exponent.is_nan() &&
    !exponent.is_inf() &&
    exponent == exponent.floor() {
    log_grid_integer_power(base, exponent)
  } else {
    @math.pow(base, exponent)
  }
}

///|
fn log_decade_less_equal(value : Double, base : Double) -> Double {
  if value == 0.0 {
    value
  } else if value < 0.0 {
    -log_decade_greater_equal(-value, base)
  } else {
    log_grid_numpy_power(
      base,
      (log_grid_natural_log(value) / log_grid_natural_log(base)).floor(),
    )
  }
}

///|
fn log_decade_greater_equal(value : Double, base : Double) -> Double {
  if value == 0.0 {
    value
  } else if value < 0.0 {
    -log_decade_less_equal(-value, base)
  } else {
    log_grid_numpy_power(
      base,
      (log_grid_natural_log(value) / log_grid_natural_log(base)).ceil(),
    )
  }
}

///|
fn log_decade_less(value : Double, base : Double) -> Double {
  if value < 0.0 {
    return -log_decade_greater(-value, base)
  }
  let lower = log_decade_less_equal(value, base)
  if lower == value {
    lower / base
  } else {
    lower
  }
}

///|
fn log_decade_greater(value : Double, base : Double) -> Double {
  if value < 0.0 {
    return -log_decade_less(-value, base)
  }
  let upper = log_decade_greater_equal(value, base)
  if upper == value {
    upper * base
  } else {
    upper
  }
}

///|
fn log_grid_log(value : Double, base : Double) -> Double {
  if base == 10.0 {
    @math.log10(value)
  } else if base == 2.0 {
    @math.log2(value)
  } else {
    @math.ln(value) / @math.ln(base)
  }
}

///|
priv struct LogGridDecades {
  start : @bigint.BigInt
  step : @bigint.BigInt
  length : @bigint.BigInt
  // 0=int64, 1=float64, 2=object, 3=uint64. Whole shape decides dtype.
  dtype : Int32
  arange : Bool
}

///|
fn log_grid_array_dtype(low : @bigint.BigInt, high : @bigint.BigInt) -> Int32 {
  let min_int = @bigint.BigInt::from_int64(-9223372036854775808L)
  let max_int = @bigint.BigInt::from_int64(9223372036854775807L)
  let max_uint = @bigint.BigInt::from_uint64(18446744073709551615UL)
  if low < min_int || high > max_uint {
    2
  } else if high > max_int {
    if low <= max_int {
      1
    } else {
      3
    }
  } else {
    0
  }
}

///|
fn log_grid_decades(
  start : LogGridNumber,
  stop : LogGridNumber,
  step : LogGridNumber,
  arange : Bool,
) -> LogGridDecades raise @core.DataError {
  let start = start.integer()
  let stop = stop.integer()
  let step = step.integer()
  if step.is_zero() {
    raise log_grid_error("log decade range step is zero")
  }
  let zero = @bigint.BigInt::from_int(0)
  let distance = stop - start
  let length = if arange {
    let ratio = log_grid_integer_ratio(distance, step)
    if ratio < -9223372036854775808.0 || ratio >= 1152921504606846976.0 {
      raise log_grid_error("log decade arange exceeds array size")
    }
    if ratio <= 0.0 {
      zero
    } else {
      auto_minor_round(ratio.ceil())
    }
  } else if (distance > zero && step > zero) || (distance < zero && step < zero) {
    let a = if distance < zero { distance.neg() } else { distance }
    let b = if step < zero { step.neg() } else { step }
    (a + b - @bigint.BigInt::from_int(1)) / b
  } else {
    zero
  }
  let dtype = if arange {
    let low = if start < stop {
      if start < step {
        start
      } else {
        step
      }
    } else if stop < step {
      stop
    } else {
      step
    }
    let high = if start > stop {
      if start > step {
        start
      } else {
        step
      }
    } else if stop > step {
      stop
    } else {
      step
    }
    let inferred = log_grid_array_dtype(low, high)
    if inferred == 3 {
      1
    } else {
      inferred
    }
  } else if length.is_zero() {
    1
  } else {
    let last = start + (length - @bigint.BigInt::from_int(1)) * step
    log_grid_array_dtype(
      if start < last {
        start
      } else {
        last
      },
      if start > last {
        start
      } else {
        last
      },
    )
  }
  { start, step, length, dtype, arange, }
}

///|
fn LogGridDecades::phase(self : LogGridDecades, index : Int32) -> Double {
  if self.arange && self.dtype == 1 {
    let first = index_round_binary(self.start, 0)
    let second = index_round_binary(self.start + self.step, 0)
    if index == 0 {
      first
    } else if index == 1 {
      second
    } else {
      numeric_arange_fill(first, second - first, index.to_double())
    }
  } else {
    index_round_binary(
      self.start + @bigint.BigInt::from_int(index) * self.step,
      0,
    )
  }
}

///|
fn log_grid_python_power(
  base : Double,
  exponent : Double,
) -> Double raise @core.DataError {
  if base == 0.0 && exponent < 0.0 {
    raise log_grid_error("log grid zero cannot be raised to a negative power")
  }
  let value = log_grid_numpy_power(base, exponent)
  if !base.is_inf() && !base.is_nan() && value.is_inf() {
    raise log_grid_error("log grid Python power overflows")
  }
  value
}

///|
fn log_grid_major_ticks(
  decades : LogGridDecades,
  base : Double,
) -> Array[Double] raise @core.DataError {
  if decades.length >= @bigint.BigInt::from_int(1) << 60 {
    raise log_grid_error("log grid decade array exceeds supported size")
  }
  if decades.length.is_zero() {
    return []
  }
  // Object power executes Python float power for every exponent. Validate both
  // ends before materializing a prefix, so an overflow beyond the cap survives.
  if decades.dtype == 2 {
    ignore(log_grid_python_power(base, index_round_binary(decades.start, 0)))
    let last = decades.start +
      (decades.length - @bigint.BigInt::from_int(1)) * decades.step
    ignore(log_grid_python_power(base, index_round_binary(last, 0)))
  }
  let length = if decades.length > @bigint.BigInt::from_int(100000) {
    100000
  } else {
    decades.length.to_int()
  }
  let cached_phase = [decades.phase(0).reinterpret_as_uint64()]
  let first = if decades.dtype == 2 {
    log_grid_python_power(base, decades.phase(0))
  } else {
    log_grid_numpy_power(base, decades.phase(0))
  }
  let cached_power = [first]
  Array::makei(length, index => {
    let exponent = decades.phase(index)
    if exponent.reinterpret_as_uint64() != cached_phase[0] {
      cached_phase[0] = exponent.reinterpret_as_uint64()
      cached_power[0] = if decades.dtype == 2 {
        log_grid_python_power(base, exponent)
      } else {
        log_grid_numpy_power(base, exponent)
      }
    }
    cached_power[0]
  })
}

///|
priv struct LogGridSubs {
  values : TickValues?
  first : Double
  length : Int64
}

///|
fn LogGridSubs::get(
  self : LogGridSubs,
  index : Int64,
) -> Double raise @core.DataError {
  match self.values {
    Some(values) => values.get(index.to_int())
    None => self.first + index.to_double()
  }
}

///|
fn LogGridSubs::visible_count(
  self : LogGridSubs,
  power : Double,
  lower : Double,
  upper : Double,
  stop_after : Int32,
) -> Int32 raise @core.DataError {
  match self.values {
    Some(values) => {
      let mut count = 0
      for index in 0..<values.length() {
        let value = values.get(index) * power
        if lower <= value && value <= upper {
          count += 1
          if count == stop_after {
            break
          }
        }
      }
      count
    }
    None => {
      if power.is_nan() || power <= 0.0 || power.is_inf() {
        return 0
      }
      let boundary = fn(target : Double, strict : Bool) {
        let mut first = 0L
        let mut last = self.length
        while first < last {
          let middle = first + (last - first) / 2L
          let value = (self.first + middle.to_double()) * power
          let after = if strict { value > target } else { value >= target }
          if after {
            last = middle
          } else {
            first = middle + 1L
          }
        }
        first
      }
      Int64::min(
        boundary(upper, true) - boundary(lower, false),
        stop_after.to_int64(),
      ).to_int()
    }
  }
}

///|
fn named_log_locator_ticks(
  locator : LogLocator,
  lower : Double,
  upper : Double,
) -> Array[Double] raise @core.DataError {
  let zero = log_grid_integer(0)
  let one = log_grid_integer(1)
  let mut requested = match locator.numticks {
    Integer(value) => LogGridNumber::PythonInteger(value)
    Number(value) => PythonFloat(value)
    Text("auto") =>
      if locator.is_bound() {
        match locator.tick_space_provider {
          Some(provider) => log_grid_space(provider())
          None =>
            raise log_grid_error("bound log locator has no tick-space provider")
        }
      } else {
        log_grid_integer(9)
      }
    Text(_) => Text
  }
  let base = locator.base
  let mut lower = lower
  let mut upper = upper
  if lower <= 0.0 {
    if locator.is_bound() {
      lower = match locator.minpos_provider {
        Some(provider) => provider()
        None =>
          raise log_grid_error(
            "bound log locator has no minimum-positive provider",
          )
      }
    }
    if lower <= 0.0 || lower.is_nan() || lower.is_inf() {
      raise log_grid_error(
        "data cannot be log-scaled because all values are nonpositive",
      )
    }
  }
  if upper < lower {
    let previous = lower
    lower = upper
    upper = previous
  }
  let efmin = log_grid_log(lower, base)
  let efmax = log_grid_log(upper, base)
  let emin = LogGridNumber::PythonInteger(auto_minor_round(efmin.ceil()))
  let emax = LogGridNumber::PythonInteger(auto_minor_round(efmax.floor()))
  let available = log_grid_op(log_grid_op(emax, emin, 1), one, 0)
  let subs = match locator.subs {
    Values(values) =>
      LogGridSubs::{
        values: Some(values),
        first: 0.0,
        length: values.length().to_int64(),
      }
    Text(value) =>
      if log_grid_compare(available, log_grid_integer(10)) is Some(0 | 1) ||
        base < 3.0 {
        if value == "auto" {
          return []
        }
        LogGridSubs::{ values: None, first: 1.0, length: 1L, }
      } else {
        let first = if value == "auto" { 2.0 } else { 1.0 }
        let count = (base - first).ceil()
        if count.is_nan() ||
          count.is_inf() ||
          count < -9223372036854775808.0 ||
          count >= 1152921504606846976.0 {
          raise log_grid_error(
            "log automatic subs arange exceeds supported size",
          )
        }
        LogGridSubs::{
          values: None,
          first,
          length: if count <= 0.0 {
            0L
          } else {
            count.to_int64()
          },
        }
      }
  }
  let mut stride : LogGridNumber = one
  let decades = if @config.classic_mode() {
    stride = log_grid_max(
      log_grid_ceil(
        log_grid_divide(
          log_grid_op(available, one, 1),
          log_grid_op(requested, one, 1),
        ),
      ),
      one,
    )
    log_grid_decades(
      log_grid_op(emin, stride, 1),
      log_grid_op(log_grid_op(emax, stride, 0), one, 0),
      stride,
      true,
    )
  } else {
    stride = log_grid_op(
      log_grid_op(available, log_grid_op(requested, one, 0), 3),
      one,
      0,
    )
    let actual = log_grid_ceil(log_grid_divide(available, stride))
    if log_grid_compare(actual, requested) is Some(-1 | 0) {
      requested = actual
    } else if !(log_grid_compare(actual, log_grid_op(requested, one, 0))
      is Some(0)) {
      raise log_grid_error("log grid requested tick assertion failed")
    }
    if log_grid_compare(requested, zero) is Some(0) {
      let first = log_grid_op(emin, one, 1)
      let last = log_grid_op(emax, one, 0)
      stride = log_grid_op(last, first, 1)
      // The source uses a list here, rather than range with this stride.
      LogGridDecades::{
        start: first.integer(),
        step: stride.integer(),
        length: @bigint.BigInt::from_int(2),
        dtype: log_grid_array_dtype(first.integer(), last.integer()),
        arange: false,
      }
    } else if log_grid_compare(requested, one) is Some(0) {
      let mid = LogGridNumber::PythonInteger(
        auto_minor_round((efmin + efmax) / 2.0),
      )
      stride = log_grid_max(
        log_grid_op(mid, log_grid_op(emin, one, 1), 1),
        log_grid_op(log_grid_op(emax, one, 0), mid, 1),
      )
      let first = log_grid_op(mid, stride, 1).integer()
      let last = log_grid_op(mid, stride, 0).integer()
      LogGridDecades::{
        start: first,
        step: stride.integer(),
        length: @bigint.BigInt::from_int(3),
        dtype: log_grid_array_dtype(
          if first < last {
            first
          } else {
            last
          },
          if first > last {
            first
          } else {
            last
          },
        ),
        arange: false,
      }
    } else {
      stride = log_grid_op(
        log_grid_op(available, one, 1),
        log_grid_op(requested, one, 1),
        3,
      )
      if log_grid_compare(stride, log_grid_divide(available, requested))
        is Some(-1) {
        stride = log_grid_op(available, requested, 3)
      }
      let low = log_grid_max(
        log_grid_op(available, log_grid_op(stride, requested, 2), 1),
        zero,
      )
      let high = log_grid_min(
        log_grid_op(
          available,
          log_grid_op(stride, log_grid_op(requested, one, 1), 2),
          1,
        ),
        stride,
      )
      let mut offset = log_grid_op(log_grid_op(zero, emin, 1), stride, 4)
      if !(log_grid_compare(low, offset) is Some(-1 | 0) &&
        log_grid_compare(offset, high) is Some(-1)) {
        offset = low
      }
      log_grid_decades(
        log_grid_op(log_grid_op(emin, offset, 0), stride, 1),
        log_grid_op(log_grid_op(emax, stride, 0), one, 0),
        stride,
        false,
      )
    }
  }
  let is_minor = subs.length > 1L || (subs.length == 1L && subs.get(0L) != 1.0)
  if !is_minor {
    return log_grid_major_ticks(decades, base)
  }
  let stride_one = log_grid_compare(stride, one) is Some(0)
  let mut first_exponent = @bigint.BigInt::from_int(0)
  let mut minor_decades = @bigint.BigInt::from_int(0)
  if stride_one || log_grid_compare(available, one) is Some(-1 | 0) {
    first_exponent = log_grid_op(emin, one, 1).integer()
    minor_decades = log_grid_op(available, one, 0).integer()
    if minor_decades <= @bigint.BigInt::from_int(0) {
      raise log_grid_error("log minor concatenate needs at least one array")
    }
    ignore(log_grid_python_power(base, index_round_binary(first_exponent, 0)))
    ignore(
      log_grid_python_power(
        base,
        index_round_binary(
          first_exponent + minor_decades - @bigint.BigInt::from_int(1),
          0,
        ),
      ),
    )
  }
  let full_count = minor_decades * @bigint.BigInt::from_int64(subs.length)
  if full_count >= @bigint.BigInt::from_int(1) << 60 {
    raise log_grid_error("log minor array exceeds supported size")
  }
  // The source decides fallback using the entire grid. A prefix can contain
  // no visible tick while a later subdivision supplies the deciding one.
  if subs.length > 1L && stride_one {
    let major_count = decades.length - @bigint.BigInt::from_int(2)
    if major_count <= @bigint.BigInt::from_int(1) {
      let mut visible = @bigint.BigInt::from_int(0)
      let mut decade = @bigint.BigInt::from_int(0)
      while decade < minor_decades &&
            major_count + visible <= @bigint.BigInt::from_int(1) {
        let power = log_grid_python_power(
          base,
          index_round_binary(first_exponent + decade, 0),
        )
        let needed = (@bigint.BigInt::from_int(2) - major_count - visible).to_int()
        visible += @bigint.BigInt::from_int(
          subs.visible_count(power, lower, upper, needed),
        )
        decade += @bigint.BigInt::from_int(1)
      }
      if major_count + visible <= @bigint.BigInt::from_int(1) {
        return AutoLocator::new().tick_values(lower, upper)
      }
    }
  }
  let length = if full_count > @bigint.BigInt::from_int(100000) {
    100000
  } else {
    full_count.to_int()
  }
  let cached_decade = [-1L]
  let cached_power = [0.0]
  Array::makei(length, index => {
    let decade = index.to_int64() / subs.length
    let position = index.to_int64() % subs.length
    if decade != cached_decade[0] {
      cached_decade[0] = decade
      cached_power[0] = log_grid_python_power(
        base,
        index_round_binary(
          first_exponent + @bigint.BigInt::from_int64(decade),
          0,
        ),
      )
    }
    subs.get(position) * cached_power[0]
  })
}
