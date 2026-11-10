///|
fn require_finite_reference(
  value : Double,
  axis : String,
) -> Unit raise @core.DataError {
  if value.is_nan() || value.is_inf() {
    raise @core.DataError::NonFiniteLimit(axis~)
  }
}

///|
/// Draw horizontal line segments at the supplied y positions.
pub fn Figure::hlines(
  self : Figure,
  ys : Array[Double],
  xmin : Double,
  xmax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().hlines(ys, xmin, xmax, color~, label~)
}

///|
/// Draw horizontal line segments at the supplied y positions.
pub fn Axes::hlines(
  self : Axes,
  ys : Array[Double],
  xmin : Double,
  xmax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_finite_reference(xmin, "x")
  require_finite_reference(xmax, "x")
  let resolved_color = self.resolve_color(color)
  let style = @core.style(resolved_color)
  for y in ys {
    require_finite_reference(y, "y")
    self.push_artist(
      Artist::Line([@core.point(xmin, y), @core.point(xmax, y)], style),
    )
  }
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Draw vertical line segments at the supplied x positions.
pub fn Figure::vlines(
  self : Figure,
  xs : Array[Double],
  ymin : Double,
  ymax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().vlines(xs, ymin, ymax, color~, label~)
}

///|
/// Draw vertical line segments at the supplied x positions.
pub fn Axes::vlines(
  self : Axes,
  xs : Array[Double],
  ymin : Double,
  ymax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_finite_reference(ymin, "y")
  require_finite_reference(ymax, "y")
  let resolved_color = self.resolve_color(color)
  let style = @core.style(resolved_color)
  for x in xs {
    require_finite_reference(x, "x")
    self.push_artist(
      Artist::Line([@core.point(x, ymin), @core.point(x, ymax)], style),
    )
  }
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Fill the horizontal span between two y values across the axes.
pub fn Figure::axhspan(
  self : Figure,
  ymin : Double,
  ymax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().axhspan(ymin, ymax, color~, label~)
}

///|
/// Fill the horizontal span between two y values across the axes.
pub fn Axes::axhspan(
  self : Axes,
  ymin : Double,
  ymax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_finite_reference(ymin, "y")
  require_finite_reference(ymax, "y")
  let resolved_color = self.resolve_color(color)
  self.push_artist(
    Artist::HSpan(
      ymin,
      ymax,
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
}

///|
/// Fill the vertical span between two x values across the axes.
pub fn Figure::axvspan(
  self : Figure,
  xmin : Double,
  xmax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().axvspan(xmin, xmax, color~, label~)
}

///|
/// Fill the vertical span between two x values across the axes.
pub fn Axes::axvspan(
  self : Axes,
  xmin : Double,
  xmax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_finite_reference(xmin, "x")
  require_finite_reference(xmax, "x")
  let resolved_color = self.resolve_color(color)
  self.push_artist(
    Artist::VSpan(
      xmin,
      xmax,
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
}
