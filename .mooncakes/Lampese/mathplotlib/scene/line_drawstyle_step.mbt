///|
// This is the actual flat path allocation size, not a logical point budget.
// The Int32 input makes every multiplication below exact in Int64. Checking
// belongs after the native XY commit, immediately before allocating the path.
fn line_drawstyle_path_cells(
  length : Int32,
  drawstyle : String,
) -> Int32 raise @core.DataError {
  let count = length.to_int64()
  let cells = match drawstyle {
    "default" => count * 2L
    "steps-mid" => count * 4L
    _ => if count == 0L { 0L } else { count * 4L - 2L }
  }
  if cells > 2147483647L {
    raise @core.DataError::InvalidTicks(
      message="ResourceError: Line path Float64 cache exceeds Array addressability",
    )
  }
  cells.to_int()
}

///|
// The original step helpers allocate independently, including for empty input.
// Default Path instead retains the same Float64 XY array and its mutations.
fn line_drawstyle_path(
  drawstyle : String,
  cache : Line2DCache,
) -> @ticker.TickValues raise @core.DataError {
  if drawstyle == "default" {
    return cache.flat
  }
  let length = cache.xs.length()
  let values : Array[Double] = Array(
    capacity=line_drawstyle_path_cells(length, drawstyle),
  )
  if drawstyle == "steps-mid" {
    if length > 0 {
      values.push(cache.xs.get(0))
      values.push(cache.ys.get(0))
      for index in 0..<(length - 1) {
        // Preserve NumPy's add followed by divide, including overflow and -0.
        let sum = cache.xs.get(index) + cache.xs.get(index + 1)
        let midpoint = sum / 2.0
        values.push(midpoint)
        values.push(cache.ys.get(index))
        values.push(midpoint)
        values.push(cache.ys.get(index + 1))
      }
      values.push(cache.xs.get(length - 1))
      values.push(cache.ys.get(length - 1))
    }
  } else {
    for index in 0..<length {
      values.push(cache.xs.get(index))
      values.push(cache.ys.get(index))
      if index + 1 < length {
        if drawstyle == "steps-post" {
          values.push(cache.xs.get(index + 1))
          values.push(cache.ys.get(index))
        } else {
          values.push(cache.xs.get(index))
          values.push(cache.ys.get(index + 1))
        }
      }
    }
  }
  @ticker.TickValues::from_array(values)
}
