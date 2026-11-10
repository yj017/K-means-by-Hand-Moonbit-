///|
// CPython 3.12.14 builtin_sum_impl's float-only path, including its first
// int-zero addition and conditional final compensation. See third-party notice.
fn line_style_float_sum(values : Array[Double]) -> Double {
  if values.is_empty() {
    return 0.0
  }
  let mut total = 0.0 + values[0]
  let mut compensation = 0.0
  for index in 1..<values.length() {
    let value = values[index]
    let next = total + value
    if total.abs() >= value.abs() {
      compensation += total - next + value
    } else {
      compensation += value - next + total
    }
    total = next
  }
  if compensation != 0.0 && !compensation.is_nan() && !compensation.is_inf() {
    total += compensation
  }
  total
}
