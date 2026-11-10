///|
/// Summary statistics for one box-and-whisker series.
pub struct BoxStats {
  lower_whisker : Double
  q1 : Double
  median : Double
  q3 : Double
  upper_whisker : Double
  fliers : Array[Double]
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn sorted_finite(values : Array[Double]) -> Array[Double] {
  let mut result : Array[Double] = []
  for value in values {
    if finite(value) {
      let mut inserted = false
      let next = Array(capacity=result.length() + 1)
      for current in result {
        if !inserted && value < current {
          next.push(value)
          inserted = true
        }
        next.push(current)
      }
      if !inserted {
        next.push(value)
      }
      result = next
    }
  }
  result
}

///|
fn percentile(values : Array[Double], fraction : Double) -> Double {
  let position = fraction * Double::from_int(values.length() - 1)
  let lower = position.floor().to_int()
  let upper = position.ceil().to_int()
  if lower == upper {
    values[lower]
  } else {
    let weight = position - Double::from_int(lower)
    values[lower] + (values[upper] - values[lower]) * weight
  }
}

///|
/// Compute Tukey box-and-whisker statistics using a 1.5 IQR whisker rule.
pub fn box_stats(values : Array[Double]) -> BoxStats raise @core.DataError {
  let sorted = sorted_finite(values)
  if sorted.length() == 0 {
    raise @core.DataError::InvalidBoxPlot(
      message="boxplot requires at least one finite value",
    )
  }
  let q1 = percentile(sorted, 0.25)
  let median = percentile(sorted, 0.5)
  let q3 = percentile(sorted, 0.75)
  let iqr = q3 - q1
  let lower_fence = q1 - 1.5 * iqr
  let upper_fence = q3 + 1.5 * iqr
  let mut lower_whisker = sorted[0]
  let mut upper_whisker = sorted[sorted.length() - 1]
  let mut found_lower = false
  let fliers : Array[Double] = []
  for value in sorted {
    if value >= lower_fence && !found_lower {
      lower_whisker = value
      found_lower = true
    }
    if value <= upper_fence {
      upper_whisker = value
    } else {
      fliers.push(value)
    }
  }
  for value in sorted {
    if value < lower_fence {
      fliers.push(value)
    }
  }
  { lower_whisker, q1, median, q3, upper_whisker, fliers, }
}

///|
pub fn BoxStats::lower_whisker(self : BoxStats) -> Double {
  self.lower_whisker
}

///|
pub fn BoxStats::q1(self : BoxStats) -> Double {
  self.q1
}

///|
pub fn BoxStats::median(self : BoxStats) -> Double {
  self.median
}

///|
pub fn BoxStats::q3(self : BoxStats) -> Double {
  self.q3
}

///|
pub fn BoxStats::upper_whisker(self : BoxStats) -> Double {
  self.upper_whisker
}

///|
pub fn BoxStats::fliers(self : BoxStats) -> Array[Double] {
  self.fliers.copy()
}
