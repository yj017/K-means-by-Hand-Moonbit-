///|
/// Draw box-and-whisker plots for one or more value series.
pub fn Figure::boxplot(
  self : Figure,
  data : Array[Array[Double]],
  horizontal~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Array[@boxplot.BoxStats] raise @core.DataError {
  self.axes().boxplot(data, horizontal~, color~, label~)
}

///|
/// Draw box-and-whisker plots for one or more value series.
pub fn Axes::boxplot(
  self : Axes,
  data : Array[Array[Double]],
  horizontal~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Array[@boxplot.BoxStats] raise @core.DataError {
  if data.length() == 0 {
    raise @core.DataError::InvalidBoxPlot(
      message="boxplot requires at least one series",
    )
  }
  let stats = Array(capacity=data.length())
  for values in data {
    stats.push(@boxplot.box_stats(values))
  }
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::BoxPlot(stats.copy(), horizontal, @core.style(resolved_color)),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
  self.add_container(ContainerKind::BoxPlot, start, label)
  stats
}
