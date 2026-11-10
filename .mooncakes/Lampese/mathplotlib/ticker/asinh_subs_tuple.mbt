///|
/// An immutable one-dimensional Asinh subdivision tuple.
pub struct AsinhSubsTuple {
  priv values : Array[Double]
}

///|
pub impl @debug.Debug for AsinhSubsTuple with fn to_repr(self) {
  @debug.Repr::Repr(("AsinhSubsTuple", self.values))
}

///|
pub extend AsinhSubsTuple with @debug.Debug::{to_repr}

///|
pub impl Eq for AsinhSubsTuple with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub extend AsinhSubsTuple with Eq::{equal, not_equal}

///|
/// Copy the values so subsequent owner mutation cannot alter this tuple.
pub fn AsinhSubsTuple::new(values : Array[Double]) -> AsinhSubsTuple {
  { values: values.copy(), }
}

///|
pub fn AsinhSubsTuple::length(self : AsinhSubsTuple) -> Int32 {
  self.values.length()
}

///|
/// Export an independent copy; tuple storage remains immutable.
pub fn AsinhSubsTuple::values(self : AsinhSubsTuple) -> Array[Double] {
  self.values.copy()
}

///|
let asinh_scale_base10_minor_tuple : AsinhSubsTuple = AsinhSubsTuple::new([
  2.0, 5.0,
])

///|
/// Shared immutable base-ten scale defaults, without a mutable class-map API.
pub fn asinh_default_minor_subs() -> AsinhSubsTuple {
  asinh_scale_base10_minor_tuple
}
