///|
/// Mutable state owned by one independent axes panel.
struct AxesData {
  artists : Array[Artist]
  mut polar : PolarState?
  line_originals : Array[Line2D]
  artist_hits : Array[ArtistHitData]
  barb_intents : Map[Int32, BarbIntent]
  contour_intents : Map[Int32, ContourIntent]
  contourf_intents : Map[Int32, ContourFIntent]
  tricolor_intents : Map[Int32, TripcolorIntent]
  streamplot_intents : Map[Int32, StreamplotIntent]
  x_axis : @axis.Axis
  y_axis : @axis.Axis
  mut title : String?
  mut explicit_bounds : @core.Bounds?
  mut legend : Array[LegendEntry]
  auto_legend : Array[LegendEntry]
  mut explicit_legend : Bool
  mut legend_position : LegendPosition
  containers : Array[Container]
  rect : @gridspec.Rect?
  mut position_override : @gridspec.Rect?
  mut active_position : @gridspec.Rect?
  mut subplot_spec : @gridspec.SubplotSpec?
  mut share_x_group : Int32?
  mut share_y_group : Int32?
  mut share_x_order : Int64
  mut share_y_order : Int64
  mut share_x_target : @ref.Ref[AxesData]?
  mut share_y_target : @ref.Ref[AxesData]?
  mut share_x_members : SharedAxesGroup?
  mut share_y_members : SharedAxesGroup?
  mut show_x_tick_labels : Bool
  mut show_y_tick_labels : Bool
  mut frame_visible : Bool
  spines : Array[SpineState]
  mut x_margin : Double
  mut y_margin : Double
  mut raw_x_data : @core.Limits
  mut raw_y_data : @core.Limits
  mut x_data_minpos : Double
  mut y_data_minpos : Double
  mut ignore_existing_data_limits : Bool
  mut tight : Bool?
  mut use_sticky_edges : Bool
  color_cycle : Array[String]
  mut color_cycle_index : Int32
  mut data_aspect : Double?
  mut anchor : Anchor
  mut adjustable : String
  mut box_aspect : Double?
  secondary_x : Array[SecondaryAxis]
  secondary_y : Array[SecondaryAxis]
}

///|
/// State retained by a SubFigure handle and consumed by the renderer.
struct SubFigureData {
  spec : @gridspec.SubplotSpec
  mut title : String?
  axes : Array[@ref.Ref[AxesData]]
  subfigures : Array[@ref.Ref[SubFigureData]]
}

///|
/// Clear the presentation state retained by a nested figure tree.
fn SubFigureData::clear_titles(self : SubFigureData) -> Unit {
  for child in self.subfigures {
    child.val.clear_titles()
  }
  self.title = None
}

///|
fn AxesData::clear_presentation(self : AxesData) -> Unit {
  for line in self.line_originals {
    line.clear_attachment()
  }
  self.artists.clear()
  if self.polar is Some(polar) {
    polar.closed.clear()
    polar.hit_data.clear()
    polar.radar_labels = None
  }
  self.artist_hits.clear()
  self.barb_intents.clear()
  self.contour_intents.clear()
  self.contourf_intents.clear()
  self.tricolor_intents.clear()
  self.streamplot_intents.clear()
  self.line_originals.clear()
  self.title = None
  self.explicit_bounds = None
  self.legend.clear()
  self.auto_legend.clear()
  self.containers.clear()
  self.explicit_legend = false
  self.legend_position = UpperRight
  self.show_x_tick_labels = true
  self.show_y_tick_labels = true
  self.frame_visible = true
  self.spines.clear()
  for spine in default_spines() {
    self.spines.push(spine)
  }
  self.x_margin = @config.x_margin()
  self.y_margin = @config.y_margin()
  self.ignore_existing_data_limits = true
  self.tight = None
  self.use_sticky_edges = true
  self.color_cycle.clear()
  for color in default_color_cycle() {
    self.color_cycle.push(color)
  }
  self.color_cycle_index = 0
  self.data_aspect = None
  self.secondary_x.clear()
  self.secondary_y.clear()
  if self.polar is Some(polar) {
    polar.cartesian_grid = [
      polar_grid_signature(self.x_axis),
      polar_grid_signature(self.y_axis),
    ]
    polar.cartesian_margins = (self.x_margin, self.y_margin)
  }
}

///|
/// Allocate a never-reused projection id for a retained sharing group.
fn Figure::allocate_share_group(self : Figure, count : Int32) -> Int32 {
  let result = self.share_group_seed
  self.share_group_seed -= count
  result
}

///|
fn Figure::default_axes_data(self : Figure) -> @ref.Ref[AxesData] {
  if self.axes.is_empty() {
    return self.add_subplot(try! @gridspec.gridspec(1, 1).cell_spec(0, 0)).state
  }
  self.axes[0]
}

///|
fn Axes::push_artist(self : Axes, artist : Artist) -> Unit {
  self.state.val.artists.push(artist)
  self.state.val.artist_hits.push({
    artist,
    series: "",
    histogram_edges: None,
    band_horizontal: None,
    band_values: None,
    mesh: None,
    hexbin: None,
    discrete: None,
    stem: None,
    vector: None,
    barb: None,
    contour: None,
    contourf: None,
    tricolor: None,
    streamplot: None,
  })
  if self.state.val.polar is Some(_) {
    return
  }
  self.update_artist_data_limits(artist)
  match artist {
    Artist::Text(_, _, _, _) | Artist::Annotation(_) | Artist::Table(_) => ()
    Artist::HLine(_, _) | Artist::HSpan(_, _, _) =>
      self.state.val.y_axis.request_autoscale()
    Artist::VLine(_, _) | Artist::VSpan(_, _, _) =>
      self.state.val.x_axis.request_autoscale()
    _ => {
      self.state.val.x_axis.request_autoscale()
      self.state.val.y_axis.request_autoscale()
    }
  }
}

///|
fn Figure::insert_axes_state(self : Figure, state : @ref.Ref[AxesData]) -> Unit {
  if self.axes.length() == 1 {
    let current = self.axes[0].val
    let empty = current.artists.length() == 0 &&
      current.title is None &&
      current.explicit_bounds is None &&
      current.legend.length() == 0 &&
      current.auto_legend.length() == 0 &&
      current.rect is None &&
      current.position_override is None &&
      current.x_axis.label() is None &&
      current.y_axis.label() is None &&
      current.x_axis.limits() is None &&
      current.y_axis.limits() is None &&
      self.colorbars.length() == 0
    if empty {
      self.axes_selection.retain(item => !physical_equal(item, self.axes[0]))
      self.axes[0] = state
      self.axes_selection.push(state)
      self.initialize_axes_state(state)
      return
    }
  }
  self.axes.push(state)
  self.axes_selection.push(state)
  self.initialize_axes_state(state)
}

///|
/// Allocate an independent axes state with an explicit display rectangle.
fn new_axes_state(
  rect : @gridspec.Rect?,
  spec : @gridspec.SubplotSpec?,
) -> @ref.Ref[AxesData] {
  @ref.new({
    artists: [],
    polar: None,
    line_originals: [],
    artist_hits: [],
    barb_intents: Map([]),
    contour_intents: Map([]),
    contourf_intents: Map([]),
    tricolor_intents: Map([]),
    streamplot_intents: Map([]),
    x_axis: @axis.axis(),
    y_axis: @axis.axis(horizontal=false),
    title: None,
    explicit_bounds: None,
    legend: [],
    auto_legend: [],
    explicit_legend: false,
    legend_position: UpperRight,
    containers: [],
    rect,
    position_override: None,
    active_position: None,
    subplot_spec: spec,
    share_x_group: None,
    share_y_group: None,
    share_x_order: 0L,
    share_y_order: 0L,
    share_x_target: None,
    share_y_target: None,
    share_x_members: None,
    share_y_members: None,
    show_x_tick_labels: true,
    show_y_tick_labels: true,
    frame_visible: true,
    spines: default_spines(),
    x_margin: @config.x_margin(),
    y_margin: @config.y_margin(),
    raw_x_data: @core.limits(1.0 / 0.0, -1.0 / 0.0),
    raw_y_data: @core.limits(1.0 / 0.0, -1.0 / 0.0),
    x_data_minpos: 1.0 / 0.0,
    y_data_minpos: 1.0 / 0.0,
    ignore_existing_data_limits: true,
    tight: None,
    use_sticky_edges: true,
    color_cycle: default_color_cycle(),
    color_cycle_index: 0,
    data_aspect: None,
    anchor: Anchor::Named("C"),
    adjustable: "box",
    box_aspect: None,
    secondary_x: [],
    secondary_y: [],
  })
}

///|
fn Figure::add_subplot_with_targets(
  self : Figure,
  spec : @gridspec.SubplotSpec,
  x_target : @ref.Ref[AxesData]?,
  y_target : @ref.Ref[AxesData]?,
) -> Axes {
  let rect = self.subplot_rect(spec)
  let state = new_axes_state(Some(rect), Some(spec))
  state.val.share_x_target = x_target
  state.val.share_y_target = y_target
  self.insert_axes_state(state)
  { figure: self, state, }
}

///|
fn Figure::initialize_axes_state(
  self : Figure,
  state : @ref.Ref[AxesData],
) -> Unit {
  let axes : Axes = { figure: self, state, }
  axes.bind_axis_data(true)
  axes.bind_axis_data(false)
  // Only fresh panels and fresh construction targets reach this private path.
  // Public clear_checked retains checked failures from later user providers.
  try! axes.clear_checked()
}
