///|
fn validate_multiseries_bars(
  categories : Array[String],
  series : Array[Array[Double]],
  labels : Array[String],
  colors : Array[String],
  width : Double,
  gap : Double,
  baseline : Double,
) -> Unit raise @core.DataError {
  for count in [labels.length(), colors.length()] {
    if count != 0 && count != series.length() {
      raise @core.DataError::LengthMismatch(
        expected=series.length(),
        actual=count,
      )
    }
  }
  if width.is_nan() || width.is_inf() || width <= 0.0 {
    raise @core.DataError::InvalidStatistics(
      message="bar width must be positive and finite",
    )
  }
  if gap.is_nan() || gap.is_inf() || gap < 0.0 || gap >= 1.0 {
    raise @core.DataError::InvalidStatistics(
      message="grouped bar gap must be finite in [0, 1)",
    )
  }
  if baseline.is_nan() || baseline.is_inf() {
    raise @core.DataError::InvalidStatistics(
      message="bar baseline must be finite",
    )
  }
  for values in series {
    if values.length() != categories.length() {
      raise @core.DataError::LengthMismatch(
        expected=categories.length(),
        actual=values.length(),
      )
    }
    for value in values {
      if value.is_inf() {
        raise @core.DataError::InvalidStatistics(
          message="bar values must be finite or NaN for a missing segment",
        )
      }
    }
  }
}

///|
fn Axes::multiseries_bars(
  self : Axes,
  categories : Array[String],
  series : Array[Array[Double]],
  labels : Array[String],
  colors : Array[String],
  horizontal : Bool,
  width : Double,
  gap : Double,
  baseline : Double,
  stacked : Bool,
) -> Unit raise @core.DataError {
  validate_multiseries_bars(
    categories, series, labels, colors, width, gap, baseline,
  )
  if series.is_empty() || categories.is_empty() {
    return
  }
  let slot = if stacked { width } else { width / series.length().to_double() }
  let bar_width = slot * (1.0 - gap)
  if bar_width <= 0.0 {
    raise @core.DataError::InvalidStatistics(
      message="grouped bar width is too small for this series count and gap",
    )
  }
  // Validate every accumulated endpoint before modifying artists, units or colors.
  // NaN leaves both accumulators unchanged and keeps its original source index.
  let positive = Array::make(categories.length(), baseline)
  let negative = Array::make(categories.length(), baseline)
  let baselines : Array[Array[Double]] = []
  for values in series {
    let starts = []
    for index, value in values {
      let start = if stacked {
        if value < 0.0 {
          negative[index]
        } else {
          positive[index]
        }
      } else {
        baseline
      }
      let end = start + value
      if end.is_inf() {
        raise @core.DataError::InvalidStatistics(
          message="bar endpoint overflowed; reduce the values or baseline",
        )
      }
      starts.push(start)
      if stacked && !value.is_nan() {
        if value < 0.0 {
          negative[index] = end
        } else {
          positive[index] = end
        }
      }
    }
    baselines.push(starts)
  }
  let positions = if horizontal {
    category_y_points(self, positive, categories).map(point => point.y())
  } else {
    category_x_points(self, categories, positive).map(point => point.x())
  }
  for series_index, values in series {
    let offset = if stacked {
      0.0
    } else {
      -width / 2.0 + (series_index.to_double() + 0.5) * slot
    }
    let segments = []
    for index, value in values {
      segments.push(
        @core.bar_segment(
          positions[index] + offset,
          value,
          baseline=baselines[series_index][index],
          width=bar_width,
          category=Some(categories[index]),
        ),
      )
    }
    let color = self.resolve_color(
      if colors.is_empty() {
        ""
      } else {
        colors[series_index]
      },
    )
    let label = if labels.is_empty() { "" } else { labels[series_index] }
    let start = self.state.val.artists.length()
    self.push_artist(
      Artist::BarSegments(
        segments,
        horizontal,
        @core.style(color, width=0.0, fill=color),
      ),
    )
    self.add_auto_legend(label, color, LegendKind::Patch)
    self.add_container(ContainerKind::Bar, start, label)
  }
}

///|
/// Add side-by-side series at each category, vertically or horizontally.
/// `series` is series-major: every row has one value per category. `width` is
/// the total category-axis group span; `gap` is the fraction of each series slot
/// left empty. NaN skips one bar without changing source indices. All lengths,
/// finite options and endpoints are checked before artists are attached.
pub fn Axes::grouped_bar(
  self : Axes,
  categories : Array[String],
  series : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  horizontal~ : Bool = false,
  width~ : Double = 0.8,
  gap~ : Double = 0.1,
  baseline~ : Double = 0.0,
) -> Unit raise @core.DataError {
  self.multiseries_bars(
    categories, series, labels, colors, horizontal, width, gap, baseline, false,
  )
}

///|
/// Add stacked series with independent positive and negative accumulators per
/// category, both beginning at `baseline`. Tooltip values remain the original
/// segment values rather than their accumulated endpoints. NaN skips a segment.
pub fn Axes::stacked_bar(
  self : Axes,
  categories : Array[String],
  series : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  horizontal~ : Bool = false,
  width~ : Double = 0.8,
  baseline~ : Double = 0.0,
) -> Unit raise @core.DataError {
  self.multiseries_bars(
    categories, series, labels, colors, horizontal, width, 0.0, baseline, true,
  )
}

///|
/// Add grouped category bars to the default axes. See `Axes::grouped_bar`.
pub fn Figure::grouped_bar(
  self : Figure,
  categories : Array[String],
  series : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  horizontal~ : Bool = false,
  width~ : Double = 0.8,
  gap~ : Double = 0.1,
  baseline~ : Double = 0.0,
) -> Unit raise @core.DataError {
  self
  .axes()
  .grouped_bar(
    categories,
    series,
    labels~,
    colors~,
    horizontal~,
    width~,
    gap~,
    baseline~,
  )
}

///|
/// Add stacked category bars to the default axes. See `Axes::stacked_bar`.
pub fn Figure::stacked_bar(
  self : Figure,
  categories : Array[String],
  series : Array[Array[Double]],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  horizontal~ : Bool = false,
  width~ : Double = 0.8,
  baseline~ : Double = 0.0,
) -> Unit raise @core.DataError {
  self
  .axes()
  .stacked_bar(
    categories,
    series,
    labels~,
    colors~,
    horizontal~,
    width~,
    baseline~,
  )
}
