///|
pub fn formatter_use_offset() -> Bool {
  current.val.formatter_use_offset
}

///|
pub fn set_formatter_use_offset(value : Bool) -> Unit {
  current.val.formatter_use_offset = value
}

///|
pub fn RcParams::formatter_use_offset(self : RcParams) -> Bool {
  self.formatter_use_offset
}

///|
pub fn formatter_use_math_text() -> Bool {
  current.val.formatter_use_math_text
}

///|
pub fn set_formatter_use_math_text(value : Bool) -> Unit {
  current.val.formatter_use_math_text = value
}

///|
pub fn RcParams::formatter_use_math_text(self : RcParams) -> Bool {
  self.formatter_use_math_text
}

///|
pub fn formatter_use_locale() -> Bool {
  current.val.formatter_use_locale
}

///|
pub fn set_formatter_use_locale(value : Bool) -> Unit {
  current.val.formatter_use_locale = value
}

///|
pub fn RcParams::formatter_use_locale(self : RcParams) -> Bool {
  self.formatter_use_locale
}

///|
pub fn formatter_offset_threshold() -> @bigint.BigInt {
  current.val.formatter_offset_threshold
}

///|
pub fn set_formatter_offset_threshold(value : @bigint.BigInt) -> Unit {
  current.val.formatter_offset_threshold = value
}

///|
pub fn RcParams::formatter_offset_threshold(self : RcParams) -> @bigint.BigInt {
  self.formatter_offset_threshold
}

///|
/// Borrow the current rc list, also retained by existing ScalarFormatter objects.
pub fn formatter_limits() -> Array[@bigint.BigInt] {
  current.val.formatter_limits
}

///|
pub fn RcParams::formatter_limits(self : RcParams) -> Array[@bigint.BigInt] {
  self.formatter_limits
}

///|
/// Validate before replacing the rc list with a fresh integer list.
pub fn set_formatter_limits(
  values : Array[@bigint.BigInt],
) -> Unit raise @core.DataError {
  if values.length() != 2 {
    let items : Array[String] = []
    for value in values {
      let magnitude = if value < @bigint.BigInt::from_int(0) {
        value.neg()
      } else {
        value
      }
      if magnitude.bit_length() >= 14285 &&
        magnitude >=
        @bigint.BigInt::from_int(10).pow(@bigint.BigInt::from_int(4300)) {
        raise @core.DataError::InvalidTicks(
          message="ValueError: Key axes.formatter.limits: Exceeds the limit (4300 digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit",
        )
      }
      items.push(value.to_string())
    }
    raise @core.DataError::InvalidTicks(
      message="ValueError: Key axes.formatter.limits: Expected 2 values, but there are " +
        values.length().to_string() +
        " values in [" +
        items.join(", ") +
        "]",
    )
  }
  current.val.formatter_limits = values.copy()
}
