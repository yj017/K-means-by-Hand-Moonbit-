///|
/// Histogram counts and bin edges produced by `Figure::hist`.
pub struct Histogram {
  counts : Array[Double]
  edges : Array[Double]
  artists : Array[Artist]
}

///|
pub fn Histogram::counts(self : Histogram) -> Array[Double] {
  self.counts.copy()
}

///|
pub fn Histogram::edges(self : Histogram) -> Array[Double] {
  self.edges.copy()
}

///|
/// Return copies of the bar artists generated for the histogram bins.
pub fn Histogram::artists(self : Histogram) -> Array[Artist] {
  let result = Array(capacity=self.artists.length())
  for artist in self.artists {
    result.push(copy_artist(artist))
  }
  result
}

///|
/// Matplotlib-style alias for the histogram bar artists.
pub fn Histogram::patches(self : Histogram) -> Array[Artist] {
  self.artists()
}

///|
fn finite_values(values : Array[Double]) -> Array[Double] {
  let result = Array(capacity=values.length())
  for value in values {
    if !value.is_nan() && !value.is_inf() {
      result.push(value)
    }
  }
  result
}

///|
/// Compute a histogram and add its bars to the figure.
pub fn Figure::hist(
  self : Figure,
  values : Array[Double],
  bins~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
) -> Histogram raise @core.DataError {
  self.axes().hist(values, bins~, color~, label~)
}

///|
/// Compute and draw a histogram on this axes panel.
pub fn Axes::hist(
  self : Axes,
  values : Array[Double],
  bins~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
) -> Histogram raise @core.DataError {
  if bins <= 0 {
    raise @core.DataError::InvalidBins
  }
  let finite = finite_values(values)
  let mut minimum = 0.0
  let mut maximum = 1.0
  if finite.length() > 0 {
    minimum = finite[0]
    maximum = finite[0]
    for i in 1..<finite.length() {
      let value = finite[i]
      minimum = Double::min(minimum, value)
      maximum = Double::max(maximum, value)
    }
  }
  if minimum == maximum {
    minimum = minimum - 0.5
    maximum = maximum + 0.5
  }
  let step = (maximum - minimum) / Double::from_int(bins)
  let edges = Array(capacity=bins + 1)
  for index in 0..<=bins {
    edges.push(minimum + Double::from_int(index) * step)
  }
  let counts = Array(capacity=bins)
  for _ in 0..<bins {
    counts.push(0.0)
  }
  for value in finite {
    let raw_index = ((value - minimum) / step).to_int()
    let index = if raw_index < 0 {
      0
    } else if raw_index >= bins {
      bins - 1
    } else {
      raw_index
    }
    counts[index] += 1.0
  }
  let points = Array(capacity=bins)
  for index in 0..<bins {
    let center = (edges[index] + edges[index + 1]) / 2.0
    points.push(@core.point(center, counts[index]))
  }
  let start = self.state.val.artists.length()
  self.bar(points, color~, label~)
  self.record_histogram_edges(edges)
  let artists = Array(capacity=self.state.val.artists.length() - start)
  for index in start..<self.state.val.artists.length() {
    artists.push(copy_artist(self.state.val.artists[index]))
  }
  { counts, edges, artists, }
}
