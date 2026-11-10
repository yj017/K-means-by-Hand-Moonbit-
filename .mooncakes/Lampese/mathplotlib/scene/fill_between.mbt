///|
// Both endpoints must participate in the mask, including for automatic limits.
fn Axes::add_fill_between(
  self : Axes,
  positions : Array[Double],
  first : Array[Double],
  second : Array[Double],
  horizontal : Bool,
  color : String,
  label : String,
) -> Unit raise @core.DataError {
  if first.length() != positions.length() {
    raise @core.DataError::LengthMismatch(
      expected=positions.length(),
      actual=first.length(),
    )
  }
  if second.length() != positions.length() {
    raise @core.DataError::LengthMismatch(
      expected=positions.length(),
      actual=second.length(),
    )
  }
  let lower = Array(capacity=positions.length())
  let upper = Array(capacity=positions.length())
  let resolved_color = self.resolve_color(color)
  let missing = @core.point(0.0 / 0.0, 0.0 / 0.0)
  for index in 0..<positions.length() {
    let (low, high) = if horizontal {
      (
        @core.point(first[index], positions[index]),
        @core.point(second[index], positions[index]),
      )
    } else {
      (
        @core.point(positions[index], first[index]),
        @core.point(positions[index], second[index]),
      )
    }
    if low.is_finite() && high.is_finite() {
      lower.push(low)
      upper.push(high)
    } else {
      lower.push(missing)
      upper.push(missing)
    }
  }
  self.push_artist(
    Artist::FillBetween(
      upper,
      lower,
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.record_band(horizontal)
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
}

///|
/// Fill the area between two y series.
pub fn Figure::fill_between(
  self : Figure,
  xs : Array[Double],
  lower : Array[Double],
  upper : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().fill_between(xs, lower, upper, color~, label~)
}

///|
/// Fill an area through the axes view.
pub fn Axes::fill_between(
  self : Axes,
  xs : Array[Double],
  lower : Array[Double],
  upper : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.add_fill_between(xs, lower, upper, false, color, label)
}

///|
/// Fill the area between two x series sampled at y positions.
pub fn Figure::fill_betweenx(
  self : Figure,
  ys : Array[Double],
  left : Array[Double],
  right~ : Array[Double] = [],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().fill_betweenx(ys, left, right~, color~, label~)
}

///|
/// Fill the area between two x series through the axes view.
pub fn Axes::fill_betweenx(
  self : Axes,
  ys : Array[Double],
  left : Array[Double],
  right~ : Array[Double] = [],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let right_values = if right.length() == 0 {
    let zeros = Array(capacity=ys.length())
    for _ in ys {
      zeros.push(0.0)
    }
    zeros
  } else {
    right
  }
  self.add_fill_between(ys, left, right_values, true, color, label)
}
