///|
/// Whether Formatter.fix_minus replaces ASCII hyphens by the Unicode minus.
pub fn unicode_minus() -> Bool {
  current.val.unicode_minus
}

///|
pub fn set_unicode_minus(value : Bool) -> Unit {
  current.val.unicode_minus = value
}

///|
pub fn RcParams::unicode_minus(self : RcParams) -> Bool {
  self.unicode_minus
}
