///|
fn include_point(scale : Scale, p : @core.Point) -> Scale {
  if p.is_missing() ||
    !scale.x_axis_scale.is_valid(p.x()) ||
    !scale.y_axis_scale.is_valid(p.y()) {
    scale
  } else {
    {
      xmin: Double::min(scale.xmin, p.x()),
      xmax: Double::max(scale.xmax, p.x()),
      ymin: Double::min(scale.ymin, p.y()),
      ymax: Double::max(scale.ymax, p.y()),
      x_axis_scale: scale.x_axis_scale,
      y_axis_scale: scale.y_axis_scale,
    }
  }
}

///|
// Blended reference artists contribute only their data-coordinate dimension.
fn include_data_coordinate(
  scale : Scale,
  value : Double,
  horizontal : Bool,
) -> Scale {
  let axis_scale = if horizontal {
    scale.x_axis_scale
  } else {
    scale.y_axis_scale
  }
  if !axis_scale.is_valid(value) {
    return scale
  }
  if horizontal {
    {
      ..scale,
      xmin: Double::min(scale.xmin, value),
      xmax: Double::max(scale.xmax, value),
    }
  } else {
    {
      ..scale,
      ymin: Double::min(scale.ymin, value),
      ymax: Double::max(scale.ymax, value),
    }
  }
}

///|
fn include_artist(scale : Scale, artist : @render.Artist) -> Scale {
  match artist {
    @render.Artist::Line(points, _) =>
      points.fold(init=scale, (current, p) => include_point(current, p))
    @render.Artist::Scatter(points, _) =>
      points.fold(init=scale, (current, p) => include_point(current, p))
    @render.Artist::PathCollection(points, _) =>
      points.fold(init=scale, (current, p) => include_point(current, p))
    @render.Artist::Bar(points, _) => {
      let points = bar_geometry_points(points)
      let mut result = scale
      for index, p in points {
        result = include_point(result, p)
        result = include_point(result, @core.point(p.x(), 0.0))
        let half = bar_data_half_span(points, index, false)
        for edge in [p.x() - half, p.x() + half] {
          result = include_point(result, @core.point(edge, p.y()))
          result = include_point(result, @core.point(edge, 0.0))
        }
      }
      result
    }
    @render.Artist::BarH(points, _) => {
      let points = bar_geometry_points(points)
      let mut result = scale
      for index, p in points {
        result = include_point(result, p)
        result = include_point(result, @core.point(0.0, p.y()))
        let half = bar_data_half_span(points, index, true)
        for edge in [p.y() - half, p.y() + half] {
          result = include_point(result, @core.point(p.x(), edge))
          result = include_point(result, @core.point(0.0, edge))
        }
      }
      result
    }
    @render.Artist::BarSegments(segments, horizontal, _) => {
      let mut result = scale
      for segment in segments {
        if bar_segment_extent(segment, horizontal) is Some(extent) {
          result = include_image_extent(result, extent)
        }
      }
      result
    }
    @render.Artist::FillBetween(upper, lower, _) => {
      let upper_scale = upper.fold(init=scale, (current, p) => {
        include_point(current, p)
      })
      lower.fold(init=upper_scale, (current, p) => include_point(current, p))
    }
    @render.Artist::Polygon(points, _) =>
      points.fold(init=scale, (current, p) => include_point(current, p))
    @render.Artist::CompoundPolygon(polygons, _) => {
      let mut result = scale
      for polygon in polygons {
        result = polygon.fold(init=result, (current, p) => {
          include_point(current, p)
        })
      }
      result
    }
    @render.Artist::GouraudTriangle(points, _) =>
      points.fold(init=scale, (current, p) => include_point(current, p))
    @render.Artist::HLine(value, _) =>
      include_data_coordinate(scale, value, false)
    @render.Artist::VLine(value, _) =>
      include_data_coordinate(scale, value, true)
    @render.Artist::AxLine(point, _, _) => include_point(scale, point)
    @render.Artist::HSpan(lower, upper, _) =>
      include_data_coordinate(
        include_data_coordinate(scale, lower, false),
        upper,
        false,
      )
    @render.Artist::VSpan(lower, upper, _) =>
      include_data_coordinate(
        include_data_coordinate(scale, lower, true),
        upper,
        true,
      )
    @render.Artist::Text(_, _, _, _) => scale
    @render.Artist::Annotation(_) => scale
    @render.Artist::ErrorBar(points, yerr, xerr, _) => {
      let mut result = scale
      for i in 0..<points.length() {
        let p = points[i]
        if p.is_finite() {
          result = include_point(result, p)
          let y_error = if yerr.length() == 0 { 0.0 } else { yerr[i] }
          let x_error = if xerr.length() == 0 { 0.0 } else { xerr[i] }
          result = include_point(result, @core.point(p.x(), p.y() - y_error))
          result = include_point(result, @core.point(p.x(), p.y() + y_error))
          result = include_point(result, @core.point(p.x() - x_error, p.y()))
          result = include_point(result, @core.point(p.x() + x_error, p.y()))
        }
      }
      result
    }
    @render.Artist::Image(_, _, _, _)
    | @render.Artist::ImageNorm(_, _, _, _, _, _, _)
    | @render.Artist::ColorImage(_, _, _, _, _) =>
      match artist_image_extent(artist) {
        Some(bounds) => include_image_extent(scale, bounds)
        None => scale
      }
    @render.Artist::Table(_) => scale
    @render.Artist::Pie(_, _, _, _) | @render.Artist::Donut(_, _, _, _, _) =>
      scale
    @render.Artist::BoxPlot(stats, horizontal, _) => {
      let mut result = scale
      for index, stat in stats {
        let position = Double::from_int(index + 1)
        if horizontal {
          result = include_point(
            result,
            @core.point(stat.lower_whisker(), position),
          )
          result = include_point(
            result,
            @core.point(stat.upper_whisker(), position),
          )
          for coordinate in [stat.q1(), stat.q3(), stat.median()] {
            result = include_point(
              result,
              @core.point(coordinate, position - 0.3),
            )
            result = include_point(
              result,
              @core.point(coordinate, position + 0.3),
            )
          }
          for flier in stat.fliers() {
            result = include_point(result, @core.point(flier, position))
          }
        } else {
          result = include_point(
            result,
            @core.point(position, stat.lower_whisker()),
          )
          result = include_point(
            result,
            @core.point(position, stat.upper_whisker()),
          )
          for coordinate in [stat.q1(), stat.q3(), stat.median()] {
            result = include_point(
              result,
              @core.point(position - 0.3, coordinate),
            )
            result = include_point(
              result,
              @core.point(position + 0.3, coordinate),
            )
          }
          for flier in stat.fliers() {
            result = include_point(result, @core.point(position, flier))
          }
        }
      }
      result
    }
    @render.Artist::Quiver(points, vectors, _) => {
      let mut result = scale
      let count = Int32::min(points.length(), vectors.length())
      for index in 0..<count {
        let point = points[index]
        let vector = vectors[index]
        result = include_point(result, point)
        result = include_point(
          result,
          @core.point(point.x() + vector.x(), point.y() + vector.y()),
        )
      }
      result
    }
    @render.Artist::Violin(
      stats,
      positions,
      widths,
      horizontal,
      _,
      _,
      _,
      _,
      _,
      _,
      _
    ) => {
      let mut result = scale
      let count = Int32::min(
        stats.length(),
        Int32::min(positions.length(), widths.length()),
      )
      for index in 0..<count {
        let stat = stats[index]
        let position = positions[index]
        let half_width = widths[index] / 2.0
        let coords = stat.coords()
        for coordinate in coords {
          if horizontal {
            result = include_point(
              result,
              @core.point(coordinate, position - half_width),
            )
            result = include_point(
              result,
              @core.point(coordinate, position + half_width),
            )
          } else {
            result = include_point(
              result,
              @core.point(position - half_width, coordinate),
            )
            result = include_point(
              result,
              @core.point(position + half_width, coordinate),
            )
          }
        }
      }
      result
    }
  }
}

///|
fn artist_data_scale(panel : @render.Panel) -> Scale {
  artists_data_scale(
    panel.artists(),
    panel.x_axis().scale(),
    panel.y_axis().scale(),
  )
}

///|
fn artists_data_scale(
  artists : Array[@render.Artist],
  x_axis_scale : @ticker_scale.Scale,
  y_axis_scale : @ticker_scale.Scale,
) -> Scale {
  let initial : Scale = {
    xmin: 1.0 / 0.0,
    xmax: -1.0 / 0.0,
    ymin: 1.0 / 0.0,
    ymax: -1.0 / 0.0,
    x_axis_scale,
    y_axis_scale,
  }
  artists.fold(init=initial, (current, artist) => {
    include_artist(current, artist)
  })
}

///|
/// Local finite artist data bounds, independent of scale validity and view limits.
pub fn artist_data_interval(
  artists : Array[@render.Artist],
  horizontal : Bool,
) -> @core.Limits {
  let data = artists_data_scale(
    artists,
    @ticker_scale.Linear,
    @ticker_scale.Linear,
  )
  if horizontal {
    @core.limits(data.xmin, data.xmax)
  } else {
    @core.limits(data.ymin, data.ymax)
  }
}

///|
fn same_group(
  target : Int32?,
  candidate : Int32?,
  target_index : Int32,
  candidate_index : Int32,
) -> Bool {
  match target {
    Some(group) =>
      match candidate {
        Some(other) => group == other
        None => false
      }
    None => target_index == candidate_index
  }
}

///|
// Renderer data providers are lower-priority fallbacks. Scene's cached data and
// explicitly bound providers, including failures, remain authoritative.
fn bind_render_data_minima(figure : @render.Figure) -> Unit {
  for index, panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    for horizontal in [true, false] {
      let axis = if horizontal { panel.x_axis() } else { panel.y_axis() }
      axis.bind_render_autoscale_minpos(() => {
        let target_group = if horizontal {
          panel.share_x_group()
        } else {
          panel.share_y_group()
        }
        let values : Array[Double] = []
        for other_index, other in figure.panels() {
          if other.polar() is Some(_) {
            continue
          }
          let group = if horizontal {
            other.share_x_group()
          } else {
            other.share_y_group()
          }
          if same_group(target_group, group, index, other_index) {
            // autoscale_view reads raw dataLim minima, independently from
            // Axis.get_minpos used by locator NS and the final _set_lim.
            values.push(artist_minpos(other.artists(), horizontal))
          }
        }
        values
      })
      axis.bind_render_minpos(
        () => {
          let minimum = artist_minpos(panel.artists(), horizontal)
          // Match Scene's default policy for bounded probability areas. An
          // explicitly bound owning-axis provider still takes precedence.
          if axis.scale().is_logit() && minimum >= 1.0 && !minimum.is_inf() {
            1.0e-7
          } else {
            minimum
          }
        },
        () => {
          let target_group = if horizontal {
            panel.share_x_group()
          } else {
            panel.share_y_group()
          }
          let values : Array[Double] = []
          for other_index, other in figure.panels() {
            if other.polar() is Some(_) {
              continue
            }
            let group = if horizontal {
              other.share_x_group()
            } else {
              other.share_y_group()
            }
            if same_group(target_group, group, index, other_index) {
              let peer = if horizontal {
                other.x_axis()
              } else {
                other.y_axis()
              }
              values.push(peer.get_minpos())
            }
          }
          values
        },
      )
    }
  }
}

///|
fn ir_group_axes(
  figure : @render.Figure,
  target_index : Int32,
  horizontal : Bool,
) -> Array[@axis.Axis] {
  let target = figure.panels()[target_index]
  let target_group = if horizontal {
    target.share_x_group()
  } else {
    target.share_y_group()
  }
  let result : Array[@axis.Axis] = []
  for index, panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    let group = if horizontal {
      panel.share_x_group()
    } else {
      panel.share_y_group()
    }
    if same_group(target_group, group, target_index, index) {
      result.push(if horizontal { panel.x_axis() } else { panel.y_axis() })
    }
  }
  result
}

///|
fn ir_group_data_endpoints(
  figure : @render.Figure,
  target_index : Int32,
  horizontal : Bool,
) -> Array[Double] {
  let target = figure.panels()[target_index]
  let target_group = if horizontal {
    target.share_x_group()
  } else {
    target.share_y_group()
  }
  let result : Array[Double] = []
  for index, panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    let group = if horizontal {
      panel.share_x_group()
    } else {
      panel.share_y_group()
    }
    if same_group(target_group, group, target_index, index) {
      // Raw artist data never incorporates explicit_bounds or stored views.
      let data = artist_data_interval(panel.artists(), horizontal)
      result.push(data.lower())
      result.push(data.upper())
    }
  }
  result
}

///|
fn installed_axis_view(
  figure : @render.Figure,
  target_index : Int32,
  horizontal : Bool,
) -> @core.Limits raise @core.DataError {
  let target = figure.panels()[target_index]
  let axis = if horizontal { target.x_axis() } else { target.y_axis() }
  if !axis.has_autoscale_view_provider() && axis.limits() is None {
    if target.explicit_bounds() is Some(bounds) {
      // The standalone IR override is a viewport, never raw artist data.
      axis.set_limits(
        if horizontal {
          bounds.xmin()
        } else {
          bounds.ymin()
        },
        if horizontal {
          bounds.xmax()
        } else {
          bounds.ymax()
        },
      )
    }
  }
  axis.resolve_autoscale_view()
  if axis.has_autoscale_view_provider() {
    // The owning Scene resolver includes retained detached shared members.
    // Its own stored Bbox is not a projection of the first IR group limit.
    return axis.stored_view_limits()
  }
  let peers = ir_group_axes(figure, target_index, horizontal)
  let pending = peers.any(peer => peer.autoscale_stale()) ||
    axis.current_view_limits() is None
  if pending {
    // Match _unstale_viewLim: requests are consumed before the checked work.
    for peer in peers {
      peer.clear_autoscale_request()
    }
    if axis.autoscale_on() {
      let data = ir_group_data_endpoints(figure, target_index, horizontal)
      let margin = if horizontal {
        target.x_margin()
      } else {
        target.y_margin()
      }
      let candidate = axis.autoscale_bounds_checked(
        data,
        margin~,
        stickies=grouped_artist_sticky_edges(figure, target_index, horizontal),
        tight=false,
      )
      if candidate is Some(bounds) {
        // Source set_bound reads old bounds even when both new ones exist,
        // then reads the view again to preserve its current direction.
        ignore(axis.lifecycle_view_interval_checked())
        let (first, last) = axis.lifecycle_view_interval_checked()
        let (low, high) = if bounds.upper() < bounds.lower() {
          (bounds.upper(), bounds.lower())
        } else {
          (bounds.lower(), bounds.upper())
        }
        let (lower, upper) = if first > last {
          (high, low)
        } else {
          (low, high)
        }
        let view = axis.set_bound_limits_checked(lower, upper)
        for peer in peers {
          if !physical_equal(peer, axis) {
            ignore(peer.set_bound_limits_checked(view.lower(), view.upper()))
          }
        }
      }
    }
  }
  axis.stored_view_limits()
}

///|
fn compute_scale(
  figure : @render.Figure,
  target_index : Int32,
) -> Scale raise @core.DataError {
  let target = figure.panels()[target_index]
  bind_render_data_minima(figure)
  let x_axis = target.x_axis()
  let y_axis = target.y_axis()
  let x_view = installed_axis_view(figure, target_index, true)
  let y_view = installed_axis_view(figure, target_index, false)
  {
    xmin: x_view.lower(),
    xmax: x_view.upper(),
    ymin: y_view.lower(),
    ymax: y_view.upper(),
    x_axis_scale: x_axis.scale(),
    y_axis_scale: y_axis.scale(),
  }
}

///|
fn compute_scales(
  figure : @render.Figure,
) -> Array[Scale] raise @core.DataError {
  let result = Array(capacity=figure.panels().length())
  for index in 0..<figure.panels().length() {
    result.push(resolve_panel_scale(figure, index))
  }
  result
}
