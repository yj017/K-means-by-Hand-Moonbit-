///|
/// A mutable one-dimensional tick view over a shared numeric buffer.
/// Locations and preset results retain their source buffer and stride.
pub struct TickValues {
  priv buffer : TickBuffer
  priv start : Int32
  priv stride : Int64
  priv length : Int32
}

///|
priv enum TickBuffer {
  Float64(Array[Double])
  Integer64(Array[Int64])
}

///|
fn TickBuffer::length(self : TickBuffer) -> Int32 {
  match self {
    Float64(values) => values.length()
    Integer64(values) => values.length()
  }
}

///|
/// Borrow Int64 storage. Fractional assignments truncate; nonfinite or overflow
/// assignments raise DataError. Views and copies retain the storage type.
pub fn TickValues::from_int64_array(values : Array[Int64]) -> TickValues {
  { buffer: Integer64(values), start: 0, stride: 1L, length: values.length(), }
}

///|
fn TickValues::is_int64(self : TickValues) -> Bool {
  self.buffer is Integer64(_)
}

///|
fn tick_integer_value(value : Double) -> Int64 raise @core.DataError {
  if value.is_nan() ||
    value.is_inf() ||
    value < -9223372036854775808.0 ||
    value >= 9223372036854775808.0 {
    raise @core.DataError::InvalidTicks(
      message="tick value cannot be assigned to an Int64 buffer",
    )
  }
  value.to_int64()
}

///|
fn TickValues::with_endpoints(
  self : TickValues,
  prepend : Bool,
  append : Bool,
) -> TickValues raise @core.DataError {
  if self.is_int64() {
    let integers : Array[Int64] = []
    if prepend {
      integers.push(1L)
    }
    for index in 0..<self.length {
      integers.push(self.get_int64(index))
    }
    if append {
      integers.push(10L)
    }
    TickValues::from_int64_array(integers)
  } else {
    let values : Array[Double] = []
    if prepend {
      values.push(1.0)
    }
    for index in 0..<self.length {
      values.push(self.get(index))
    }
    if append {
      values.push(10.0)
    }
    TickValues::from_array(values)
  }
}

///|
fn TickValues::get_int64(
  self : TickValues,
  index : Int32,
) -> Int64 raise @core.DataError {
  let index = self.buffer_index(index)
  match self.buffer {
    Integer64(values) => values[index]
    Float64(_) =>
      raise @core.DataError::InvalidTicks(
        message="tick buffer is not Int64 storage",
      )
  }
}

///|
/// Borrow the current shape of an array without copying its values.
pub fn TickValues::from_array(values : Array[Double]) -> TickValues {
  tick_values_view(values, 0, 1, values.length())
}

///|
fn tick_values_view(
  buffer : Array[Double],
  start : Int32,
  stride : Int32,
  length : Int32,
) -> TickValues {
  { buffer: Float64(buffer), start, stride: Int64::from_int(stride), length, }
}

///|
pub fn TickValues::length(self : TickValues) -> Int32 {
  self.length
}

///|
fn TickValues::buffer_index(
  self : TickValues,
  index : Int32,
) -> Int32 raise @core.DataError {
  let index = if index < 0 { self.length + index } else { index }
  if index < 0 || index >= self.length {
    raise @core.DataError::InvalidTicks(
      message="tick view index is out of bounds",
    )
  }
  let position = Int64::from_int(self.start) +
    Int64::from_int(index) * self.stride
  if position < 0L || position >= Int64::from_int(self.buffer.length()) {
    raise @core.DataError::InvalidTicks(
      message="tick view buffer shape has changed",
    )
  }
  position.to_int()
}

///|
/// Borrow a strided portion of this view, retaining its original buffer.
/// A negative start counts from the end; a negative stride reverses direction.
pub fn TickValues::view(
  self : TickValues,
  start : Int32,
  stride : Int32,
  length : Int32,
) -> TickValues raise @core.DataError {
  if length < 0 {
    raise @core.DataError::InvalidTicks(
      message="tick view length must be nonnegative",
    )
  }
  if length == 0 {
    return { buffer: self.buffer, start: 0, stride: 1L, length: 0, }
  }
  let start = if start < 0 { self.length + start } else { start }
  let end = Int64::from_int(start) +
    Int64::from_int(stride) * Int64::from_int(length - 1)
  if start < 0 ||
    start >= self.length ||
    end < 0L ||
    end >= Int64::from_int(self.length) {
    raise @core.DataError::InvalidTicks(
      message="tick view extends beyond its parent",
    )
  }
  let buffer_start = self.buffer_index(start)
  ignore(self.buffer_index(end.to_int()))
  let buffer_stride = if length == 1 {
    0L
  } else {
    self.stride * Int64::from_int(stride)
  }
  { buffer: self.buffer, start: buffer_start, stride: buffer_stride, length, }
}

///|
/// Read an element, with negative indices counted from the view's end.
pub fn TickValues::get(
  self : TickValues,
  index : Int32,
) -> Double raise @core.DataError {
  let index = self.buffer_index(index)
  match self.buffer {
    Float64(values) => values[index]
    Integer64(values) => values[index].to_double()
  }
}

///|
pub fn TickValues::set(
  self : TickValues,
  index : Int32,
  value : Double,
) -> Unit raise @core.DataError {
  let index = self.buffer_index(index)
  match self.buffer {
    Float64(values) => values[index] = value
    Integer64(values) => values[index] = tick_integer_value(value)
  }
}

///|
/// Materialize an independent array containing every view element.
pub fn TickValues::to_array(
  self : TickValues,
) -> Array[Double] raise @core.DataError {
  let result = Array(capacity=self.length)
  for index in 0..<self.length {
    result.push(self.get(index))
  }
  result
}

///|
/// Copy the view values into an independent contiguous buffer.
pub fn TickValues::copy(self : TickValues) -> TickValues raise @core.DataError {
  match self.buffer {
    Float64(_) => TickValues::from_array(self.to_array())
    Integer64(values) => {
      let copied : Array[Int64] = []
      for index in 0..<self.length {
        copied.push(values[self.buffer_index(index)])
      }
      TickValues::from_int64_array(copied)
    }
  }
}

///|
/// Select a fresh contiguous array while preserving the source storage type.
/// The boolean mask must have exactly this view's fixed shape.
pub fn TickValues::select_mask(
  self : TickValues,
  mask : Array[Bool],
) -> TickValues raise @core.DataError {
  if mask.length() != self.length {
    raise @core.DataError::InvalidTicks(
      message="tick selection mask shape differs from its view",
    )
  }
  match self.buffer {
    Integer64(_) => {
      let selected : Array[Int64] = []
      for index in 0..<self.length {
        if mask[index] {
          selected.push(self.get_int64(index))
        }
      }
      TickValues::from_int64_array(selected)
    }
    Float64(_) => {
      let selected : Array[Double] = []
      for index in 0..<self.length {
        if mask[index] {
          selected.push(self.get(index))
        }
      }
      TickValues::from_array(selected)
    }
  }
}

///|
fn TickValues::eager_prefix(
  self : TickValues,
) -> Array[Double] raise @core.DataError {
  let length = Int32::min(self.length, 100000)
  let result = Array(capacity=length)
  for index in 0..<length {
    result.push(self.get(index))
  }
  result
}
