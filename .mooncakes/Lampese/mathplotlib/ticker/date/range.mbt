///|
// Python aware datetimes sharing the same tzinfo compare wall-clock fields.
// Distinct zones (and fixed-offset representations) compare actual UTC instants.
fn arithmetic_date_at_least(left : DateTime, right : DateTime) -> Bool {
  match (left.timezone, right.timezone) {
    (Some(first), Some(last)) if physical_equal(first, last) =>
      locator_microseconds(left) >= locator_microseconds(right)
    _ => rruleset_instant(left) >= rruleset_instant(right)
  }
}

///|
/// Generate equally spaced numeric dates using Matplotlib's endpoint/linspace
/// algorithm. Endpoints carry their own offsets; a retained rule zone supplies
/// wall-clock duration arithmetic across DST. This retains the upstream
/// endpoint adjustments, including negative steps and floating ceil edge cases. Zero spacing, arithmetic overflow, negative sample counts and
/// counts beyond MoonBit's Int32 array index range raise DateError.
///
/// ```mbt check
/// test {
///   let values = @date.drange(
///     @date.datetime(2011, 1, 1),
///     @date.datetime(2011, 1, 2),
///     @date.timedelta(hours=4),
///   )
///   assert_eq(values.length(), 6)
///   assert_eq(@date.num2date(values[5]).hour(), 20)
/// }
/// ```
pub fn drange(
  dstart : DateTime,
  dend : DateTime,
  delta : TimeDelta,
) -> Array[Double] raise DateError {
  // The upstream datetime -> UTC conversion cannot construct year 0/10000,
  // even though its subsequent floating ordinal may round to a day boundary.
  for value in [dstart, dend] {
    let instant = rruleset_instant(value)
    if instant < -62_135_596_800_000_000L || instant >= 253_402_300_800_000_000L {
      raise DateError::InvalidDate(
        message="drange UTC input is outside years 1..9999",
      )
    }
  }
  let first = dstart.to_ordinal()
  let stop = dend.to_ordinal()
  let step = delta.total_seconds() / 86400.0
  if step == 0.0 {
    raise DateError::InvalidDate(message="drange spacing must not be zero")
  }
  let samples = ((stop - first) / step).ceil()
  // Supported dates and microsecond spacing bound the real quotient below
  // Int64, but check before the backend's saturating float-to-int conversion.
  if samples.is_nan() ||
    samples.is_inf() ||
    samples <= -9.223372036854776e18 ||
    samples >= 9.223372036854776e18 {
    raise DateError::InvalidDate(
      message="drange sample count is not representable",
    )
  }
  let mut count = samples.to_int64()
  let mut end = dstart.add_timedelta_multiple(delta, count)
  if arithmetic_date_at_least(end, dend) {
    end = end.add_timedelta_multiple(delta, -1L)
    count -= 1L
  }
  let last_instant = rruleset_instant(end)
  if last_instant < -62_135_596_800_000_000L ||
    last_instant >= 253_402_300_800_000_000L {
    raise DateError::InvalidDate(
      message="drange UTC endpoint is outside years 1..9999",
    )
  }
  let last = end.to_ordinal()
  if count < -1L {
    raise DateError::InvalidDate(message="drange has a negative sample count")
  }
  if count >= 2147483647L {
    raise DateError::InvalidDate(
      message="drange exceeds the Int32 array index range",
    )
  }
  let size = (count + 1L).to_int()
  let result : Array[Double] = Array(capacity=size)
  if size == 0 {
    return result
  }
  if size == 1 {
    return [first]
  }
  let difference = last - first
  let interpolation_step = difference / count.to_double()
  for index in 0..<size {
    let value = if interpolation_step == 0.0 && difference != 0.0 {
      Double::from_int(index) / count.to_double() * difference
    } else {
      Double::from_int(index) * interpolation_step
    }
    result.push(value + first)
  }
  result[size - 1] = last
  result
}
