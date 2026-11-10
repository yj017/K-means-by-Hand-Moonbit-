///|
/// A one-dimensional floating-point array with an explicit boolean mask.
///
/// Masked values remain in `values` so callers can preserve source data, while
/// plotting adapters use `to_array` to replace masked entries with NaN.
pub struct MaskedArray {
  priv values : Array[Double]
  priv mask : Array[Bool]
}

///|
fn nan_value() -> Double {
  0.0 / 0.0
}

///|
fn mask_or_invalid(value : Double, masked : Bool) -> Bool {
  masked || value.is_nan() || value.is_inf()
}

///|
/// Construct a masked array. An omitted mask means that every value is
/// initially unmasked; an explicit mask must have the same length as `values`.
pub fn masked_array(
  values : Array[Double],
  mask? : Array[Bool],
) -> MaskedArray raise MaskError {
  let actual_mask = match mask {
    None => {
      let result = Array(capacity=values.length())
      for _ in values {
        result.push(false)
      }
      result
    }
    Some(mask) => {
      if mask.length() != values.length() {
        raise MaskError::InvalidShape(
          message="masked array mask must have the same length as values",
        )
      }
      mask.copy()
    }
  }
  { values: values.copy(), mask: actual_mask, }
}

///|
/// Number of entries in a masked array.
pub fn MaskedArray::length(self : MaskedArray) -> Int32 {
  self.values.length()
}

///|
/// Return a copy of the source values, including values that are masked.
pub fn MaskedArray::values(self : MaskedArray) -> Array[Double] {
  self.values.copy()
}

///|
/// Return a copy of the explicit boolean mask.
pub fn MaskedArray::mask(self : MaskedArray) -> Array[Bool] {
  self.mask.copy()
}

///|
/// Whether the entry at `index` is explicitly masked.
pub fn MaskedArray::is_masked(self : MaskedArray, index : Int32) -> Bool {
  self.mask[index]
}

///|
/// Number of entries that are not explicitly masked.
pub fn MaskedArray::count(self : MaskedArray) -> Int32 {
  let mut result = 0
  for masked in self.mask {
    if !masked {
      result += 1
    }
  }
  result
}

///|
/// Whether every entry is explicitly masked.
pub fn MaskedArray::all_masked(self : MaskedArray) -> Bool {
  self.count() == 0
}

///|
/// Replace masked entries with `fill_value` and return an independent array.
pub fn MaskedArray::filled(
  self : MaskedArray,
  fill_value : Double,
) -> Array[Double] {
  let result = Array(capacity=self.length())
  for index in 0..<self.length() {
    result.push(if self.mask[index] { fill_value } else { self.values[index] })
  }
  result
}

///|
/// Convert masked entries to NaN, the representation consumed by plotters.
pub fn MaskedArray::to_array(self : MaskedArray) -> Array[Double] {
  self.filled(nan_value())
}

///|
/// Return unmasked entries in their original order.
pub fn MaskedArray::compressed(self : MaskedArray) -> Array[Double] {
  let result = Array(capacity=self.count())
  for index in 0..<self.length() {
    if !self.mask[index] {
      result.push(self.values[index])
    }
  }
  result
}

///|
/// Return finite and unmasked entries in their original order.
pub fn MaskedArray::finite_values(self : MaskedArray) -> Array[Double] {
  let result = Array(capacity=self.count())
  for index in 0..<self.length() {
    let value = self.values[index]
    if !self.mask[index] && !value.is_nan() && !value.is_inf() {
      result.push(value)
    }
  }
  result
}

///|
/// Apply a function while preserving the mask and masking invalid results.
pub fn MaskedArray::map(
  self : MaskedArray,
  f : (Double) -> Double,
) -> MaskedArray {
  let values = Array(capacity=self.length())
  let mask = Array(capacity=self.length())
  for index in 0..<self.length() {
    let original_mask = self.mask[index]
    let value = if original_mask {
      self.values[index]
    } else {
      f(self.values[index])
    }
    values.push(value)
    mask.push(mask_or_invalid(value, original_mask))
  }
  { values, mask, }
}

///|
/// Combine two masked arrays elementwise. The result mask is the OR of both
/// masks and any invalid result.
pub fn MaskedArray::zip_map(
  self : MaskedArray,
  other : MaskedArray,
  f : (Double, Double) -> Double,
) -> MaskedArray raise DataError {
  if self.length() != other.length() {
    raise DataError::LengthMismatch(
      expected=self.length(),
      actual=other.length(),
    )
  }
  let values = Array(capacity=self.length())
  let mask = Array(capacity=self.length())
  for index in 0..<self.length() {
    let combined_mask = self.mask[index] || other.mask[index]
    let value = if combined_mask {
      self.values[index]
    } else {
      f(self.values[index], other.values[index])
    }
    values.push(value)
    mask.push(mask_or_invalid(value, combined_mask))
  }
  { values, mask, }
}
