///|
/// Raw standard scalar inputs retain their Python and NumPy origin.
pub(all) enum LogValue {
  Numeric(ScalarNumber)
  Text(String)
  NoneValue
} derive(Debug, Eq)

///|
pub extend LogValue with @debug.Debug::{to_repr}

///|
pub extend LogValue with Eq::{equal, not_equal}

///|
/// An immutable numeric/text tuple. Construction and values() copy their arrays.
pub struct LogThresholdTuple {
  priv items : Array[LogValue]
}

///|
pub impl @debug.Debug for LogThresholdTuple with fn to_repr(self) {
  @debug.Repr::Repr(("LogThresholdTuple", self.items))
}

///|
pub extend LogThresholdTuple with @debug.Debug::{to_repr}

///|
pub impl Eq for LogThresholdTuple with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub extend LogThresholdTuple with Eq::{equal, not_equal}

///|
pub fn LogThresholdTuple::new(values : Array[LogValue]) -> LogThresholdTuple {
  { items: values.copy(), }
}

///|
pub fn LogThresholdTuple::length(self : LogThresholdTuple) -> Int32 {
  self.items.length()
}

///|
pub fn LogThresholdTuple::values(self : LogThresholdTuple) -> Array[LogValue] {
  self.items.copy()
}

///|
pub fn LogThresholdTuple::get(
  self : LogThresholdTuple,
  index : Int32,
) -> LogValue raise @core.DataError {
  let normalized = if index < 0 {
    Int64::from_int(self.items.length()) + Int64::from_int(index)
  } else {
    Int64::from_int(index)
  }
  if normalized < 0L || normalized >= Int64::from_int(self.items.length()) {
    raise @core.DataError::InvalidTicks(
      message="IndexError: tuple index out of range",
    )
  }
  self.items[normalized.to_int()]
}

///|
/// Preserve an immutable tuple, a borrowed list/view, or a raw scalar slot.
pub(all) enum LogMinorThresholds {
  Tuple(LogThresholdTuple)
  Sequence(Array[LogValue])
  NdArray(TickValues)
  Raw(LogValue)
}

///|
pub impl @debug.Debug for LogMinorThresholds with fn to_repr(self) {
  match self {
    Tuple(values) => @debug.Repr::Repr(("Tuple", values))
    Sequence(values) => @debug.Repr::Repr(("Sequence", values))
    NdArray(values) => @debug.Repr::Repr(("NdArray length", values.length()))
    Raw(value) => @debug.Repr::Repr(("Raw", value))
  }
}

///|
pub extend LogMinorThresholds with @debug.Debug::{to_repr}

///|
fn log_value_truth(value : LogValue) -> Bool {
  match value {
    NoneValue => false
    Text(value) => !value.is_empty()
    Numeric(value) => scalar_numeric_truth(Some(value))
  }
}

///|
fn log_base_float(value : LogValue) -> Double raise @core.DataError {
  match value {
    Numeric(value) => scalar_numeric_double(value)
    Text(value) => log_text_float(value)
    NoneValue =>
      raise @core.DataError::InvalidTicks(
        message="TypeError: float() argument must be a string or a real number, not 'NoneType'",
      )
  }
}

///|
fn log_threshold_at(
  thresholds : LogMinorThresholds?,
  index : Int32,
) -> LogValue raise @core.DataError {
  match thresholds {
    None =>
      raise @core.DataError::InvalidTicks(
        message="TypeError: 'NoneType' object is not subscriptable",
      )
    Some(Tuple(values)) => values.get(index)
    Some(Sequence(values)) => {
      let normalized = if index < 0 {
        Int64::from_int(values.length()) + Int64::from_int(index)
      } else {
        Int64::from_int(index)
      }
      if normalized < 0L || normalized >= Int64::from_int(values.length()) {
        raise @core.DataError::InvalidTicks(
          message="IndexError: list index out of range",
        )
      }
      values[normalized.to_int()]
    }
    Some(NdArray(values)) => {
      let length = values.length()
      let normalized = if index < 0 {
        Int64::from_int(length) + Int64::from_int(index)
      } else {
        Int64::from_int(index)
      }
      if normalized < 0L || normalized >= Int64::from_int(length) {
        raise @core.DataError::InvalidTicks(
          message="IndexError: index " +
            index.to_string() +
            " is out of bounds for axis 0 with size " +
            length.to_string(),
        )
      }
      Numeric(
        if values.is_int64() {
          ScalarNumber::NumpyInt64(values.get_int64(index))
        } else {
          ScalarNumber::NumpyFloat64(values.get(index))
        },
      )
    }
    Some(Raw(Text(text))) => {
      let characters = text.to_array()
      let normalized = if index < 0 {
        Int64::from_int(characters.length()) + Int64::from_int(index)
      } else {
        Int64::from_int(index)
      }
      if normalized < 0L || normalized >= Int64::from_int(characters.length()) {
        raise @core.DataError::InvalidTicks(
          message="IndexError: string index out of range",
        )
      }
      Text(characters[normalized.to_int()].to_string())
    }
    Some(Raw(NoneValue)) =>
      raise @core.DataError::InvalidTicks(
        message="TypeError: 'NoneType' object is not subscriptable",
      )
    Some(Raw(Numeric(NumpyFloat64(_) | NumpyInt64(_) | NumpyBool(_)))) =>
      raise @core.DataError::InvalidTicks(
        message="IndexError: invalid index to scalar variable.",
      )
    Some(Raw(Numeric(value))) => {
      let kind = match value {
        Number(_) => "float"
        Boolean(_) => "bool"
        _ => "int"
      }
      raise @core.DataError::InvalidTicks(
        message="TypeError: '" + kind + "' object is not subscriptable",
      )
    }
  }
}
