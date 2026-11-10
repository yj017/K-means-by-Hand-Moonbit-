///|
/// Compute and draw a histogram on the current figure.
pub fn hist(
  values : Array[Double],
  bins~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
) -> @scene.Histogram raise @core.DataError {
  require_axes().hist(values, bins~, color~, label~)
}

///|
/// Draw a pie chart on the current axes.
pub fn pie(
  values : Array[Double],
  labels~ : Array[String] = [],
  colors~ : Array[String] = [],
  start_angle~ : Double = 0.0,
) -> Array[Double] raise @core.DataError {
  require_axes().pie(values, labels~, colors~, start_angle~)
}

///|
/// Draw box-and-whisker plots on the current axes.
pub fn boxplot(
  data : Array[Array[Double]],
  horizontal~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Array[@boxplot.BoxStats] raise @core.DataError {
  require_axes().boxplot(data, horizontal~, color~, label~)
}

///|
/// Compute and draw a two-dimensional histogram on the current axes.
pub fn hist2d(
  xs : Array[Double],
  ys : Array[Double],
  bins_x~ : Int32 = 10,
  bins_y~ : Int32 = 10,
  cmap~ : String = "viridis",
) -> Unit raise @core.DataError {
  require_axes().hist2d(xs, ys, bins_x~, bins_y~, cmap~)
}

///|
/// Draw Gaussian kernel-density violins on the current axes.
pub fn violinplot(
  data : Array[Array[Double]],
  positions~ : Array[Double] = [],
  width~ : Double = 0.5,
  widths~ : Array[Double] = [],
  horizontal~ : Bool = false,
  side~ : @scene.ViolinSide = @scene.ViolinSide::Both,
  showmeans~ : Bool = false,
  showextrema~ : Bool = true,
  showmedians~ : Bool = false,
  quantiles~ : Array[Array[Double]] = [],
  points~ : Int32 = 100,
  bandwidth~ : @scene.ViolinBandwidth = @scene.ViolinBandwidth::Scott,
  color~ : String = "",
  facecolor~ : String = "",
  linecolor~ : String = "",
  label~ : String = "",
) -> Array[@scene.ViolinStats] raise @core.DataError {
  require_axes().violinplot(
    data,
    positions~,
    width~,
    widths~,
    horizontal~,
    side~,
    showmeans~,
    showextrema~,
    showmedians~,
    quantiles~,
    points~,
    bandwidth~,
    color~,
    facecolor~,
    linecolor~,
    label~,
  )
}

///|
/// Plot and return an autocorrelation sequence on the current axes.
/// `detrend` receives an owned copy of the samples and must preserve its
/// length; `@scene.detrend_mean` and `@scene.detrend_linear` cover common
/// cases.
pub fn acorr(
  values : Array[Double],
  normed~ : Bool = true,
  usevlines~ : Bool = true,
  maxlags~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
  detrend~ : (Array[Double]) -> Array[Double] = @scene.detrend_none,
) -> @scene.Correlation raise @core.DataError {
  require_axes().acorr(
    values,
    normed~,
    usevlines~,
    maxlags~,
    color~,
    label~,
    detrend~,
  )
}

///|
/// Plot and return a cross-correlation sequence on the current axes.
/// The detrending function is applied independently to both input sequences.
pub fn xcorr(
  first : Array[Double],
  second : Array[Double],
  normed~ : Bool = true,
  usevlines~ : Bool = true,
  maxlags~ : Int32 = 10,
  color~ : String = "",
  label~ : String = "",
  detrend~ : (Array[Double]) -> Array[Double] = @scene.detrend_none,
) -> @scene.Correlation raise @core.DataError {
  require_axes().xcorr(
    first,
    second,
    normed~,
    usevlines~,
    maxlags~,
    color~,
    label~,
    detrend~,
  )
}

///|
/// Plot and return an empirical cumulative distribution function.
pub fn ecdf(
  values : Array[Double],
  weights~ : Array[Double] = [],
  complementary~ : Bool = false,
  horizontal~ : Bool = false,
  compress~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> @scene.Ecdf raise @core.DataError {
  require_axes().ecdf(
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
/// Bin points into regular hexagons on the current axes.
pub fn hexbin(
  xs : Array[Double],
  ys : Array[Double],
  values~ : Array[Double] = [],
  gridsize~ : Int32 = 20,
  mincnt~ : Int32 = 0,
  cmap~ : String = "viridis",
  vmin? : Double,
  vmax? : Double,
  color~ : String = "",
  label~ : String = "",
  reduce~ : String = "mean",
  edgecolor~ : String = "",
  linewidth~ : Double = 0.0,
  bins~ : String = "linear",
  extent~ : Array[Double] = [],
  marginals~ : Bool = false,
  reduce_fn? : @scene.HexbinReducer,
) -> @scene.Hexbin raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        vmin~,
        vmax~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
    (Some(vmin), None) =>
      require_axes().hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        vmin~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
    (None, Some(vmax)) =>
      require_axes().hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        vmax~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
    (None, None) =>
      require_axes().hexbin(
        xs,
        ys,
        values~,
        gridsize~,
        mincnt~,
        cmap~,
        color~,
        label~,
        reduce~,
        edgecolor~,
        linewidth~,
        bins~,
        extent~,
        marginals~,
        reduce_fn~,
      )
  }
}

///|
/// Plot the sparsity pattern of a rectangular matrix on the current axes.
pub fn spy(
  data : Array[Array[Double]],
  precision~ : Double = 0.0,
  color~ : String = "",
  label~ : String = "",
  markersize~ : Double = 3.5,
  origin~ : String = "upper",
  aspect~ : String = "equal",
  marker~ : String = "o",
) -> Unit raise @core.DataError {
  require_axes().spy(
    data,
    precision~,
    color~,
    label~,
    markersize~,
    origin~,
    aspect~,
    marker~,
  )
}
