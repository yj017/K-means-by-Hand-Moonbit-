///|
/// Python integer, floating and raw text tick budgets remain distinct.
pub(all) enum LogNumTicks {
  Text(String)
  Number(Double)
  Integer(@bigint.BigInt)
} derive(Debug, Eq)

///|
pub extend LogNumTicks with @debug.Debug::{to_repr}

///|
pub extend LogNumTicks with Eq::{equal, not_equal}

///|
/// Numeric subs retain borrowed Float64 views after source dtype normalization.
pub(all) enum LogSubs {
  Text(String)
  Values(TickValues)
}

///|
pub impl @debug.Debug for LogSubs with fn to_repr(self) {
  match self {
    Text(value) => @debug.Repr::Repr(("Text", value))
    Values(value) => @debug.Repr::Repr(("Values length", value.length()))
  }
}

///|
pub extend LogSubs with @debug.Debug::{to_repr}

///|
/// Physical axes return Python integers; custom float providers preserve floats.
pub(all) enum LogTickSpace {
  Integer(@bigint.BigInt)
  Number(Double)
} derive(Debug, Eq)

///|
pub extend LogTickSpace with @debug.Debug::{to_repr}

///|
pub extend LogTickSpace with Eq::{equal, not_equal}

///|
/// Transport a finite integer-valued Double without losing Python integer dtype.
pub fn LogTickSpace::from_integer(
  value : Double,
) -> LogTickSpace raise @core.DataError {
  if value.is_nan() || value.is_inf() || value.trunc() != value {
    raise @core.DataError::InvalidTicks(
      message="log tick space is not a finite integer",
    )
  }
  Integer(auto_minor_round(value))
}
