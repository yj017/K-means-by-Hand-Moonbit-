///|
/// Mutable fixed locations. new borrows an array; from_view retains its stride.
pub struct FixedLocator {
  priv locations : TickValues
  priv mut nbins : Double?
}

///|
/// Retain source order, duplicates and nonfinite locations.
///
/// ```mbt check
/// test {
///   let positions = [4.0, 1.0, 0.0, -1.0, -4.0]
///   let locator = @ticker.FixedLocator::new(positions, nbins=2.0)
///   let ticks = locator.tick_values(100.0, -100.0)
///   assert_eq(ticks.to_array(), [0.0])
///   ticks.set(0, 0.5)
///   assert_eq(positions[2], 0.5)
/// }
/// ```
pub fn FixedLocator::new(
  locations : Array[Double],
  nbins? : Double,
) -> FixedLocator {
  FixedLocator::from_view(TickValues::from_array(locations), nbins?)
}

///|
/// Borrow an existing view, retaining its base buffer, shape and signed stride.
pub fn FixedLocator::from_view(
  locations : TickValues,
  nbins? : Double,
) -> FixedLocator {
  let nbins = nbins.map(value => if value < 2.0 { 2.0 } else { value })
  { locations, nbins, }
}

///|
/// Python-list-style construction, independent from the supplied array.
pub fn FixedLocator::from_list(
  locations : Array[Double],
  nbins? : Double,
) -> FixedLocator {
  FixedLocator::new(locations.copy(), nbins?)
}

///|
/// Borrow the live locations buffer, corresponding to the source locs attribute.
pub fn FixedLocator::locations(self : FixedLocator) -> TickValues {
  self.locations
}

///|
pub fn FixedLocator::nbins(self : FixedLocator) -> Double? {
  self.nbins
}

///|
/// Omitted/None leaves nbins unchanged. Source validation is deferred to ticks.
pub fn FixedLocator::set_params(self : FixedLocator, nbins? : Double) -> Unit {
  if nbins is Some(value) {
    self.nbins = Some(value)
  }
}

///|
/// Shallow source-style copy: share locations, independently replace nbins.
pub fn FixedLocator::copy(self : FixedLocator) -> FixedLocator {
  { locations: self.locations, nbins: self.nbins, }
}

///|
fn fixed_minimum_absolute(
  locations : TickValues,
  first : Int32,
  stride : Int32,
) -> Double raise @core.DataError {
  let mut smallest = Double::abs(locations.get(first))
  let mut index = first
  while index < locations.length() {
    let candidate = Double::abs(locations.get(index))
    if candidate.is_nan() || candidate < smallest {
      smallest = candidate
    }
    if stride >= locations.length() - index {
      break
    }
    index += stride
  }
  smallest
}

///|
fn fixed_integer_absolute(value : Int64) -> Int64 {
  if value < 0L {
    (0UL - value.reinterpret_as_uint64()).reinterpret_as_int64()
  } else {
    value
  }
}

///|
// NumPy abs/min retains Int64 storage: abs(Int64.min) wraps to Int64.min.
// Comparing through Double would also collapse distinct integers above 2^53.
fn fixed_minimum_integer_absolute(
  locations : TickValues,
  first : Int32,
  stride : Int32,
) -> Int64 raise @core.DataError {
  let mut smallest = fixed_integer_absolute(locations.get_int64(first))
  let mut index = first
  while index < locations.length() {
    let candidate = fixed_integer_absolute(locations.get_int64(index))
    if candidate < smallest {
      smallest = candidate
    }
    if stride >= locations.length() - index {
      break
    }
    index += stride
  }
  smallest
}

///|
/// Ignore bounds and return a borrowed, possibly strided view.
pub fn FixedLocator::tick_values(
  self : FixedLocator,
  _lower : Double,
  _upper : Double,
) -> TickValues raise @core.DataError {
  guard self.nbins is Some(nbins) else { return self.locations }
  if nbins == 0.0 {
    raise @core.DataError::InvalidTicks(
      message="fixed locator nbins divides by zero",
    )
  }
  let stride = (Double::from_int(self.locations.length()) / nbins).ceil()
  if stride.is_nan() || stride.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="fixed locator subsampling stride is not an integer",
    )
  }
  let stride = if stride < 1.0 { 1.0 } else { stride }
  if stride > Double::from_int(self.locations.length()) && stride > 1.0 {
    raise @core.DataError::InvalidTicks(
      message="fixed locator empty subsample has no minimum",
    )
  }
  let stride = stride.to_int()
  let mut first = 0
  if stride > 1 {
    if self.locations.is_int64() {
      let mut smallest = fixed_minimum_integer_absolute(
        self.locations,
        0,
        stride,
      )
      for candidate in 1..<stride {
        let minimum = fixed_minimum_integer_absolute(
          self.locations,
          candidate,
          stride,
        )
        if minimum < smallest {
          first = candidate
          smallest = minimum
        }
      }
    } else {
      let mut smallest = fixed_minimum_absolute(self.locations, 0, stride)
      for candidate in 1..<stride {
        let minimum = fixed_minimum_absolute(self.locations, candidate, stride)
        if minimum < smallest {
          first = candidate
          smallest = minimum
        }
      }
    }
  }
  let length = if first >= self.locations.length() {
    0
  } else {
    1 + (self.locations.length() - 1 - first) / stride
  }
  self.locations.view(first, stride, length)
}

///|
/// Source __call__ without an axis binding: locations never depend on bounds.
pub fn FixedLocator::values(
  self : FixedLocator,
) -> TickValues raise @core.DataError {
  self.tick_values(0.0, 0.0)
}

///|
pub fn FixedLocator::nonsingular(
  _self : FixedLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.05)
}

///|
pub fn FixedLocator::view_limits(
  _self : FixedLocator,
  lower : Double,
  upper : Double,
) -> (Double, Double) {
  locator_nonsingular(lower, upper, 0.001)
}
