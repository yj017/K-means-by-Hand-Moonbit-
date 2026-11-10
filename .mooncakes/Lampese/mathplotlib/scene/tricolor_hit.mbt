///|
priv struct TripcolorSource {
  data : @render.TripcolorHitData
  cursor : @ref.Ref[Int32]
}

///|
priv struct TripcolorIntent {
  artist : Artist
  source : TripcolorSource
}

///|
fn Axes::push_tripcolor_face(
  self : Axes,
  points : Array[@core.Point],
  style : @core.Style,
  slot : Int32,
  value : Double,
  vertices : (Int32, Int32, Int32),
  vertex_mean : Bool,
  series : String,
) -> Unit {
  let artist = Artist::Polygon(points, style)
  let data = @render.tripcolor_hit_data(
    points, slot, value, vertices, vertex_mean, series,
  )
  let source : TripcolorSource = { data, cursor: @ref.Ref(0), }
  self.push_artist(artist)
  let records = self.state.val.artist_hits
  let record = records[records.length() - 1]
  record.tricolor = Some(source)
  record.series = series
  self.state.val.tricolor_intents[self.state.val.artists.length() - 1] = {
    artist,
    source,
  }
}

///|
fn AxesData::remove_tricolor_slot(self : AxesData, removed : Int32) -> Unit {
  if self.tricolor_intents.is_empty() {
    return
  }
  let next = Map([])
  for slot, intent in self.tricolor_intents {
    if slot != removed {
      next[if slot > removed { slot - 1 } else { slot }] = intent
    }
  }
  self.tricolor_intents.clear()
  for slot, intent in next {
    self.tricolor_intents[slot] = intent
  }
}
