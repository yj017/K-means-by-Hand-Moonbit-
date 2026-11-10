///|
/// Live exponent threshold used by logarithmic mathematical text formatters.
pub fn formatter_min_exponent() -> @bigint.BigInt {
  current.val.formatter_min_exponent
}

///|
pub fn set_formatter_min_exponent(value : @bigint.BigInt) -> Unit {
  current.val.formatter_min_exponent = value
}

///|
pub fn RcParams::formatter_min_exponent(self : RcParams) -> @bigint.BigInt {
  self.formatter_min_exponent
}
