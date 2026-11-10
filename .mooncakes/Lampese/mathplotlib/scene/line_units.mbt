///|
/// Original coordinate kind is independent of the Axis's current converter.
pub(all) enum LineData {
  Numeric(Array[Double])
  Category(Array[String])
  Date(Array[@date.RRuleDateTime])
}

///|
fn LineData::copy(self : LineData) -> LineData {
  match self {
    Numeric(values) => Numeric(values.copy())
    Category(values) => Category(values.copy())
    Date(values) => Date(values.copy())
  }
}

///|
fn LineData::length(self : LineData) -> Int32 {
  match self {
    Numeric(values) => values.length()
    Category(values) => values.length()
    Date(values) => values.length()
  }
}

///|
fn LineData::convert(
  self : LineData,
  axis : @axis.Axis,
) -> Array[Double] raise @core.DataError {
  match self {
    // Python-list Float64 coercion finishes before converting the other axis.
    Numeric(values) => values.copy()
    Category(values) => axis.convert_category_units(values)
    Date(values) => axis.convert_date_units(values)
  }
}

///|
fn LineData::convert_detached(
  self : LineData,
) -> Array[Double] raise @core.DataError {
  match self {
    Numeric(values) => values.copy()
    Category(values) => values.map(value => @ticker.parse_float_text(value))
    Date(values) =>
      if values.is_empty() {
        []
      } else {
        raise @core.DataError::InvalidTicks(
          message="TypeError: float() argument must be a string or a real number, not 'datetime.datetime'",
        )
      }
  }
}

///|
fn Axes::attach_line_handle(
  self : Axes,
  points : Array[@core.Point],
  x_original : LineData,
  y_original : LineData,
  color~ : String = "",
  label~ : String = "",
) -> Line2D raise @core.DataError {
  let attached = copy_points(points)
  let x = x_original.copy()
  let y = y_original.copy()
  let cache = line2d_cache_from_points(attached)
  // Preserve copy/cache failure order before consuming an automatic color.
  let resolved_color = self.resolve_color(color)
  let style = @core.style(resolved_color)
  let line : Line2D = {
    points: attached,
    style,
    unscaled_dash_pattern: { offset: 0.0, dashes: None, },
    scaled_dashes_as_list: true,
    source_color: false,
    x,
    y,
    cache,
    drawstyle: "default",
    path_values: cache.flat,
    invalid_x: false,
    invalid_y: false,
    owner: Some(self),
    removal_parent: Some(self),
    visible: true,
    stale: true,
  }
  self.state.val.line_originals.push(line)
  self.push_artist(Artist::Line(attached, style))
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
  line
}

///|
// Preserve the existing pure Unit convenience signatures. Their supplied point
// buffers must fit the interleaved storage, as with the original allocation.
fn Axes::attach_line_with_originals(
  self : Axes,
  points : Array[@core.Point],
  x_original : LineData,
  y_original : LineData,
  color~ : String = "",
  label~ : String = "",
) -> Unit {
  ignore(
    try! self.attach_line_handle(points, x_original, y_original, color~, label~),
  )
}

///|
/// A forced unit recache visits real attached Lines in artist order.
fn Axes::recache_line_units(self : Axes) -> Unit raise @core.DataError {
  let state = self.state.val
  for artist in state.artists {
    guard artist is Artist::Line(points, _) else { continue }
    for line in state.line_originals {
      if physical_equal(points, line.points) {
        line.recache_checked(always=true)
        break
      }
    }
  }
}

///|
/// Contour rewriting can erase an attachment without destroying retained handles.
fn Axes::prune_line_originals(self : Axes) -> Unit {
  let artists = self.state.val.artists
  self.state.val.line_originals.retain(line => {
    let attached = artists.any(artist => {
      match artist {
        Artist::Line(points, _) => physical_equal(points, line.points)
        _ => false
      }
    })
    if !attached {
      line.detach()
    }
    attached
  })
}
