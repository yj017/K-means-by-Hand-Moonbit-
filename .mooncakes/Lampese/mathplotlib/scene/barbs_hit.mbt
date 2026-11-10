///|
priv struct BarbIntent {
  artist : Artist
  view : @render.BarbHitView
}

///|
fn barb_source(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  label : String,
) -> @render.BarbHitData {
  let points = Array(capacity=xs.length())
  let vectors = Array(capacity=xs.length())
  for i, x in xs {
    points.push(@core.point(x, ys[i]))
    vectors.push(@core.point(us[i], vs[i]))
  }
  @render.barb_hit_data(points, vectors, label).unwrap()
}

///|
fn Axes::push_barb_component(
  self : Axes,
  artist : Artist,
  source : @render.BarbHitData,
  index : Int32,
) -> Unit {
  let (component, points) = match artist {
    Line(points, _) => (@render.BarbComponent::Stroke, points)
    Polygon(points, _) => (@render.BarbComponent::Flag, points)
    Scatter(points, _) => (@render.BarbComponent::Calm, points)
    _ => return
  }
  let view = source.view(index, component, points).unwrap()
  self.push_artist(artist)
  let records = self.state.val.artist_hits
  let record = records[records.length() - 1]
  record.barb = Some(view)
  record.series = view.series()
  self.state.val.barb_intents[self.state.val.artists.length() - 1] = {
    artist,
    view,
  }
}

///|
// Normal Line removal shifts known component slots, independently of the
// metadata record cursor (which can omit images and expanded contour lines).
fn AxesData::remove_barb_slot(self : AxesData, removed : Int32) -> Unit {
  if self.barb_intents.is_empty() {
    return
  }
  let next = Map([])
  for slot, intent in self.barb_intents {
    if slot != removed {
      next[if slot > removed { slot - 1 } else { slot }] = intent
    }
  }
  self.barb_intents.clear()
  for slot, intent in next {
    self.barb_intents[slot] = intent
  }
}
