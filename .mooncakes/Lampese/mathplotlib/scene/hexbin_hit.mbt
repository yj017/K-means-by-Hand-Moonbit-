///|
fn hexbin_reduction(
  has_values : Bool,
  reduce : String,
  reduce_fn : HexbinReducer?,
) -> @drawing.HexbinReduction {
  if reduce_fn is Some(_) {
    Custom
  } else if !has_values || reduce == "count" {
    Count
  } else {
    match reduce {
      "sum" => Sum
      "min" => Min
      "max" => Max
      _ => Mean
    }
  }
}
