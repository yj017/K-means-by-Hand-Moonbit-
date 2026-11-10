///|
/// dateutil weekday with an optional relative occurrence. None and zero apply
/// as +1; the weekday object's equality still distinguishes their stored values.
pub struct RelativeWeekday {
  priv weekday : Int32
  priv nth : Int32?
} derive(Eq, Debug)

///|
pub extend RelativeWeekday with Eq::{equal, not_equal}

///|
pub extend RelativeWeekday with @debug.Debug::{to_repr}

///|
/// Construct the weekday object form. As in dateutil.weekday, arbitrary integer
/// indices are retained; applying a delta uses modulo-seven calendar movement.
pub fn RelativeWeekday::new(weekday : Int32, nth? : Int32) -> RelativeWeekday {
  { weekday, nth, }
}

///|
pub fn RelativeWeekday::weekday(self : RelativeWeekday) -> Int32 {
  self.weekday
}

///|
pub fn RelativeWeekday::nth(self : RelativeWeekday) -> Int32? {
  self.nth
}

///|
pub fn RelativeWeekday::with_nth(
  self : RelativeWeekday,
  nth : Int32,
) -> RelativeWeekday {
  { ..self, nth: Some(nth), }
}

///|
pub let mo : RelativeWeekday = { weekday: 0, nth: None, }

///|
pub let tu : RelativeWeekday = { weekday: 1, nth: None, }

///|
pub let we : RelativeWeekday = { weekday: 2, nth: None, }

///|
pub let th : RelativeWeekday = { weekday: 3, nth: None, }

///|
pub let fr : RelativeWeekday = { weekday: 4, nth: None, }

///|
pub let sa : RelativeWeekday = { weekday: 5, nth: None, }

///|
pub let su : RelativeWeekday = { weekday: 6, nth: None, }
