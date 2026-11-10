///|
/// Preserve raw scalar/unsized subs and borrowed one-dimensional numeric storage.
pub(all) enum SymLogSubs {
  Text(String)
  Number(Double)
  Values(TickValues)
}

///|
pub impl @debug.Debug for SymLogSubs with fn to_repr(self) {
  match self {
    Text(value) => @debug.Repr::Repr(("Text", value))
    Number(value) => @debug.Repr::Repr(("Number", value))
    Values(value) => @debug.Repr::Repr(("Values length", value.length()))
  }
}

///|
pub extend SymLogSubs with @debug.Debug::{to_repr}
