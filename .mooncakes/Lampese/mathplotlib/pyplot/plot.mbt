///|
/// Add a line plot to the current figure.
pub fn plot(
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().plot(xs, ys, color~, label~)
}

///|
/// Add typed line data and retain a mutable data handle.
pub fn plot_line(
  xs : @scene.LineData,
  ys : @scene.LineData,
  color~ : String = "",
  label~ : String = "",
) -> @scene.Line2D raise @core.DataError {
  require_axes().plot_line(xs, ys, color~, label~)
}

///|
/// Add a line whose x coordinates are string categories to the current axes.
pub fn plot_category(
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().plot_category(categories, values, color~, label~)
}

///|
/// Add a line whose y coordinates are string categories to the current axes.
pub fn plot_category_y(
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().plot_category_y(values, categories, color~, label~)
}

///|
/// Add a line with optional symmetric x/y error bars to the current figure.
pub fn errorbar(
  xs : Array[Double],
  ys : Array[Double],
  yerr~ : Array[Double] = [],
  xerr~ : Array[Double] = [],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().errorbar(xs, ys, yerr~, xerr~, color~, label~)
}

///|
/// Add a step plot to the current axes.
pub fn step(
  xs : Array[Double],
  ys : Array[Double],
  where_~ : String = "pre",
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().step(xs, ys, where_~, color~, label~)
}

///|
/// Fill the area between two x series at y positions on the current axes.
pub fn fill_betweenx(
  ys : Array[Double],
  left : Array[Double],
  right~ : Array[Double] = [],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().fill_betweenx(ys, left, right~, color~, label~)
}

///|
/// Draw a stepwise constant function on the current axes.
pub fn stairs(
  values : Array[Double],
  edges~ : Array[Double] = [],
  orientation~ : String = "vertical",
  baseline~ : Double = 0.0,
  fill~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().stairs(
    values,
    edges~,
    orientation~,
    baseline~,
    fill~,
    color~,
    label~,
  )
}

///|
/// Draw stems from a baseline on the current axes.
pub fn stem(
  heads : Array[Double],
  locs~ : Array[Double] = [],
  bottom~ : Double = 0.0,
  orientation~ : String = "vertical",
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().stem(heads, locs~, bottom~, orientation~, color~, label~)
}

///|
/// Draw parallel event markers on the current axes.
pub fn eventplot(
  positions : Array[Array[Double]],
  orientation~ : String = "horizontal",
  lineoffsets~ : Array[Double] = [],
  linelengths~ : Array[Double] = [],
  linewidth~ : Double = 1.0,
  color~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().eventplot(
    positions,
    orientation~,
    lineoffsets~,
    linelengths~,
    linewidth~,
    color~,
  )
}

///|
/// Fill a closed polygon on the current axes.
pub fn fill(
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().fill(xs, ys, color~, label~)
}

///|
/// Draw horizontal broken bars on the current axes.
pub fn broken_barh(
  xranges : Array[(Double, Double)],
  yrange : (Double, Double),
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().broken_barh(xranges, yrange, color~, label~)
}

///|
/// Add scatter points to the current figure.
pub fn scatter(
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let points = @core.series(xs, ys).points()
  require_axes().scatter(points, color~, label~)
}

///|
/// Add per-point marker colors and sizes to the current axes.
pub fn scatter_collection(
  xs : Array[Double],
  ys : Array[Double],
  colors~ : Array[String] = [],
  sizes~ : Array[Double] = [],
  label~ : String = "",
) -> @scene.PathCollection raise @core.DataError {
  let points = @core.series(xs, ys).points()
  require_axes().scatter_collection(points, colors~, sizes~, label~)
}

///|
/// Add scatter points whose x coordinates are string categories.
pub fn scatter_category(
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().scatter_category(categories, values, color~, label~)
}

///|
/// Add scatter points whose y coordinates are string categories.
pub fn scatter_category_y(
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().scatter_category_y(values, categories, color~, label~)
}

///|
/// Add bars to the current figure.
pub fn bar(
  xs : Array[Double],
  heights : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let points = @core.series(xs, heights).points()
  require_axes().bar(points, color~, label~)
}

///|
/// Add bars whose x coordinates are string categories.
pub fn bar_category(
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().bar_category(categories, values, color~, label~)
}

///|
/// Add horizontal bars whose y coordinates are string categories.
pub fn bar_category_y(
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().bar_category_y(values, categories, color~, label~)
}

///|
/// Add horizontal bars to the current figure.
pub fn barh(
  ys : Array[Double],
  widths : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().barh(ys, widths, color~, label~)
}

///|
/// Draw horizontal line segments on the current axes.
pub fn hlines(
  ys : Array[Double],
  xmin : Double,
  xmax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().hlines(ys, xmin, xmax, color~, label~)
}

///|
/// Draw vertical line segments on the current axes.
pub fn vlines(
  xs : Array[Double],
  ymin : Double,
  ymax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().vlines(xs, ymin, ymax, color~, label~)
}

///|
/// Fill a horizontal span on the current axes.
pub fn axhspan(
  ymin : Double,
  ymax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().axhspan(ymin, ymax, color~, label~)
}

///|
/// Fill a vertical span on the current axes.
pub fn axvspan(
  xmin : Double,
  xmax : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().axvspan(xmin, xmax, color~, label~)
}

///|
/// Fill the area between two y series on the current figure.
pub fn fill_between(
  xs : Array[Double],
  lower : Array[Double],
  upper : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().fill_between(xs, lower, upper, color~, label~)
}

///|
/// Add a logarithmic x/y plot to the current axes.
pub fn loglog(
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().loglog(xs, ys, color~, label~)
}

///|
/// Add a plot with logarithmic x coordinates to the current axes.
pub fn semilogx(
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().semilogx(xs, ys, color~, label~)
}

///|
/// Add a plot with logarithmic y coordinates to the current axes.
pub fn semilogy(
  xs : Array[Double],
  ys : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().semilogy(xs, ys, color~, label~)
}

///|
/// Draw a horizontal reference line on the current figure.
pub fn axhline(
  value : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().axhline(value, color~, label~)
}

///|
/// Draw a vertical reference line on the current figure.
pub fn axvline(
  value : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().axvline(value, color~, label~)
}

///|
/// Draw an infinitely long line through one or two data points.
pub fn axline(
  xy1 : @core.Point,
  xy2? : @core.Point,
  slope? : Double,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  match (xy2, slope) {
    (Some(xy2), Some(slope)) =>
      require_axes().axline(xy1, xy2~, slope~, color~, label~)
    (Some(xy2), None) => require_axes().axline(xy1, xy2~, color~, label~)
    (None, Some(slope)) => require_axes().axline(xy1, slope~, color~, label~)
    (None, None) => require_axes().axline(xy1, color~, label~)
  }
}
