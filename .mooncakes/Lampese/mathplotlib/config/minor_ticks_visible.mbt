///|
/// Whether a newly installed linear scale selects AutoMinorLocator.
pub fn minor_ticks_visible(horizontal~ : Bool = true) -> Bool {
  if horizontal {
    current.val.x_minor_ticks_visible
  } else {
    current.val.y_minor_ticks_visible
  }
}

///|
/// Configure the x or y minor-visibility default for future scale installations.
pub fn set_minor_ticks_visible(value : Bool, horizontal~ : Bool = true) -> Unit {
  if horizontal {
    current.val.x_minor_ticks_visible = value
  } else {
    current.val.y_minor_ticks_visible = value
  }
}

///|
pub fn RcParams::minor_ticks_visible(
  self : RcParams,
  horizontal~ : Bool = true,
) -> Bool {
  if horizontal {
    self.x_minor_ticks_visible
  } else {
    self.y_minor_ticks_visible
  }
}
