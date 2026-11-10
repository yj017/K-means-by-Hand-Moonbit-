///|
// Data-container identities detect setter replacements even when equal data
// was supplied. The carrier independently copies values for mutation checks.
priv struct DiscreteLineSource {
  data : @render.DiscreteLineHitData
  line : Line2D?
  x : LineData?
  y : LineData?
}

///|
fn Axes::record_discrete_line(
  self : Axes,
  data : @render.DiscreteLineHitData,
) -> Unit {
  let records = self.state.val.artist_hits
  if records.is_empty() {
    return
  }
  let record = records[records.length() - 1]
  guard record.artist is Artist::Line(points, _) else { return }
  for line in self.state.val.line_originals {
    if physical_equal(line.points, points) {
      record.discrete = Some({
        data,
        line: Some(line),
        x: Some(line.x),
        y: Some(line.y),
      })
      return
    }
  }
  record.discrete = Some({ data, line: None, x: None, y: None, })
}

///|
// A filled stairs polygon shares the same copied path/datum carrier. Its
// validated boundary-edge map is not a second line stroke or a hit bbox.
fn Axes::record_discrete_face(
  self : Axes,
  data : @render.DiscreteLineHitData,
) -> Unit {
  let records = self.state.val.artist_hits
  if records.is_empty() {
    return
  }
  let record = records[records.length() - 1]
  if record.artist is Artist::Polygon(_, _) {
    record.discrete = Some({ data, line: None, x: None, y: None, })
  }
}

///|
fn discrete_same_original(first : LineData, second : LineData?) -> Bool {
  match (first, second) {
    (Numeric(a), Some(Numeric(b))) => physical_equal(a, b)
    _ => false
  }
}

///|
fn DiscreteLineSource::prepare(
  self : DiscreteLineSource,
  line : Line2D,
  path : Array[@core.Point],
  samples : Array[@core.Point]?,
) -> @render.DiscreteLineHitData? {
  guard self.line is Some(original) else { return None }
  if !physical_equal(line, original) ||
    line.drawstyle != "default" ||
    !discrete_same_original(line.x, self.x) ||
    !discrete_same_original(line.y, self.y) ||
    !self.data.matches_path(path) {
    return None
  }
  guard samples is Some(current) else { return None }
  if !self.data.matches_path(current) {
    return None
  }
  match (line.x, line.y) {
    (Numeric(xs), Numeric(ys)) =>
      if self.data.matches_xy(xs, ys) {
        Some(self.data)
      } else {
        None
      }
    _ => None
  }
}

///|
fn prepared_discrete_line(
  sources : Array[DiscreteLineSource],
  line : Line2D,
  path : Array[@core.Point],
  samples : Array[@core.Point]?,
) -> @render.DiscreteLineHitData? {
  for source in sources {
    if source.line is Some(original) && physical_equal(original, line) {
      return source.prepare(line, path, samples)
    }
  }
  None
}
