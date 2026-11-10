///|
priv struct ContourSource {
  view : @render.ContourHitView
  // Rebuilt once from the frame's records, so inline fragments advance the
  // existing metadata cursor without scanning old paths or unrelated records.
  cursor : @ref.Ref[Int32]
}

///|
priv struct ContourIntent {
  artist : Artist
  source : ContourSource
  view : @render.ContourHitView
}

///|
fn Axes::push_contour_path(
  self : Axes,
  points : Array[@core.Point],
  style : @core.Style,
  slot : Int32,
  level : Double,
  series : String,
) -> Unit {
  let view = @render.contour_hit_view(points, slot, level, series)
  let source : ContourSource = { view, cursor: @ref.Ref(0), }
  let artist = Artist::Line(points, style)
  self.push_artist(artist)
  let records = self.state.val.artist_hits
  let record = records[records.length() - 1]
  record.contour = Some(source)
  record.series = series
  self.state.val.contour_intents[self.state.val.artists.length() - 1] = {
    artist,
    source,
    view,
  }
}

///|
fn ContourIntent::split(
  self : ContourIntent,
  original : Artist,
  fragment : Artist,
) -> ContourIntent {
  let valid = same_hit_artist(self.artist, original) &&
    (match original {
      Line(points, _) => self.view.matches_points(points)
      _ => false
    })
  let view = if valid { self.view } else { self.view.invalidated() }
  let view = match fragment {
    Line(points, _) => view.fragment(points)
    _ => view.invalidated()
  }
  { artist: fragment, source: self.source, view, }
}

///|
fn AxesData::remove_contour_slot(self : AxesData, removed : Int32) -> Unit {
  if self.contour_intents.is_empty() {
    return
  }
  let next = Map([])
  for slot, intent in self.contour_intents {
    if slot != removed {
      next[if slot > removed { slot - 1 } else { slot }] = intent
    }
  }
  self.contour_intents.clear()
  for slot, intent in next {
    self.contour_intents[slot] = intent
  }
}
