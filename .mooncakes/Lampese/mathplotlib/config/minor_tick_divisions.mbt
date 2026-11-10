///|
/// Raw AutoMinor subdivisions and validated integer rc values are distinct.
pub(all) enum MinorTickDivisions {
  Text(String)
  Number(Double)
  Integer(@bigint.BigInt)
} derive(Debug, Eq)

///|
pub extend MinorTickDivisions with @debug.Debug::{to_repr}

///|
pub extend MinorTickDivisions with Eq::{equal, not_equal}

///|
// Python 3.12 Unicode decimal digits; int() accepts these without normalizing text.
fn minor_tick_decimal_digit(character : Char) -> Int32? {
  let code = character.to_int()
  for
    zero in [
      0x30, 0x660, 0x6f0, 0x7c0, 0x966, 0x9e6, 0xa66, 0xae6, 0xb66, 0xbe6, 0xc66,
      0xce6, 0xd66, 0xde6, 0xe50, 0xed0, 0xf20, 0x1040, 0x1090, 0x17e0, 0x1810, 0x1946,
      0x19d0, 0x1a80, 0x1a90, 0x1b50, 0x1bb0, 0x1c40, 0x1c50, 0xa620, 0xa8d0, 0xa900,
      0xa9d0, 0xa9f0, 0xaa50, 0xabf0, 0xff10, 0x104a0, 0x10d30, 0x11066, 0x110f0,
      0x11136, 0x111d0, 0x112f0, 0x11450, 0x114d0, 0x11650, 0x116c0, 0x11730, 0x118e0,
      0x11950, 0x11c50, 0x11d50, 0x11da0, 0x11f50, 0x16a60, 0x16ac0, 0x16b50, 0x1d7ce,
      0x1d7d8, 0x1d7e2, 0x1d7ec, 0x1d7f6, 0x1e140, 0x1e2f0, 0x1e4f0, 0x1e950, 0x1fbf0,
    ] {
    if code >= zero && code < zero + 10 {
      return Some(code - zero)
    }
  }
  None
}

///|
fn minor_tick_integer_space(character : Char) -> Bool {
  let code = character.to_int()
  (code >= 9 && code <= 13) ||
  code == 32 ||
  code == 0x85 ||
  code == 0xA0 ||
  code == 0x1680 ||
  (code >= 0x2000 && code <= 0x200A) ||
  code == 0x2028 ||
  code == 0x2029 ||
  code == 0x202F ||
  code == 0x205F ||
  code == 0x3000
}

///|
fn minor_tick_integer_error() -> @core.DataError {
  @core.DataError::InvalidTicks(
    message="'tick.minor.ndivs' must be 'auto' or non-negative int",
  )
}

///|
fn minor_tick_parse_integer(
  value : String,
) -> @bigint.BigInt raise @core.DataError {
  let chars = value.to_array()
  let mut first = 0
  let mut last = chars.length()
  while first < last && minor_tick_integer_space(chars[first]) {
    first += 1
  }
  while last > first && minor_tick_integer_space(chars[last - 1]) {
    last -= 1
  }
  if first == last {
    raise minor_tick_integer_error()
  }
  let negative = chars[first] == '-'
  if negative || chars[first] == '+' {
    first += 1
  }
  let digits = StringBuilder()
  let mut previous_digit = false
  let mut count = 0
  for index in first..<last {
    match minor_tick_decimal_digit(chars[index]) {
      Some(digit) => {
        digits.write_string(digit.to_string())
        count += 1
        previous_digit = true
      }
      None => {
        if chars[index] != '_' ||
          !previous_digit ||
          index + 1 == last ||
          minor_tick_decimal_digit(chars[index + 1]) is None {
          raise minor_tick_integer_error()
        }
        previous_digit = false
      }
    }
  }
  if !previous_digit || count > 4300 {
    raise minor_tick_integer_error()
  }
  let integer = @bigint.BigInt::from_string(digits.to_string())
  if negative && !integer.is_zero() {
    raise minor_tick_integer_error()
  }
  integer
}

///|
// Truncate the complete finite binary64 domain without an Int64 intermediate.
fn minor_tick_truncate(value : Double) -> @bigint.BigInt raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise minor_tick_integer_error()
  }
  let bits = value.reinterpret_as_uint64()
  let exponent = ((bits >> 52) & 0x7FFUL).to_int() - 1023 - 52
  let significand = (bits & 0xFFFFFFFFFFFFFUL) | 0x10000000000000UL
  let integer = if exponent < -52 {
    @bigint.BigInt::from_int(0)
  } else if exponent < 0 {
    @bigint.BigInt::from_uint64(significand) >> -exponent
  } else {
    @bigint.BigInt::from_uint64(significand) << exponent
  }
  if value < 0.0 && !integer.is_zero() {
    raise minor_tick_integer_error()
  }
  integer
}

///|
fn validate_minor_tick_divisions(
  value : MinorTickDivisions,
) -> MinorTickDivisions raise @core.DataError {
  match value {
    Text(text) =>
      if text.to_lower() == "auto" {
        Text(text)
      } else {
        Integer(minor_tick_parse_integer(text))
      }
    Number(number) => Integer(minor_tick_truncate(number))
    Integer(integer) => {
      if integer < @bigint.BigInt::from_int(0) {
        raise minor_tick_integer_error()
      }
      Integer(integer)
    }
  }
}

///|
/// Return the current x or y minor subdivision rc value.
pub fn minor_tick_divisions(horizontal~ : Bool = true) -> MinorTickDivisions {
  if horizontal {
    current.val.x_minor_tick_divisions
  } else {
    current.val.y_minor_tick_divisions
  }
}

///|
/// Validate the new value before replacing its axis-specific rc setting.
pub fn set_minor_tick_divisions(
  value : MinorTickDivisions,
  horizontal~ : Bool = true,
) -> Unit raise @core.DataError {
  let value = validate_minor_tick_divisions(value)
  if horizontal {
    current.val.x_minor_tick_divisions = value
  } else {
    current.val.y_minor_tick_divisions = value
  }
}

///|
pub fn RcParams::minor_tick_divisions(
  self : RcParams,
  horizontal~ : Bool = true,
) -> MinorTickDivisions {
  if horizontal {
    self.x_minor_tick_divisions
  } else {
    self.y_minor_tick_divisions
  }
}
