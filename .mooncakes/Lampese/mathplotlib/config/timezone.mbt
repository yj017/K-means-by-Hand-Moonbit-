///|
/// Default date display timezone. Numeric date instants and parsing are independent.
pub fn timezone() -> String {
  current.val.timezone
}

///|
/// Store a timezone name, as rcParams["timezone"] does. Name resolution and
/// errors happen when a date consumer uses it, not when this string is stored.
pub fn set_timezone(value : String) -> Unit {
  current.val.timezone = value
}

///|
pub fn RcParams::timezone(self : RcParams) -> String {
  self.timezone
}
