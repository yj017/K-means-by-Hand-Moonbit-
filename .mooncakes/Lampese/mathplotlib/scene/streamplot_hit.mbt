///|
priv struct StreamplotSource {
  view : @render.StreamplotHitView
  cursor : @ref.Ref[Int32]
}

///|
priv struct StreamplotIntent {
  artist : Artist
  source : StreamplotSource
}

///|
fn Axes::push_streamplot_owned(
  self : Axes,
  artist : Artist,
  view : @render.StreamplotHitView,
) -> Unit {
  self.push_artist(artist)
  let source : StreamplotSource = { view, cursor: @ref.Ref(0), }
  let records = self.state.val.artist_hits
  records[records.length() - 1].streamplot = Some(source)
  records[records.length() - 1].series = view.series()
  self.state.val.streamplot_intents[self.state.val.artists.length() - 1] = {
    artist,
    source,
  }
}

///|
fn Axes::push_streamplot_arrow(
  self : Axes,
  artist : Artist,
  series : String,
) -> Unit {
  let points = match artist {
    Line(points, _) | Polygon(points, _) => points
    _ => []
  }
  self.push_streamplot_owned(
    artist,
    @render.streamplot_static_hit(points, series),
  )
}

///|
fn streamplot_sample_datum(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Array[Double]],
  vs : Array[Array[Double]],
  point : @core.Point,
  edge : Int32,
  seed_index : Int32,
  color_value : Double?,
) -> @render.StreamplotDatum? {
  if !point.is_finite() {
    return None
  }
  guard stream_sample(xs, ys, us, vs, point.x(), point.y()) is Some((u, v)) else {
    return None
  }
  if !stream_finite(u) || !stream_finite(v) {
    return None
  }
  Some(
    @render.streamplot_datum(
      edge,
      point,
      @drawing.streamplot_info(seed_index, u, v, color_value~),
    ),
  )
}

///|
fn AxesData::remove_streamplot_slot(self : AxesData, removed : Int32) -> Unit {
  if self.streamplot_intents.is_empty() {
    return
  }
  let next = Map([])
  for slot, intent in self.streamplot_intents {
    if slot != removed {
      next[if slot > removed { slot - 1 } else { slot }] = intent
    }
  }
  self.streamplot_intents.clear()
  for slot, intent in next {
    self.streamplot_intents[slot] = intent
  }
}
