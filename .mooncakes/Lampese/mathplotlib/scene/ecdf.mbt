///|
/// Values and cumulative probabilities returned by `ecdf`.
pub struct Ecdf {
  values : Array[Double]
  probabilities : Array[Double]
}

///|
pub fn Ecdf::values(self : Ecdf) -> Array[Double] {
  self.values.copy()
}

///|
pub fn Ecdf::probabilities(self : Ecdf) -> Array[Double] {
  self.probabilities.copy()
}

///|
fn validate_ecdf_values(values : Array[Double]) -> Unit raise @core.DataError {
  if values.length() == 0 {
    raise @core.DataError::InvalidStatistics(
      message="ecdf requires at least one value",
    )
  }
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidStatistics(
        message="ecdf values must be finite",
      )
    }
  }
}

///|
fn ecdf_pairs(
  values : Array[Double],
  weights : Array[Double],
) -> Array[(Double, Double)] raise @core.DataError {
  validate_ecdf_values(values)
  if weights.length() != 0 && weights.length() != values.length() {
    raise @core.DataError::LengthMismatch(
      expected=values.length(),
      actual=weights.length(),
    )
  }
  let pairs = Array(capacity=values.length())
  for index in 0..<values.length() {
    let weight = if weights.length() == 0 { 1.0 } else { weights[index] }
    if weight.is_nan() || weight.is_inf() || weight < 0.0 {
      raise @core.DataError::InvalidStatistics(
        message="ecdf weights must be finite and non-negative",
      )
    }
    pairs.push((values[index], weight))
  }
  pairs.sort_by((first, second) => {
    let (first_value, _) = first
    let (second_value, _) = second
    if first_value < second_value {
      -1
    } else if first_value > second_value {
      1
    } else {
      0
    }
  })
  let mut total = 0.0
  for pair in pairs {
    let (_, weight) = pair
    total += weight
  }
  if total <= 0.0 {
    raise @core.DataError::InvalidStatistics(
      message="ecdf weights must have a positive sum",
    )
  }
  pairs
}

///|
fn ecdf_result(
  values : Array[Double],
  weights : Array[Double],
  complementary : Bool,
  horizontal : Bool,
  compress : Bool,
  color : String,
  label : String,
  axes : Axes,
) -> Ecdf raise @core.DataError {
  let pairs = ecdf_pairs(values, weights)
  let total = {
    let mut result = 0.0
    for pair in pairs {
      let (_, weight) = pair
      result += weight
    }
    result
  }
  let output_values = Array(capacity=pairs.length())
  let output_probabilities = Array(capacity=pairs.length())
  let before_probabilities = Array(capacity=pairs.length())
  let points : Array[@core.Point] = []
  let mut cumulative = 0.0
  let mut index = 0
  while index < pairs.length() {
    let (value, first_weight) = pairs[index]
    let mut group_weight = first_weight
    let mut next_index = index + 1
    if compress {
      while next_index < pairs.length() {
        let (next_value, next_weight) = pairs[next_index]
        if next_value != value {
          break
        }
        group_weight += next_weight
        next_index += 1
      }
    }
    let before = if complementary {
      1.0 - cumulative / total
    } else {
      cumulative / total
    }
    cumulative += group_weight
    let after = if complementary {
      1.0 - cumulative / total
    } else {
      cumulative / total
    }
    output_values.push(value)
    output_probabilities.push(after)
    before_probabilities.push(before)
    let first_point = if horizontal {
      @core.point(before, value)
    } else {
      @core.point(value, before)
    }
    let second_point = if horizontal {
      @core.point(after, value)
    } else {
      @core.point(value, after)
    }
    points.push(first_point)
    points.push(second_point)
    index = if compress { next_index } else { index + 1 }
  }
  let datums = []
  let owners = []
  for i in 0..<output_values.length() {
    datums.push(
      @render.discrete_datum(
        i,
        points[i * 2 + 1],
        output_values[i],
        interval=if i + 1 < output_values.length() {
          Some((output_values[i], output_values[i + 1]))
        } else {
          None
        },
        fraction=Some(output_probabilities[i]),
        band=Some(
          @drawing.band_info(
            before_probabilities[i],
            output_probabilities[i],
            horizontal~,
          ),
        ),
      ),
    )
    if i > 0 {
      owners.push(i - 1)
    }
    owners.push(i)
  }
  let source = @render.discrete_line_hit_data(Ecdf, points, datums, owners).unwrap()
  let resolved_color = axes.resolve_color(color)
  axes.push_artist(Artist::Line(points, @core.style(resolved_color)))
  axes.record_discrete_line(source)
  axes.add_auto_legend(label, resolved_color, LegendKind::Line)
  { values: output_values, probabilities: output_probabilities, }
}

///|
/// Plot and return an empirical cumulative distribution function.
pub fn Figure::ecdf(
  self : Figure,
  values : Array[Double],
  weights~ : Array[Double] = [],
  complementary~ : Bool = false,
  horizontal~ : Bool = false,
  compress~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Ecdf raise @core.DataError {
  self
  .axes()
  .ecdf(
    values,
    weights~,
    complementary~,
    horizontal~,
    compress~,
    color~,
    label~,
  )
}

///|
/// Plot and return an empirical cumulative distribution function.
pub fn Axes::ecdf(
  self : Axes,
  values : Array[Double],
  weights~ : Array[Double] = [],
  complementary~ : Bool = false,
  horizontal~ : Bool = false,
  compress~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Ecdf raise @core.DataError {
  ecdf_result(
    values, weights, complementary, horizontal, compress, color, label, self,
  )
}
