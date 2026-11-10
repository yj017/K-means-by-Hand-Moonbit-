///|
/// Construction-time classic style flag used by AutoLocator.
pub fn classic_mode() -> Bool {
  current.val.classic_mode
}

///|
pub fn set_classic_mode(value : Bool) -> Unit {
  current.val.classic_mode = value
}

///|
pub fn RcParams::classic_mode(self : RcParams) -> Bool {
  self.classic_mode
}
