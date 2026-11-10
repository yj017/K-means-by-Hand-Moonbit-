///|
fn finite_additional(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
/// Fill a closed polygon from paired x/y coordinates.
pub fn Figure::fill(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().fill(xs, ys, color~, label~)
}

///|
/// Fill a closed polygon through the axes view.
pub fn Axes::fill(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let values = @core.series(xs, ys)
  if values.length() < 3 {
    raise @core.DataError::InvalidReference(
      message="fill requires at least three points",
    )
  }
  let resolved_color = self.resolve_color(color)
  self.push_artist(
    Artist::Polygon(
      values.points(),
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
}

///|
/// Draw horizontal broken bars from `(start, width)` ranges.
pub fn Figure::broken_barh(
  self : Figure,
  xranges : Array[(Double, Double)],
  yrange : (Double, Double),
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().broken_barh(xranges, yrange, color~, label~)
}

///|
/// Draw horizontal broken bars through the axes view.
pub fn Axes::broken_barh(
  self : Axes,
  xranges : Array[(Double, Double)],
  yrange : (Double, Double),
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let (y, height) = yrange
  if !finite_additional(y) || !finite_additional(height) || height <= 0.0 {
    raise @core.DataError::InvalidReference(
      message="broken_barh y range must be finite with positive height",
    )
  }
  let resolved_color = self.resolve_color(color)
  for (x, width) in xranges {
    if !finite_additional(x) || !finite_additional(width) || width < 0.0 {
      raise @core.DataError::InvalidReference(
        message="broken_barh ranges must be finite with non-negative widths",
      )
    }
    self.push_artist(
      Artist::Polygon(
        [
          @core.point(x, y),
          @core.point(x + width, y),
          @core.point(x + width, y + height),
          @core.point(x, y + height),
        ],
        @core.style(resolved_color, width=0.0, fill=resolved_color),
      ),
    )
  }
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
}

///|
fn histogram_edges(
  minimum : Double,
  maximum : Double,
  bins : Int32,
) -> Array[Double] {
  let (lower, upper) = if minimum == maximum {
    (minimum - 0.5, maximum + 0.5)
  } else {
    (minimum, maximum)
  }
  let step = (upper - lower) / Double::from_int(bins)
  let result = Array(capacity=bins + 1)
  for index in 0..<=bins {
    result.push(lower + Double::from_int(index) * step)
  }
  result
}

///|
fn finite_pair_bounds(
  xs : Array[Double],
  ys : Array[Double],
) -> (Double, Double, Double, Double)? {
  let mut xmin : Double? = None
  let mut xmax : Double? = None
  let mut ymin : Double? = None
  let mut ymax : Double? = None
  let count = Int32::min(xs.length(), ys.length())
  for index in 0..<count {
    let x = xs[index]
    let y = ys[index]
    if finite_additional(x) && finite_additional(y) {
      xmin = Some(
        match xmin {
          None => x
          Some(value) => Double::min(value, x)
        },
      )
      xmax = Some(
        match xmax {
          None => x
          Some(value) => Double::max(value, x)
        },
      )
      ymin = Some(
        match ymin {
          None => y
          Some(value) => Double::min(value, y)
        },
      )
      ymax = Some(
        match ymax {
          None => y
          Some(value) => Double::max(value, y)
        },
      )
    }
  }
  match (xmin, xmax, ymin, ymax) {
    (Some(x0), Some(x1), Some(y0), Some(y1)) => Some((x0, x1, y0, y1))
    _ => None
  }
}

///|
/// Compute a rectangular two-dimensional histogram and draw it as a mesh.
pub fn Figure::hist2d(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  bins_x~ : Int32 = 10,
  bins_y~ : Int32 = 10,
  cmap~ : String = "viridis",
) -> Unit raise @core.DataError {
  self.axes().hist2d(xs, ys, bins_x~, bins_y~, cmap~)
}

///|
/// Compute and draw a rectangular two-dimensional histogram.
pub fn Axes::hist2d(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  bins_x~ : Int32 = 10,
  bins_y~ : Int32 = 10,
  cmap~ : String = "viridis",
) -> Unit raise @core.DataError {
  if bins_x <= 0 || bins_y <= 0 {
    raise @core.DataError::InvalidStatistics(
      message="hist2d bins must be positive",
    )
  }
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  let bounds = match finite_pair_bounds(xs, ys) {
    Some(value) => value
    None =>
      raise @core.DataError::InvalidStatistics(
        message="hist2d requires at least one finite pair",
      )
  }
  let (xmin, xmax, ymin, ymax) = bounds
  let x_edges = histogram_edges(xmin, xmax, bins_x)
  let y_edges = histogram_edges(ymin, ymax, bins_y)
  let counts = Array(capacity=bins_y)
  for _ in 0..<bins_y {
    let row = Array(capacity=bins_x)
    for _ in 0..<bins_x {
      row.push(0.0)
    }
    counts.push(row)
  }
  let x_span = x_edges[bins_x] - x_edges[0]
  let y_span = y_edges[bins_y] - y_edges[0]
  for index in 0..<xs.length() {
    let x = xs[index]
    let y = ys[index]
    if finite_additional(x) && finite_additional(y) {
      let x_index = if x == x_edges[bins_x] {
        bins_x - 1
      } else {
        ((x - x_edges[0]) / x_span * Double::from_int(bins_x)).to_int()
      }
      let y_index = if y == y_edges[bins_y] {
        bins_y - 1
      } else {
        ((y - y_edges[0]) / y_span * Double::from_int(bins_y)).to_int()
      }
      if x_index >= 0 && x_index < bins_x && y_index >= 0 && y_index < bins_y {
        counts[y_index][x_index] = counts[y_index][x_index] + 1.0
      }
    }
  }
  add_mesh(
    self,
    counts,
    x_edges,
    y_edges,
    None,
    None,
    cmap,
    true,
    false,
    histogram2d=true,
  )
}

///|
/// Draw a vector key arrow and label in data coordinates.
pub fn Figure::quiverkey(
  self : Figure,
  x : Double,
  y : Double,
  value : Double,
  label : String,
  color~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().quiverkey(x, y, value, label, color~)
}

///|
/// Draw a vector key arrow and label through the axes view.
pub fn Axes::quiverkey(
  self : Axes,
  x : Double,
  y : Double,
  value : Double,
  label : String,
  color~ : String = "",
) -> Unit raise @core.DataError {
  if !finite_additional(x) || !finite_additional(y) || !finite_additional(value) {
    raise @core.DataError::InvalidQuiver(
      message="quiverkey values must be finite",
    )
  }
  let resolved_color = self.resolve_color(color)
  self.arrow(x, y, value, 0.0, color=resolved_color, label="")
  self.text(x + value, y, label, color=resolved_color)
}

///|
/// Return the effective legend entries for the default axes.
pub fn Figure::get_legend_handles_labels(self : Figure) -> Array[LegendEntry] {
  self.legend_entries()
}

///|
/// Return the effective legend entries for this axes.
pub fn Axes::get_legend_handles_labels(self : Axes) -> Array[LegendEntry] {
  self.legend_entries()
}
