///|
/// Return the default calendar alignment used by newly enabled date axes.
pub fn date_interval_multiples() -> Bool {
  current.val.date_interval_multiples
}

///|
pub fn set_date_interval_multiples(value : Bool) -> Unit {
  current.val.date_interval_multiples = value
}

///|
pub fn RcParams::date_interval_multiples(self : RcParams) -> Bool {
  self.date_interval_multiples
}
