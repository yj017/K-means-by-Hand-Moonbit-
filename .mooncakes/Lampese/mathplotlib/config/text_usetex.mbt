///|
/// Dynamic text.usetex setting used by formatter symbol escaping.
pub fn text_usetex() -> Bool {
  current.val.text_usetex
}

///|
pub fn set_text_usetex(value : Bool) -> Unit {
  current.val.text_usetex = value
}

///|
pub fn RcParams::text_usetex(self : RcParams) -> Bool {
  self.text_usetex
}
