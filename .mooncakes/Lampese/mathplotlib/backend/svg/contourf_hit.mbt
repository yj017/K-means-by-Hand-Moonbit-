///|
// Actual emitted loops passed the writer; source identity was guarded once.
fn collect_contourf_region(
  hits : DrawingCapture,
  source : @render.ContourFHitData?,
  panel_index : Int32,
  artist_index : Int32,
  rings : Array[Array[@core.Point]],
  even_odd : Bool,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  style : @core.Style,
  figure_width : Int32,
  figure_height : Int32,
) -> Unit {
  guard source is Some(data) else { return }
  let (lower, upper) = data.interval()
  if !data.enabled() ||
    !violin_screen_finite(lower) ||
    !violin_screen_finite(upper) ||
    !violin_screen_finite(data.value()) {
    return
  }
  collect_filled_region(
    hits,
    panel_index,
    artist_index,
    data.slot(),
    rings,
    even_odd,
    scale,
    bounds,
    style,
    figure_width,
    figure_height,
    point => {
      @drawing.hit_info(
        point,
        ContourF,
        value=data.value(),
        interval=Some(data.interval()),
        series=data.series(),
      )
    },
  )
}
