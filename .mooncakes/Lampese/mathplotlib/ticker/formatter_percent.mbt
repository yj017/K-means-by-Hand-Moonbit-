///|
/// Percentage formatting with viewport-aware automatic precision.

///|
fn format_percent_values(
  values : Array[Double],
  xmax : Double,
  decimals : Int32,
  symbol : String,
  view : @core.Limits?,
) -> Array[String] {
  let (minimum, maximum) = formatter_extent(values, view)
  let display_range = maximum - minimum
  values.map(value => {
    format_percent(value, xmax, decimals, symbol, display_range)
  })
}

///|
fn format_percent(
  value : Double,
  xmax : Double,
  decimals : Int32,
  symbol : String,
  display_range : Double,
) -> String {
  let percentage = 100.0 * value / xmax
  let digits = if decimals >= 0 {
    decimals
  } else {
    let scaled_range = 100.0 * Double::abs(display_range) / Double::abs(xmax)
    if scaled_range <= 0.0 || scaled_range.is_nan() || scaled_range.is_inf() {
      0
    } else {
      Int32::max(
        0,
        Int32::min(5, (2.0 - @math.log10(2.0 * scaled_range)).ceil().to_int()),
      )
    }
  }
  format_fixed(percentage, digits) + symbol
}
