///|
// The subsecond interval table used by Matplotlib's AutoDateLocator.
fn microsecond_interval(target : Double) -> Int32 {
  for
    interval in [
      1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000,
      100000, 200000, 500000, 1000000,
    ] {
    if Double::from_int(interval) >= target {
      return interval
    }
  }
  1000000
}

///|
// Source: Matplotlib v3.11.2 dates.MicrosecondLocator and ticker.MultipleLocator.
// The locator first floors the UTC ordinal and scales the fractional day to
// integer microseconds. The requested fixed offset affects date formatting,
// but does not move this UTC grid's phase.
fn microsecond_ticks(
  first : Double,
  last : Double,
  interval : Int32,
) -> Array[Double] {
  microsecond_ticks_unclipped(first, last, Double::from_int(interval)).filter(
    supported_ordinal,
  ) catch {
    _ => []
  }
}

///|
fn microsecond_multiple_ticks(
  lower : Double,
  upper : Double,
  step : Double,
) -> Array[Double] raise DateError {
  @tick_grid.ticks(lower, upper, step) catch {
    _ =>
      raise DateError::InvalidDate(
        message="microsecond grid alignment or count is not finite",
      )
  }
}

///|
// Keep origin from the original first endpoint. MultipleLocator sorts only
// after origin subtraction; reversed direct bounds can round differently.
fn microsecond_ticks_unclipped(
  first : Double,
  last : Double,
  interval : Double,
) -> Array[Double] raise DateError {
  let origin = first.floor()
  let lower = (first - origin) * 86_400_000_000.0
  let upper = (last - origin) * 86_400_000_000.0
  microsecond_multiple_ticks(lower, upper, interval).map(value => {
    value / 86_400_000_000.0 + origin
  })
}
