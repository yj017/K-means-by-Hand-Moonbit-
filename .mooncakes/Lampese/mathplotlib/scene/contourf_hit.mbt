///|
priv struct ContourFSource {
  data : @render.ContourFHitData
  cursor : @ref.Ref[Int32]
}

///|
priv struct ContourFIntent {
  artist : Artist
  source : ContourFSource
}

///|
fn Axes::push_contourf_band(
  self : Axes,
  rings : Array[Array[@core.Point]],
  style : @core.Style,
  slot : Int32,
  lower : Double,
  upper : Double,
  series : String,
) -> Unit {
  let artist = if rings.length() == 1 {
    Artist::Polygon(rings[0], style)
  } else if rings.length() > 1 {
    Artist::CompoundPolygon(rings, style)
  } else {
    return
  }
  let data = @render.contourf_hit_data(rings, slot, lower, upper, series)
  let source : ContourFSource = { data, cursor: @ref.Ref(0), }
  self.push_artist(artist)
  let records = self.state.val.artist_hits
  let record = records[records.length() - 1]
  record.contourf = Some(source)
  record.series = series
  self.state.val.contourf_intents[self.state.val.artists.length() - 1] = {
    artist,
    source,
  }
}

///|
fn AxesData::remove_contourf_slot(self : AxesData, removed : Int32) -> Unit {
  if self.contourf_intents.is_empty() {
    return
  }
  let next = Map([])
  for slot, intent in self.contourf_intents {
    if slot != removed {
      next[if slot > removed { slot - 1 } else { slot }] = intent
    }
  }
  self.contourf_intents.clear()
  for slot, intent in next {
    self.contourf_intents[slot] = intent
  }
}
