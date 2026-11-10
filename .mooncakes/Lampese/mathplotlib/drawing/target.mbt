///|
/// The plotted primitive described by a hit target.
pub(all) enum HitKind {
  Line
  Scatter
  Bar
  BarH
  Histogram
  Histogram2D
  Hexbin
  Pie
  Heatmap
  ErrorBar
  Area
  BoxPlot
  Violin
  Step
  Stairs
  Ecdf
  Stem
  Quiver
  Barbs
  Contour
  ContourF
  Tripcolor
  Streamplot
  Polar
  PolarBar
} derive(Eq, Debug)

///|
pub extend HitKind with Eq::{equal, not_equal}

///|
pub extend HitKind with @debug.Debug::{to_repr}

///|
/// XNearest falls back to a real line/error-bar sample nearest in screen X inside a panel.
pub(all) enum HitMode {
  Nearest
  XNearest
} derive(Eq, Debug)

///|
pub extend HitMode with Eq::{equal, not_equal}

///|
pub extend HitMode with @debug.Debug::{to_repr}

///|
/// Intrinsic drawing geometry. Rectangles use left, top, width, height.
/// Sectors use center X/Y, radius, start degrees and positive CCW sweep degrees;
/// angles follow mathematical coordinates, with the screen Y direction reversed.
/// Nonpositive sizes/sweeps and nonfinite geometry do not hit; rectangle and
/// sector edges are included, and sweeps of at least 360 degrees are full circles.
/// Annular sectors use center X/Y, inner radius, outer radius, start and sweep.
/// Inner/outer edges are included; a positive inner radius excludes the hole.
/// Quadrilaterals list four consecutive vertices, with included edges and an
/// even-odd interior. They retain only immutable numeric coordinates.
pub(all) enum HitShape {
  Point
  /// A finite centerline segment; proximity uses the caller's CSS pixel radius.
  Segment(Double, Double, Double, Double)
  /// One immutable filled path; all subpaths share its actual SVG fill rule.
  FilledRegion(FilledRegion)
  Rectangle(Double, Double, Double, Double)
  Sector(Double, Double, Double, Double, Double)
  AnnularSector(Double, Double, Double, Double, Double, Double)
  Quadrilateral(Double, Double, Double, Double, Double, Double, Double, Double)
} derive(Eq, Debug)

///|
pub extend HitShape with Eq::{equal, not_equal}

///|
pub extend HitShape with @debug.Debug::{to_repr}

///|
/// Semantic values captured with the same immutable frame as its hit point.
pub struct HitInfo {
  point : HitPoint
  kind : HitKind
  series : String
  category : String?
  value : Double
  interval : (Double, Double)?
  fraction : Double?
  cell : CellInfo?
  error : ErrorInfo?
  band : BandInfo?
  box : BoxInfo?
  hexbin : HexbinInfo?
  violin : ViolinInfo?
  vector : VectorInfo?
  tricolor : TriColorInfo?
  streamplot : StreamplotInfo?
} derive(Eq, Debug)

///|
pub extend HitInfo with Eq::{equal, not_equal}

///|
pub extend HitInfo with @debug.Debug::{to_repr}

///|
pub fn hit_info(
  point : HitPoint,
  kind : HitKind,
  value~ : Double,
  series~ : String = "",
  category~ : String? = None,
  interval~ : (Double, Double)? = None,
  fraction~ : Double? = None,
  cell~ : CellInfo? = None,
  error~ : ErrorInfo? = None,
  band~ : BandInfo? = None,
  box~ : BoxInfo? = None,
  hexbin~ : HexbinInfo? = None,
  violin~ : ViolinInfo? = None,
  vector~ : VectorInfo? = None,
  tricolor~ : TriColorInfo? = None,
  streamplot~ : StreamplotInfo? = None,
) -> HitInfo {
  {
    point,
    kind,
    series,
    category,
    value,
    interval,
    fraction,
    cell,
    error,
    band,
    box,
    hexbin,
    violin,
    vector,
    tricolor,
    streamplot,
  }
}

///|
/// A hit geometry and the displayed panel rectangle that clips it.
pub struct HitTarget {
  info : HitInfo
  shape : HitShape
  bounds : (Double, Double, Double, Double)
} derive(Eq, Debug)

///|
pub extend HitTarget with Eq::{equal, not_equal}

///|
pub extend HitTarget with @debug.Debug::{to_repr}

///|
pub fn hit_target(
  info : HitInfo,
  shape : HitShape,
  bounds : (Double, Double, Double, Double),
) -> HitTarget {
  { info, shape, bounds, }
}
