///|
fn collect_tripcolor_region(
  hits : DrawingCapture,
  source : @render.TripcolorHitData?,
  panel_index : Int32,
  artist_index : Int32,
  points : Array[@core.Point],
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  style : @core.Style,
  figure_width : Int32,
  figure_height : Int32,
) -> Unit {
  guard source is Some(data) else { return }
  if !data.enabled() || !violin_screen_finite(data.value()) {
    return
  }
  collect_filled_region(
    hits,
    panel_index,
    artist_index,
    data.slot(),
    [points],
    false,
    scale,
    bounds,
    style,
    figure_width,
    figure_height,
    point => {
      @drawing.hit_info(
        point,
        Tripcolor,
        value=data.value(),
        tricolor=Some(data.info()),
        series=data.series(),
      )
    },
  )
}
