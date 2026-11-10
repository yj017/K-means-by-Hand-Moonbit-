///|
/// Backend input for a rendered figure. This package is intentionally internal;
/// public callers use scene.Figure instead.
pub(all) enum Artist {
  Line(Array[@core.Point], @core.Style)
  Scatter(Array[@core.Point], @core.Style)
  PathCollection(Array[@core.Point], Array[@core.Style])
  Bar(Array[@core.Point], @core.Style)
  BarH(Array[@core.Point], @core.Style)
  /// Explicit position, width and baseline for grouped or stacked bar segments.
  BarSegments(Array[@core.BarSegment], Bool, @core.Style)
  FillBetween(Array[@core.Point], Array[@core.Point], @core.Style)
  Polygon(Array[@core.Point], @core.Style)
  CompoundPolygon(Array[Array[@core.Point]], @core.Style)
  GouraudTriangle(Array[@core.Point], Array[String])
  HLine(Double, @core.Style)
  VLine(Double, @core.Style)
  AxLine(@core.Point, @core.Point, @core.Style)
  HSpan(Double, Double, @core.Style)
  VSpan(Double, Double, @core.Style)
  Text(Double, Double, String, @core.Style)
  Annotation(Annotation)
  ErrorBar(Array[@core.Point], Array[Double], Array[Double], @core.Style)
  Image(Array[Array[Double]], Double?, Double?, @colors.ColorMap)
  ImageNorm(
    Array[Array[Double]],
    @colors.ColorNorm,
    @colors.ColorMap,
    ImageOrigin,
    (Double, Double, Double, Double)?,
    Double,
    ImageInterpolation
  )
  /// An image whose pixels already carry RGB or RGBA colors.
  ColorImage(
    Array[Array[@colors.Rgba]],
    ImageOrigin,
    (Double, Double, Double, Double)?,
    Double,
    ImageInterpolation
  )
  Table(Table)
  Pie(Array[Double], Array[String], Array[String], Double)
  Donut(Array[Double], Array[String], Array[String], Double, Double)
  BoxPlot(Array[@boxplot.BoxStats], Bool, @core.Style)
  Quiver(Array[@core.Point], Array[@core.Point], @core.Style)
  Violin(
    Array[ViolinStats],
    Array[Double],
    Array[Double],
    Bool,
    ViolinSide,
    Bool,
    Bool,
    Bool,
    @core.Style,
    @core.Style,
    Double
  )
}

///|
/// Row orientation for raster images in the backend model.
pub(all) enum ImageOrigin {
  Upper
  Lower
}

///|
/// Image sampling policy forwarded from the scene package.
pub(all) enum ImageInterpolation {
  Nearest
  NoInterpolation
  Bilinear
  Bicubic
  Spline16
  Spline36
  Hanning
  Hamming
  Hermite
  Kaiser
  Quadric
  Catrom
  Gaussian
  Bessel
  Mitchell
  Sinc
  Lanczos
  Blackman
  Auto
  Antialiased
}

///|
pub struct Annotation {
  x : Double
  y : Double
  text_x : Double
  text_y : Double
  value : String
  xycoords : String
  textcoords : String
  connector : String
  arrow : Bool
  arrowcolor : String
  linewidth : Double
  head_length : Double
  head_width : Double
  style : @core.Style
}

///|
pub fn annotation(
  x : Double,
  y : Double,
  text_x : Double,
  text_y : Double,
  value : String,
  xycoords : String,
  textcoords : String,
  connector : String,
  arrow : Bool,
  arrowcolor : String,
  linewidth : Double,
  head_length : Double,
  head_width : Double,
  style : @core.Style,
) -> Annotation {
  {
    x,
    y,
    text_x,
    text_y,
    value,
    xycoords,
    textcoords,
    connector,
    arrow,
    arrowcolor,
    linewidth,
    head_length,
    head_width,
    style,
  }
}

///|
pub fn Annotation::x(self : Annotation) -> Double {
  self.x
}

///|
pub fn Annotation::y(self : Annotation) -> Double {
  self.y
}

///|
pub fn Annotation::text_x(self : Annotation) -> Double {
  self.text_x
}

///|
pub fn Annotation::text_y(self : Annotation) -> Double {
  self.text_y
}

///|
pub fn Annotation::value(self : Annotation) -> String {
  self.value
}

///|
pub fn Annotation::xycoords(self : Annotation) -> String {
  self.xycoords
}

///|
pub fn Annotation::textcoords(self : Annotation) -> String {
  self.textcoords
}

///|
pub fn Annotation::connector(self : Annotation) -> String {
  self.connector
}

///|
pub fn Annotation::arrow(self : Annotation) -> Bool {
  self.arrow
}

///|
pub fn Annotation::arrowcolor(self : Annotation) -> String {
  self.arrowcolor
}

///|
pub fn Annotation::linewidth(self : Annotation) -> Double {
  self.linewidth
}

///|
pub fn Annotation::head_length(self : Annotation) -> Double {
  self.head_length
}

///|
pub fn Annotation::head_width(self : Annotation) -> Double {
  self.head_width
}

///|
pub fn Annotation::style(self : Annotation) -> @core.Style {
  self.style
}

///|
pub struct TableCell {
  row : Int32
  column : Int32
  text : String
  facecolor : String
  edgecolor : String
  align : String
  visible_edges : String
}

///|
pub struct Table {
  cells : Array[TableCell]
  rows : Int32
  columns : Int32
  x : Double
  y : Double
  width : Double
  height : Double
  column_widths : Array[Double]
}

///|
pub fn table_cell(
  row : Int32,
  column : Int32,
  text : String,
  facecolor : String,
  edgecolor : String,
  align : String,
  visible_edges : String,
) -> TableCell {
  { row, column, text, facecolor, edgecolor, align, visible_edges, }
}

///|
pub fn table(
  cells : Array[TableCell],
  rows : Int32,
  columns : Int32,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  column_widths : Array[Double],
) -> Table {
  { cells, rows, columns, x, y, width, height, column_widths, }
}

///|
pub fn Table::cells(self : Table) -> Array[TableCell] {
  self.cells
}

///|
pub fn TableCell::row(self : TableCell) -> Int32 {
  self.row
}

///|
pub fn TableCell::column(self : TableCell) -> Int32 {
  self.column
}

///|
pub fn TableCell::text(self : TableCell) -> String {
  self.text
}

///|
pub fn TableCell::facecolor(self : TableCell) -> String {
  self.facecolor
}

///|
pub fn TableCell::edgecolor(self : TableCell) -> String {
  self.edgecolor
}

///|
pub fn TableCell::align(self : TableCell) -> String {
  self.align
}

///|
pub fn TableCell::visible_edges(self : TableCell) -> String {
  self.visible_edges
}

///|
pub fn Table::rows(self : Table) -> Int32 {
  self.rows
}

///|
pub fn Table::columns(self : Table) -> Int32 {
  self.columns
}

///|
pub fn Table::x(self : Table) -> Double {
  self.x
}

///|
pub fn Table::y(self : Table) -> Double {
  self.y
}

///|
pub fn Table::width(self : Table) -> Double {
  self.width
}

///|
pub fn Table::height(self : Table) -> Double {
  self.height
}

///|
pub fn Table::column_widths(self : Table) -> Array[Double] {
  self.column_widths
}

///|
pub(all) enum ViolinSide {
  Both
  Low
  High
}

///|
pub struct ViolinStats {
  coords : Array[Double]
  vals : Array[Double]
  mean : Double
  median : Double
  min : Double
  max : Double
  quantiles : Array[Double]
}

///|
pub fn violin_stats(
  coords : Array[Double],
  vals : Array[Double],
  mean : Double,
  median : Double,
  min : Double,
  max : Double,
  quantiles : Array[Double],
) -> ViolinStats {
  { coords, vals, mean, median, min, max, quantiles, }
}

///|
pub fn ViolinStats::coords(self : ViolinStats) -> Array[Double] {
  self.coords
}

///|
pub fn ViolinStats::vals(self : ViolinStats) -> Array[Double] {
  self.vals
}

///|
pub fn ViolinStats::mean(self : ViolinStats) -> Double {
  self.mean
}

///|
pub fn ViolinStats::median(self : ViolinStats) -> Double {
  self.median
}

///|
pub fn ViolinStats::min(self : ViolinStats) -> Double {
  self.min
}

///|
pub fn ViolinStats::max(self : ViolinStats) -> Double {
  self.max
}

///|
pub fn ViolinStats::quantiles(self : ViolinStats) -> Array[Double] {
  self.quantiles
}

///|
pub(all) enum LegendKind {
  Line
  Marker
  Patch
}

///|
/// Public presentation values are shared with all render backends.
pub using @core {type LegendPosition}

///|
pub struct LegendEntry {
  label : String
  color : String
  kind : LegendKind
}

///|
pub fn legend_entry(
  label : String,
  color : String,
  kind : LegendKind,
) -> LegendEntry {
  { label, color, kind, }
}

///|
pub fn LegendEntry::label(self : LegendEntry) -> String {
  self.label
}

///|
pub fn LegendEntry::color(self : LegendEntry) -> String {
  self.color
}

///|
pub fn LegendEntry::kind(self : LegendEntry) -> LegendKind {
  self.kind
}

///|
/// Location of a secondary coordinate axis in the backend model.
pub(all) enum SecondaryLocation {
  Top
  Bottom
  Left
  Right
}

///|
/// Immutable screen edges and decoration side of an owned secondary child.
pub struct SecondaryDrawingContext {
  left : Double
  top : Double
  right : Double
  bottom : Double
  alignment : SecondaryLocation
}

///|
pub fn SecondaryDrawingContext::new(
  left : Double,
  top : Double,
  right : Double,
  bottom : Double,
  alignment : SecondaryLocation,
) -> SecondaryDrawingContext {
  { left, top, right, bottom, alignment, }
}

///|
pub fn SecondaryDrawingContext::left(self : SecondaryDrawingContext) -> Double {
  self.left
}

///|
pub fn SecondaryDrawingContext::top(self : SecondaryDrawingContext) -> Double {
  self.top
}

///|
pub fn SecondaryDrawingContext::right(self : SecondaryDrawingContext) -> Double {
  self.right
}

///|
pub fn SecondaryDrawingContext::bottom(
  self : SecondaryDrawingContext,
) -> Double {
  self.bottom
}

///|
pub fn SecondaryDrawingContext::alignment(
  self : SecondaryDrawingContext,
) -> SecondaryLocation {
  self.alignment
}

///|
/// Immutable own-view geometry captured after a secondary's full tick batches.
pub struct SecondaryPlacement {
  lower : Double
  upper : Double
  transform : (Double) -> Double
}

///|
pub fn SecondaryPlacement::new(
  lower : Double,
  upper : Double,
  transform : (Double) -> Double,
) -> SecondaryPlacement {
  { lower, upper, transform, }
}

///|
pub fn SecondaryPlacement::lower(self : SecondaryPlacement) -> Double {
  self.lower
}

///|
pub fn SecondaryPlacement::upper(self : SecondaryPlacement) -> Double {
  self.upper
}

///|
pub fn SecondaryPlacement::transform(
  self : SecondaryPlacement,
) -> (Double) -> Double {
  self.transform
}

///|
/// Secondary transport with optional live Scene-owner lifecycle callbacks.
pub struct SecondaryAxis {
  draw_order : Int32?
  formatter_view_provider : (() -> (Double, Double))?
  synchronize_view_provider : (() -> Unit raise @core.DataError)?
  prepare_draw_provider : (() -> Unit raise @core.DataError)?
  positioned_aspect_provider : ((Double, Double, Double, Double) -> Unit raise @core.DataError)?
  drawing_context_provider : (() -> SecondaryDrawingContext)?
  placement_provider : (() -> SecondaryPlacement)?
  locator_provider : (() -> @ticker.Locator?)?
  minor_locator_provider : (() -> @ticker.MinorLocator?)?
  fixed_ticks_provider : (() -> Array[Double]?)?
  formatter_provider : ((Bool) -> @ticker.BaseFormatter?)?
  legacy_formatter_provider : (() -> @ticker.Formatter?)?
  null_group_provider : ((Bool) -> Bool)?
  named_formatter : @ticker.BaseFormatter?
  minor_named_formatter : @ticker.BaseFormatter?
  major_formatter_locations_provider : (() -> @ticker.FormatterLocations raise @core.DataError)?
  minor_formatter_locations_provider : (() -> @ticker.FormatterLocations raise @core.DataError)?
  minor_locator : @ticker.MinorLocator?
  minor_ticks_provider : (() -> Array[Double] raise @core.DataError)?
  tick_label_size : Double
  location : SecondaryLocation
  forward : (Double) -> Double
  inverse : (Double) -> Double
  label : String?
  tick_count : Int32
  fixed_ticks : Array[Double]?
  locator : @ticker.Locator?
  formatter : @ticker.Formatter?
}

///|
fn copy_secondary_locator(locator : @ticker.Locator) -> @ticker.Locator {
  locator.copy()
}

///|
pub fn secondary_axis(
  location : SecondaryLocation,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  label : String?,
  tick_count : Int32,
  fixed_ticks : Array[Double]?,
  locator : @ticker.Locator?,
  formatter : @ticker.Formatter?,
  named_formatter~ : @ticker.BaseFormatter? = None,
  minor_named_formatter~ : @ticker.BaseFormatter? = None,
  formatter_provider~ : ((Bool) -> @ticker.BaseFormatter?)? = None,
  legacy_formatter_provider~ : (() -> @ticker.Formatter?)? = None,
  null_group_provider~ : ((Bool) -> Bool)? = None,
  major_formatter_locations_provider~ : (() -> @ticker.FormatterLocations raise @core.DataError)? = None,
  minor_formatter_locations_provider~ : (() -> @ticker.FormatterLocations raise @core.DataError)? = None,
  tick_label_size~ : Double = 10.0,
  minor_locator~ : @ticker.MinorLocator? = None,
  minor_ticks_provider~ : (() -> Array[Double] raise @core.DataError)? = None,
  synchronize_view_provider~ : (() -> Unit raise @core.DataError)? = None,
  prepare_draw_provider~ : (() -> Unit raise @core.DataError)? = None,
  positioned_aspect_provider~ : ((Double, Double, Double, Double) -> Unit raise @core.DataError)? = None,
  drawing_context_provider~ : (() -> SecondaryDrawingContext)? = None,
  placement_provider~ : (() -> SecondaryPlacement)? = None,
  locator_provider~ : (() -> @ticker.Locator?)? = None,
  minor_locator_provider~ : (() -> @ticker.MinorLocator?)? = None,
  fixed_ticks_provider~ : (() -> Array[Double]?)? = None,
  formatter_view_provider~ : (() -> (Double, Double))? = None,
  draw_order~ : Int32? = None,
) -> SecondaryAxis {
  {
    draw_order,
    synchronize_view_provider,
    prepare_draw_provider,
    positioned_aspect_provider,
    drawing_context_provider,
    placement_provider,
    locator_provider,
    minor_locator_provider,
    fixed_ticks_provider,
    formatter_view_provider,
    named_formatter,
    minor_named_formatter,
    formatter_provider,
    legacy_formatter_provider,
    null_group_provider,
    major_formatter_locations_provider,
    minor_formatter_locations_provider,
    minor_locator: minor_locator.map(value => value.copy()),
    minor_ticks_provider,
    tick_label_size,
    location,
    forward,
    inverse,
    label,
    tick_count,
    fixed_ticks: match fixed_ticks {
      Some(values) => Some(values.copy())
      None => None
    },
    locator: match locator {
      Some(value) => Some(copy_secondary_locator(value))
      None => None
    },
    formatter: match formatter {
      Some(value) => Some(value.copy())
      None => None
    },
  }
}

///|
/// Run the aspect-only owner synchronization, without changing default tickers.
pub fn SecondaryAxis::synchronize_view(
  self : SecondaryAxis,
) -> Bool raise @core.DataError {
  match self.synchronize_view_provider {
    Some(provider) => {
      provider()
      true
    }
    None => false
  }
}

///|
/// Run one owned child draw preparation after aspect layout and before batches.
pub fn SecondaryAxis::prepare_draw(
  self : SecondaryAxis,
) -> Bool raise @core.DataError {
  match self.prepare_draw_provider {
    Some(provider) => {
      provider()
      true
    }
    None => false
  }
}

///|
/// Apply owned position and limits at the current parent frame rectangle.
pub fn SecondaryAxis::positioned_aspect(
  self : SecondaryAxis,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
) -> Bool raise @core.DataError {
  match self.positioned_aspect_provider {
    Some(provider) => {
      provider(left, top, width, height)
      true
    }
    None => false
  }
}

///|
pub fn SecondaryAxis::drawing_context(
  self : SecondaryAxis,
) -> SecondaryDrawingContext? {
  self.drawing_context_provider.map(provider => provider())
}

///|
pub fn SecondaryAxis::has_placement_provider(self : SecondaryAxis) -> Bool {
  self.placement_provider is Some(_)
}

///|
pub fn SecondaryAxis::placement(self : SecondaryAxis) -> SecondaryPlacement? {
  self.placement_provider.map(provider => provider())
}

///|
/// Read the owner's stored interval before visibility transforms and offset text.
pub fn SecondaryAxis::formatter_view_interval(
  self : SecondaryAxis,
) -> (Double, Double)? {
  self.formatter_view_provider.map(provider => provider())
}

///|
/// Scene child creation order; absent for standalone transport.
pub fn SecondaryAxis::draw_order(self : SecondaryAxis) -> Int32? {
  self.draw_order
}

///|
pub fn SecondaryAxis::location(self : SecondaryAxis) -> SecondaryLocation {
  self.location
}

///|
pub fn SecondaryAxis::forward(self : SecondaryAxis) -> (Double) -> Double {
  self.forward
}

///|
pub fn SecondaryAxis::inverse(self : SecondaryAxis) -> (Double) -> Double {
  self.inverse
}

///|
pub fn SecondaryAxis::label(self : SecondaryAxis) -> String? {
  self.label
}

///|
pub fn SecondaryAxis::tick_count(self : SecondaryAxis) -> Int32 {
  self.tick_count
}

///|
pub fn SecondaryAxis::fixed_ticks(self : SecondaryAxis) -> Array[Double]? {
  let values = match self.fixed_ticks_provider {
    Some(provider) => provider()
    None => self.fixed_ticks
  }
  values.map(values => values.copy())
}

///|
pub fn SecondaryAxis::locator(self : SecondaryAxis) -> @ticker.Locator? {
  let locator = match self.locator_provider {
    Some(provider) => provider()
    None => self.locator
  }
  locator.map(value => copy_secondary_locator(value))
}

///|
pub fn SecondaryAxis::minor_locator(
  self : SecondaryAxis,
) -> @ticker.MinorLocator? {
  let locator = match self.minor_locator_provider {
    Some(provider) => provider()
    None => self.minor_locator
  }
  locator.map(value => value.copy())
}

///|
pub fn SecondaryAxis::formatter(self : SecondaryAxis) -> @ticker.Formatter? {
  let formatter = match self.legacy_formatter_provider {
    Some(provider) => provider()
    None => self.formatter
  }
  match formatter {
    Some(value) => Some(value.copy())
    None => None
  }
}

///|
pub fn SecondaryAxis::named_formatter(
  self : SecondaryAxis,
) -> @ticker.BaseFormatter? {
  match self.formatter_provider {
    Some(provider) => provider(false)
    None => self.named_formatter
  }
}

///|
pub fn SecondaryAxis::minor_named_formatter(
  self : SecondaryAxis,
) -> @ticker.BaseFormatter? {
  match self.formatter_provider {
    Some(provider) => provider(true)
    None => self.minor_named_formatter
  }
}

///|
pub fn SecondaryAxis::formatter_tick_locations(
  self : SecondaryAxis,
  minor~ : Bool = false,
) -> @ticker.FormatterLocations? raise @core.DataError {
  let provider = if minor {
    self.minor_formatter_locations_provider
  } else {
    self.major_formatter_locations_provider
  }
  match provider {
    Some(provider) => Some(provider())
    None => None
  }
}

///|
/// One axes border consumed by a backend renderer.
pub(all) enum SpineSide {
  Left
  Right
  Bottom
  Top
}

///|
pub(all) enum SpinePosition {
  Axes
  Data(Double)
  Outward(Double)
}

///|
pub struct Spine {
  side : SpineSide
  visible : Bool
  color : String
  linewidth : Double
  position : SpinePosition
  bounds : (Double, Double)?
}

///|
pub fn spine(
  side : SpineSide,
  visible : Bool,
  color : String,
  linewidth : Double,
  position : SpinePosition,
  bounds : (Double, Double)?,
) -> Spine {
  { side, visible, color, linewidth, position, bounds, }
}

///|
pub fn Spine::side(self : Spine) -> SpineSide {
  self.side
}

///|
pub fn Spine::visible(self : Spine) -> Bool {
  self.visible
}

///|
pub fn Spine::color(self : Spine) -> String {
  self.color
}

///|
pub fn Spine::linewidth(self : Spine) -> Double {
  self.linewidth
}

///|
pub fn Spine::position(self : Spine) -> SpinePosition {
  self.position
}

///|
pub fn Spine::bounds(self : Spine) -> (Double, Double)? {
  self.bounds
}

///|
/// Immutable render input for one axes panel.
pub struct Panel {
  rect : @gridspec.Rect?
  artists : Array[Artist]
  hit_metadata : Array[HitMetadata]
  polar : PolarProjection?
  line_provider : ((Array[@core.Point]) -> LineDrawingContext? raise @core.DataError)?
  title : String?
  legend : Array[LegendEntry]
  legend_position : LegendPosition
  explicit_bounds : @core.Bounds?
  x_axis : @axis.Axis
  y_axis : @axis.Axis
  share_x_group : Int32?
  share_y_group : Int32?
  show_x_tick_labels : Bool
  show_y_tick_labels : Bool
  frame_visible : Bool
  spines : Array[Spine]
  x_margin : Double
  y_margin : Double
  data_aspect : Double?
  anchor : (Double, Double)
  adjustable : String
  box_aspect : Double?
  secondary_x : Array[SecondaryAxis]
  secondary_y : Array[SecondaryAxis]
}

///|
/// Construct panel input. aspect overrides the legacy equal_aspect flag and
/// must be a positive finite y/x display ratio when supplied.
/// anchor uses lower-left fractions within the free space after shrinking.
/// box_aspect constrains physical dimensions when adjustable="datalim".
pub fn panel(
  rect : @gridspec.Rect?,
  artists : Array[Artist],
  title : String?,
  legend : Array[LegendEntry],
  explicit_bounds : @core.Bounds?,
  x_axis : @axis.Axis,
  y_axis : @axis.Axis,
  equal_aspect : Bool,
  secondary_x : Array[SecondaryAxis],
  secondary_y : Array[SecondaryAxis],
  aspect? : Double,
  anchor~ : (Double, Double) = (0.5, 0.5),
  adjustable~ : String = "box",
  box_aspect? : Double,
  line_provider~ : ((Array[@core.Point]) -> LineDrawingContext? raise @core.DataError)? = None,
  legend_position~ : LegendPosition = UpperRight,
  polar~ : PolarProjection? = None,
) -> Panel {
  panel_with_sharing(
    rect,
    artists,
    title,
    legend,
    explicit_bounds,
    x_axis,
    y_axis,
    None,
    None,
    equal_aspect,
    secondary_x,
    secondary_y,
    aspect?,
    anchor~,
    adjustable~,
    box_aspect?,
    line_provider~,
    legend_position~,
    polar~,
  )
}

///|
/// Construct panel input with explicit shared-axis group identifiers.
/// aspect overrides the legacy equal_aspect flag when supplied.
/// anchor uses lower-left fractions within the free space after shrinking.
/// box_aspect constrains physical dimensions when adjustable="datalim".
pub fn panel_with_sharing(
  rect : @gridspec.Rect?,
  artists : Array[Artist],
  title : String?,
  legend : Array[LegendEntry],
  explicit_bounds : @core.Bounds?,
  x_axis : @axis.Axis,
  y_axis : @axis.Axis,
  share_x_group : Int32?,
  share_y_group : Int32?,
  equal_aspect : Bool,
  secondary_x : Array[SecondaryAxis],
  secondary_y : Array[SecondaryAxis],
  show_x_tick_labels~ : Bool = true,
  show_y_tick_labels~ : Bool = true,
  frame_visible~ : Bool = true,
  x_margin~ : Double = 0.05,
  y_margin~ : Double = 0.05,
  spines~ : Array[Spine] = [],
  aspect? : Double,
  anchor~ : (Double, Double) = (0.5, 0.5),
  adjustable~ : String = "box",
  box_aspect? : Double,
  line_provider~ : ((Array[@core.Point]) -> LineDrawingContext? raise @core.DataError)? = None,
  legend_position~ : LegendPosition = UpperRight,
  hit_metadata~ : Array[HitMetadata] = [],
  polar~ : PolarProjection? = None,
) -> Panel {
  {
    rect,
    artists,
    hit_metadata: hit_metadata.copy(),
    polar,
    line_provider,
    title,
    legend,
    legend_position,
    explicit_bounds,
    x_axis,
    y_axis,
    share_x_group,
    share_y_group,
    show_x_tick_labels,
    show_y_tick_labels,
    frame_visible,
    spines,
    x_margin,
    y_margin,
    data_aspect: match aspect {
      Some(_) => aspect
      None => if equal_aspect { Some(1.0) } else { None }
    },
    anchor,
    adjustable,
    box_aspect,
    secondary_x,
    secondary_y,
  }
}

///|
/// Capture current owned Line geometry and ordered paints at its draw stage.
/// Append first, resolve/append foreground if present, then invoke completion.
pub fn Panel::prepare_line(
  self : Panel,
  points : Array[@core.Point],
) -> LineDrawingContext? raise @core.DataError {
  match self.line_provider {
    Some(provider) => provider(points)
    None => None
  }
}

///|
/// Return whether the primary x-axis tick labels are visible.
pub fn Panel::show_x_tick_labels(self : Panel) -> Bool {
  self.show_x_tick_labels
}

///|
/// Return whether the primary y-axis tick labels are visible.
pub fn Panel::show_y_tick_labels(self : Panel) -> Bool {
  self.show_y_tick_labels
}

///|
/// Return whether primary axis decorations should be rendered.
pub fn Panel::frame_visible(self : Panel) -> Bool {
  self.frame_visible
}

///|
/// Return the configured axes spines.
pub fn Panel::spines(self : Panel) -> Array[Spine] {
  self.spines
}

///|
/// Return the automatic x-axis margin for this panel.
pub fn Panel::x_margin(self : Panel) -> Double {
  self.x_margin
}

///|
/// Return the automatic y-axis margin for this panel.
pub fn Panel::y_margin(self : Panel) -> Double {
  self.y_margin
}

///|
/// Immutable render input for one nested figure region.
pub struct SubFigure {
  rect : @gridspec.Rect
  title : String?
}

///|
pub fn subfigure(rect : @gridspec.Rect, title : String?) -> SubFigure {
  { rect, title, }
}

///|
pub fn SubFigure::rect(self : SubFigure) -> @gridspec.Rect {
  self.rect
}

///|
pub fn SubFigure::title(self : SubFigure) -> String? {
  self.title
}

///|
/// Immutable render input shared by backend implementations.
pub struct Figure {
  width : Int32
  height : Int32
  margin : Int32
  panels : Array[Panel]
  colorbars : Array[@colorbar.Colorbar]
  subfigures : Array[SubFigure]
  title : String?
}

///|
pub fn figure(
  width : Int32,
  height : Int32,
  margin : Int32,
  panels : Array[Panel],
  colorbars : Array[@colorbar.Colorbar],
  title : String?,
) -> Figure {
  figure_with_subfigures(width, height, margin, panels, colorbars, [], title)
}

///|
pub fn figure_with_subfigures(
  width : Int32,
  height : Int32,
  margin : Int32,
  panels : Array[Panel],
  colorbars : Array[@colorbar.Colorbar],
  subfigures : Array[SubFigure],
  title : String?,
) -> Figure {
  { width, height, margin, panels, colorbars, subfigures, title, }
}

///|
pub fn Figure::width(self : Figure) -> Int32 {
  self.width
}

///|
pub fn Figure::height(self : Figure) -> Int32 {
  self.height
}

///|
pub fn Figure::margin(self : Figure) -> Int32 {
  self.margin
}

///|
pub fn Figure::panels(self : Figure) -> Array[Panel] {
  self.panels
}

///|
pub fn Figure::colorbars(self : Figure) -> Array[@colorbar.Colorbar] {
  self.colorbars
}

///|
pub fn Figure::subfigures(self : Figure) -> Array[SubFigure] {
  self.subfigures
}

///|
pub fn Panel::rect(self : Panel) -> @gridspec.Rect? {
  self.rect
}

///|
pub fn Panel::artists(self : Panel) -> Array[Artist] {
  self.artists
}

///|
pub fn Panel::title(self : Panel) -> String? {
  self.title
}

///|
pub fn Panel::legend(self : Panel) -> Array[LegendEntry] {
  self.legend
}

///|
pub fn Panel::legend_position(self : Panel) -> LegendPosition {
  self.legend_position
}

///|
pub fn Panel::explicit_bounds(self : Panel) -> @core.Bounds? {
  self.explicit_bounds
}

///|
pub fn Panel::x_axis(self : Panel) -> @axis.Axis {
  self.x_axis
}

///|
pub fn Panel::y_axis(self : Panel) -> @axis.Axis {
  self.y_axis
}

///|
/// Return the shared x-axis group, if this panel belongs to one.
pub fn Panel::share_x_group(self : Panel) -> Int32? {
  self.share_x_group
}

///|
/// Return the shared y-axis group, if this panel belongs to one.
pub fn Panel::share_y_group(self : Panel) -> Int32? {
  self.share_y_group
}

///|
/// Return whether the panel requests equal data scaling.
pub fn Panel::equal_aspect(self : Panel) -> Bool {
  self.data_aspect == Some(1.0)
}

///|
/// Return the numeric y/x display scale ratio, or None for automatic aspect.
///
/// ```mbt check
/// test {
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     @axis.axis(),
///     @axis.axis(),
///     false,
///     [],
///     [],
///     aspect=2.0,
///   )
///   assert_eq(panel.aspect(), Some(2.0))
///   assert_true(!panel.equal_aspect())
/// }
/// ```
pub fn Panel::aspect(self : Panel) -> Double? {
  self.data_aspect
}

///|
/// Return the anchor fractions relative to the allocated box's lower left.
///
/// ```mbt check
/// test {
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     @axis.axis(),
///     @axis.axis(),
///     true,
///     [],
///     [],
///     anchor=(0.0, 1.0),
///   )
///   assert_eq(panel.anchor(), (0.0, 1.0))
/// }
/// ```
pub fn Panel::anchor(self : Panel) -> (Double, Double) {
  self.anchor
}

///|
/// Return whether aspect changes the box ("box") or view limits ("datalim").
///
/// ```mbt check
/// test {
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     @axis.axis(),
///     @axis.axis(),
///     true,
///     [],
///     [],
///     adjustable="datalim",
///   )
///   assert_eq(panel.adjustable(), "datalim")
/// }
/// ```
pub fn Panel::adjustable(self : Panel) -> String {
  self.adjustable
}

///|
/// Return a physical height/width constraint, independently of data aspect.
///
/// ```mbt check
/// test {
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     @axis.axis(),
///     @axis.axis(),
///     false,
///     [],
///     [],
///     adjustable="datalim",
///     box_aspect=1.0,
///   )
///   assert_eq(panel.box_aspect(), Some(1.0))
/// }
/// ```
pub fn Panel::box_aspect(self : Panel) -> Double? {
  self.box_aspect
}

///|
pub fn Panel::secondary_x(self : Panel) -> Array[SecondaryAxis] {
  self.secondary_x
}

///|
pub fn Panel::secondary_y(self : Panel) -> Array[SecondaryAxis] {
  self.secondary_y
}

///|
pub fn Figure::title(self : Figure) -> String? {
  self.title
}

///|
pub fn SecondaryAxis::tick_label_size(self : SecondaryAxis) -> Double {
  self.tick_label_size
}

///|
pub fn SecondaryAxis::minor_tick_values(
  self : SecondaryAxis,
) -> Array[Double] raise @core.DataError {
  if self.tick_group_is_null(minor=true) {
    return []
  }
  match self.minor_ticks_provider {
    Some(provider) => provider()
    None => []
  }
}

///|
pub fn SecondaryAxis::tick_group_is_null(
  self : SecondaryAxis,
  minor~ : Bool = false,
) -> Bool {
  if self.null_group_provider is Some(provider) {
    return provider(minor)
  }
  if minor {
    self.minor_locator() is Some(@ticker.MinorLocator::Null(_))
  } else {
    self.locator() is Some(@ticker.Locator::Null(_))
  }
}
