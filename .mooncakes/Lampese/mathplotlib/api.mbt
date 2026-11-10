///|
/// Public core values are re-exported from the facade package.
pub using @core {
  type BarSegment,
  bar_segment,
  type Bounds,
  type DataError,
  type Limits,
  type MaskedArray,
  type MaskedMatrix,
  type MaskError,
  type Point,
  type Series,
  type Style,
  type LineStroke,
  bounds,
  bounds_from_points,
  limits,
  masked_array,
  masked_matrix,
  point,
  series,
  style,
  line_stroke,
}

///|
/// Prepared output and data-point locations for interactive adapters.
pub using @drawing {
  type Drawing,
  type FilledRegion,
  filled_region,
  type HitPoint,
  type HitInfo,
  type CellInfo,
  type ErrorInfo,
  type BandInfo,
  type BoxInfo,
  type BoxPart,
  type HexbinInfo,
  type HexbinReduction,
  type ViolinInfo,
  type ViolinPart,
  type VectorInfo,
  type TriColorInfo,
  type StreamplotInfo,
  streamplot_info,
  tricolor_info,
  type HitKind,
  type HitMode,
  type HitShape,
  type HitTarget,
}

///|
/// Typed RGB and RGBA values used by colored image inputs.
pub using @colors {type Rgb, type Rgba, rgb, rgba}

///|
/// The object-style figure API is owned by the scene package.
pub using @scene {
  type Artist,
  type Axes,
  type PolarAxes,
  type PolarDirection,
  type Figure,
  type Line2D,
  type LineData,
  type LegendPosition,
  type SubFigure,
  type Histogram,
  type ContourSet,
  type ViolinBandwidth,
  type ViolinSide,
  type ViolinStats,
  type SecondaryAxis,
  type SecondaryAxisLocation,
  type SecondaryAxisAlignment,
  type StreamplotSet,
  figure,
}

///|
/// Axis configuration is exposed as a separate value object.
pub using @axis {type Axis, axis}

///|
/// Ordered string-to-position category conversion.
pub using @category {type CategoryAxis, category}

///|
/// Linear, logarithmic, Asinh and Logit coordinate scales.
pub using @scale {type Scale, linear_scale, log_scale, asinh_scale, logit_scale}

///|
/// Numeric tick formatters and the main Matplotlib-style formatter helpers.
pub using @ticker {
  type Formatter,
  scalar_formatter,
  fixed_formatter,
  index_formatter,
  format_str_formatter,
  str_method_formatter,
  eng_formatter,
  percent_formatter,
  log_formatter,
  null_formatter,
  func_formatter,
}

///|
/// Regular subplot grid layout values.
pub using @gridspec {type GridSpec, type LayoutError, type Rect, gridspec}

///|
/// Convenience function for a line plot rendered as SVG.
pub fn plot_svg(
  xs : Array[Double],
  ys : Array[Double],
) -> String raise DataError {
  let result = figure()
  result.plot(xs, ys)
  result.to_svg()
}
