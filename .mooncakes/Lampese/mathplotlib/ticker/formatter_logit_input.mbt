///|
priv enum NumericArrayStorage {
  Boolean(Array[Bool])
  Unsigned64(Array[UInt64])
  Objects(Array[ScalarNumber])
}

///|
/// A readonly numeric ndarray snapshot outside Float64 and Int64 tick buffers.
/// UInt64 values project to exact Python integers through get_value.
pub struct NumericArray {
  priv storage : NumericArrayStorage
}

///|
pub fn NumericArray::length(self : NumericArray) -> Int32 {
  match self.storage {
    Boolean(values) => values.length()
    Unsigned64(values) => values.length()
    Objects(values) => values.length()
  }
}

///|
pub fn NumericArray::dtype(self : NumericArray) -> String {
  match self.storage {
    Boolean(_) => "bool"
    Unsigned64(_) => "uint64"
    Objects(_) => "object"
  }
}

///|
fn NumericArray::checked_index(
  self : NumericArray,
  index : Int32,
) -> Int32 raise @core.DataError {
  let normalized = if index < 0 {
    Int64::from_int(self.length()) + Int64::from_int(index)
  } else {
    Int64::from_int(index)
  }
  if normalized < 0L || normalized >= Int64::from_int(self.length()) {
    raise @core.DataError::InvalidTicks(
      message="IndexError: index " +
        index.to_string() +
        " is out of bounds for axis 0 with size " +
        self.length().to_string(),
    )
  }
  normalized.to_int()
}

///|
pub fn NumericArray::get_value(
  self : NumericArray,
  index : Int32,
) -> ScalarNumber raise @core.DataError {
  let index = self.checked_index(index)
  match self.storage {
    Boolean(values) => ScalarNumber::NumpyBool(values[index])
    Unsigned64(values) =>
      ScalarNumber::Integer(@bigint.BigInt::from_uint64(values[index]))
    Objects(values) => values[index]
  }
}

///|
pub fn NumericArray::get(
  self : NumericArray,
  index : Int32,
) -> Double raise @core.DataError {
  scalar_numeric_double(self.get_value(index))
}

///|
/// Exact UInt64 access; other storage kinds raise a typed bridge error.
pub fn NumericArray::get_uint64(
  self : NumericArray,
  index : Int32,
) -> UInt64 raise @core.DataError {
  let index = self.checked_index(index)
  match self.storage {
    Unsigned64(values) => values[index]
    _ =>
      raise @core.DataError::InvalidTicks(
        message="numeric array is not UInt64 storage",
      )
  }
}

///|
priv enum LogitInput {
  Sequence(Array[LogitKey])
  NdArray(TickValues)
}

///|
fn LogitInput::from_array(values : Array[Double]) -> LogitInput {
  Sequence(values.map(value => LogitKey::new(ScalarNumber::Number(value))))
}

///|
fn LogitInput::from_view(values : TickValues) -> LogitInput {
  NdArray(values)
}

///|
fn LogitInput::from_keys(values : Array[LogitKey]) -> LogitInput {
  Sequence(values)
}

///|
fn LogitInput::length(self : LogitInput) -> Int32 {
  match self {
    Sequence(values) => values.length()
    NdArray(values) => values.length()
  }
}

///|
fn LogitInput::key_at(
  self : LogitInput,
  index : Int32,
) -> LogitKey raise @core.DataError {
  let normalized = if index < 0 {
    Int64::from_int(self.length()) + Int64::from_int(index)
  } else {
    Int64::from_int(index)
  }
  if normalized < 0L || normalized >= Int64::from_int(self.length()) {
    let message = match self {
      Sequence(_) => "IndexError: list index out of range"
      NdArray(_) =>
        "IndexError: index " +
        index.to_string() +
        " is out of bounds for axis 0 with size " +
        self.length().to_string()
    }
    raise @core.DataError::InvalidTicks(message~)
  }
  let index = normalized.to_int()
  match self {
    Sequence(values) => values[index]
    NdArray(values) =>
      LogitKey::new(
        if values.is_int64() {
          ScalarNumber::NumpyInt64(values.get_int64(index))
        } else {
          ScalarNumber::NumpyFloat64(values.get(index))
        },
      )
  }
}

///|
priv enum LogitArrayKind {
  Boolean
  Signed64
  Unsigned64
  Float64
  Objects
}

///|
fn logit_array_kind(value : ScalarNumber) -> LogitArrayKind {
  match value {
    Boolean(_) | NumpyBool(_) => LogitArrayKind::Boolean
    NumpyInt64(_) => LogitArrayKind::Signed64
    Number(_) | NumpyFloat64(_) => LogitArrayKind::Float64
    Integer(value) =>
      if value >= @bigint.BigInt::from_int64(-9223372036854775808L) &&
        value <= @bigint.BigInt::from_int64(9223372036854775807L) {
        LogitArrayKind::Signed64
      } else if value >= @bigint.BigInt::from_int(0) &&
        value <= @bigint.BigInt::from_uint64(18446744073709551615UL) {
        LogitArrayKind::Unsigned64
      } else {
        LogitArrayKind::Objects
      }
  }
}

///|
fn logit_array_promote(
  left : LogitArrayKind,
  right : LogitArrayKind,
) -> LogitArrayKind {
  match (left, right) {
    (Objects, _) | (_, Objects) => LogitArrayKind::Objects
    (Float64, _) | (_, Float64) => LogitArrayKind::Float64
    (Signed64, Unsigned64) | (Unsigned64, Signed64) => LogitArrayKind::Float64
    (Unsigned64, _) | (_, Unsigned64) => LogitArrayKind::Unsigned64
    (Signed64, _) | (_, Signed64) => LogitArrayKind::Signed64
    _ => LogitArrayKind::Boolean
  }
}

///|
// np.array makes an independent dtype-preserving snapshot. Original keys
// remain in LogitInput for the later ideal scan, count and set update stages.
fn LogitInput::snapshot(
  self : LogitInput,
) -> FormatterLocations raise @core.DataError {
  if self is NdArray(values) {
    return FormatterLocations::NdArray(values.copy())
  }
  let mut kind = if self.length() == 0 {
    LogitArrayKind::Float64
  } else {
    LogitArrayKind::Boolean
  }
  for index in 0..<self.length() {
    kind = logit_array_promote(
      kind,
      logit_array_kind(self.key_at(index).value()),
    )
  }
  match kind {
    Float64 => {
      let values : Array[Double] = []
      for index in 0..<self.length() {
        values.push(scalar_numeric_double(self.key_at(index).value()))
      }
      FormatterLocations::NdArray(TickValues::from_array(values))
    }
    Signed64 => {
      let values : Array[Int64] = []
      for index in 0..<self.length() {
        values.push(
          scalar_numeric_integer(self.key_at(index).value()).to_int64(),
        )
      }
      FormatterLocations::NdArray(TickValues::from_int64_array(values))
    }
    Unsigned64 => {
      let values : Array[UInt64] = []
      for index in 0..<self.length() {
        values.push(
          scalar_numeric_integer(self.key_at(index).value()).to_uint64(),
        )
      }
      FormatterLocations::Typed({
        storage: NumericArrayStorage::Unsigned64(values),
      })
    }
    Boolean => {
      let values : Array[Bool] = []
      for index in 0..<self.length() {
        values.push(scalar_numeric_truth(Some(self.key_at(index).value())))
      }
      FormatterLocations::Typed({
        storage: NumericArrayStorage::Boolean(values),
      })
    }
    Objects => {
      let values : Array[ScalarNumber] = []
      for index in 0..<self.length() {
        values.push(self.key_at(index).value())
      }
      FormatterLocations::Typed({
        storage: NumericArrayStorage::Objects(values),
      })
    }
  }
}
