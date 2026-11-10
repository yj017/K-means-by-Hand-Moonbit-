///|
/// Plot the sparsity pattern of a rectangular scalar matrix.
pub fn Figure::spy(
  self : Figure,
  data : Array[Array[Double]],
  precision~ : Double = 0.0,
  color~ : String = "",
  label~ : String = "",
  markersize~ : Double = 3.5,
  origin~ : String = "upper",
  aspect~ : String = "equal",
  marker~ : String = "o",
) -> Unit raise @core.DataError {
  self
  .axes()
  .spy(data, precision~, color~, label~, markersize~, origin~, aspect~, marker~)
}

///|
fn spy_marker_supported(marker : String) -> Bool {
  marker == "o" ||
  marker == "s" ||
  marker == "^" ||
  marker == "v" ||
  marker == "D" ||
  marker == "x" ||
  marker == "+" ||
  marker == "|" ||
  marker == "_" ||
  marker == "." ||
  marker == ","
}

///|
/// Plot the sparsity pattern of a rectangular scalar matrix.
pub fn Axes::spy(
  self : Axes,
  data : Array[Array[Double]],
  precision~ : Double = 0.0,
  color~ : String = "",
  label~ : String = "",
  markersize~ : Double = 3.5,
  origin~ : String = "upper",
  aspect~ : String = "equal",
  marker~ : String = "o",
) -> Unit raise @core.DataError {
  if data.length() == 0 || data[0].length() == 0 {
    raise @core.DataError::InvalidImage(
      message="spy data must have at least one cell",
    )
  }
  if precision.is_nan() || precision.is_inf() || precision < 0.0 {
    raise @core.DataError::InvalidImage(
      message="spy precision must be finite and non-negative",
    )
  }
  if markersize.is_nan() || markersize.is_inf() || markersize <= 0.0 {
    raise @core.DataError::InvalidImage(
      message="spy markersize must be positive and finite",
    )
  }
  if origin != "upper" && origin != "lower" {
    raise @core.DataError::InvalidImage(
      message="spy origin must be 'upper' or 'lower'",
    )
  }
  if aspect != "equal" && aspect != "auto" {
    raise @core.DataError::InvalidImage(
      message="spy aspect must be 'equal' or 'auto'",
    )
  }
  if !spy_marker_supported(marker) {
    raise @core.DataError::InvalidImage(
      message="spy marker must be one of o, s, ^, v, D, x, +, |, _, ., or ,",
    )
  }
  let columns = data[0].length()
  let points : Array[@core.Point] = []
  for row in 0..<data.length() {
    if data[row].length() != columns {
      raise @core.DataError::InvalidImage(
        message="spy data rows must have equal length",
      )
    }
    for column in 0..<columns {
      let value = data[row][column]
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidImage(
          message="spy data must contain finite values",
        )
      }
      if Double::abs(value) > precision {
        let point_row = if origin == "upper" {
          data.length() - row - 1
        } else {
          row
        }
        points.push(
          @core.point(Double::from_int(column), Double::from_int(point_row)),
        )
      }
    }
  }
  if aspect == "equal" {
    self.set_aspect_equal()
  } else {
    self.set_aspect_auto()
  }
  let resolved_color = self.resolve_color(color)
  self.push_artist(
    Artist::Scatter(
      points,
      @core.style(resolved_color, width=0.0, radius=markersize, marker~),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Marker)
}
