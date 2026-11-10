///|
/// A rectangular two-dimensional floating-point array with an explicit mask.
pub struct MaskedMatrix {
  priv values : Array[Array[Double]]
  priv mask : Array[Array[Bool]]
}

///|
fn validate_matrix_values(
  values : Array[Array[Double]],
) -> Int32 raise MaskError {
  if values.length() == 0 {
    0
  } else {
    let columns = values[0].length()
    for row in values {
      if row.length() != columns {
        raise MaskError::InvalidShape(
          message="masked matrix rows must have equal length",
        )
      }
    }
    columns
  }
}

///|
fn copy_bool_matrix(mask : Array[Array[Bool]]) -> Array[Array[Bool]] {
  let result = Array(capacity=mask.length())
  for row in mask {
    result.push(row.copy())
  }
  result
}

///|
fn empty_mask_matrix(rows : Int32, columns : Int32) -> Array[Array[Bool]] {
  let result = Array(capacity=rows)
  for _ in 0..<rows {
    let row = Array(capacity=columns)
    for _ in 0..<columns {
      row.push(false)
    }
    result.push(row)
  }
  result
}

///|
/// Construct a rectangular masked matrix. An omitted mask leaves every cell
/// unmasked; an explicit mask must have the same rectangular shape as values.
pub fn masked_matrix(
  values : Array[Array[Double]],
  mask? : Array[Array[Bool]],
) -> MaskedMatrix raise MaskError {
  let columns = validate_matrix_values(values)
  let actual_mask = match mask {
    None => empty_mask_matrix(values.length(), columns)
    Some(mask) => {
      if mask.length() != values.length() {
        raise MaskError::InvalidShape(
          message="masked matrix mask must have the same row count as values",
        )
      }
      for row in mask {
        if row.length() != columns {
          raise MaskError::InvalidShape(
            message="masked matrix mask rows must match values",
          )
        }
      }
      copy_bool_matrix(mask)
    }
  }
  let copied_values = Array(capacity=values.length())
  for row in values {
    copied_values.push(row.copy())
  }
  { values: copied_values, mask: actual_mask, }
}

///|
/// Number of matrix rows.
pub fn MaskedMatrix::rows(self : MaskedMatrix) -> Int32 {
  self.values.length()
}

///|
/// Number of matrix columns.
pub fn MaskedMatrix::columns(self : MaskedMatrix) -> Int32 {
  if self.values.length() == 0 {
    0
  } else {
    self.values[0].length()
  }
}

///|
/// Return a deep copy of the source matrix.
pub fn MaskedMatrix::values(self : MaskedMatrix) -> Array[Array[Double]] {
  let result = Array(capacity=self.rows())
  for row in self.values {
    result.push(row.copy())
  }
  result
}

///|
/// Return a deep copy of the explicit mask matrix.
pub fn MaskedMatrix::mask(self : MaskedMatrix) -> Array[Array[Bool]] {
  copy_bool_matrix(self.mask)
}

///|
/// Whether one matrix cell is explicitly masked.
pub fn MaskedMatrix::is_masked(
  self : MaskedMatrix,
  row : Int32,
  column : Int32,
) -> Bool {
  self.mask[row][column]
}

///|
/// Number of unmasked matrix cells.
pub fn MaskedMatrix::count(self : MaskedMatrix) -> Int32 {
  let mut result = 0
  for row in self.mask {
    for masked in row {
      if !masked {
        result += 1
      }
    }
  }
  result
}

///|
/// Replace masked cells with `fill_value` and return a deep copy.
pub fn MaskedMatrix::filled(
  self : MaskedMatrix,
  fill_value : Double,
) -> Array[Array[Double]] {
  let result = Array(capacity=self.rows())
  for row in 0..<self.rows() {
    let values = Array(capacity=self.columns())
    for column in 0..<self.columns() {
      values.push(
        if self.mask[row][column] {
          fill_value
        } else {
          self.values[row][column]
        },
      )
    }
    result.push(values)
  }
  result
}

///|
/// Convert masked cells to NaN for plotting adapters.
pub fn MaskedMatrix::to_array(self : MaskedMatrix) -> Array[Array[Double]] {
  self.filled(nan_value())
}

///|
/// Return finite and unmasked cells in row-major order.
pub fn MaskedMatrix::finite_values(self : MaskedMatrix) -> Array[Double] {
  let result = Array(capacity=self.count())
  for row in 0..<self.rows() {
    for column in 0..<self.columns() {
      let value = self.values[row][column]
      if !self.mask[row][column] && !value.is_nan() && !value.is_inf() {
        result.push(value)
      }
    }
  }
  result
}

///|
/// Apply a function elementwise while preserving and extending the mask.
pub fn MaskedMatrix::map(
  self : MaskedMatrix,
  f : (Double) -> Double,
) -> MaskedMatrix {
  let values = Array(capacity=self.rows())
  let mask = Array(capacity=self.rows())
  for row in 0..<self.rows() {
    let value_row = Array(capacity=self.columns())
    let mask_row = Array(capacity=self.columns())
    for column in 0..<self.columns() {
      let original_mask = self.mask[row][column]
      let value = if original_mask {
        self.values[row][column]
      } else {
        f(self.values[row][column])
      }
      value_row.push(value)
      mask_row.push(mask_or_invalid(value, original_mask))
    }
    values.push(value_row)
    mask.push(mask_row)
  }
  { values, mask, }
}
