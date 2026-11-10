///|
/// Raw sequences and ndarray views keep their distinct truth and alias rules.
pub(all) enum AsinhSubs {
  Sequence(Array[Double])
  Tuple(AsinhSubsTuple)
  NdArray(TickValues)
  Number(Double)
  Text(String)
}

///|
pub impl @debug.Debug for AsinhSubs with fn to_repr(self) {
  match self {
    Sequence(value) => @debug.Repr::Repr(("Sequence", value))
    Tuple(value) => @debug.Repr::Repr(("Tuple", value))
    NdArray(value) => @debug.Repr::Repr(("NdArray length", value.length()))
    Number(value) => @debug.Repr::Repr(("Number", value))
    Text(value) => @debug.Repr::Repr(("Text", value))
  }
}

///|
pub extend AsinhSubs with @debug.Debug::{to_repr}
