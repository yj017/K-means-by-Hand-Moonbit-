///|
// Image bounds update each coordinate separately: an invalid endpoint on a
// logarithmic x-axis must not discard valid y endpoints (or vice versa).
fn include_image_extent(
  scale : Scale,
  extent : (Double, Double, Double, Double),
) -> Scale {
  let (left, right, bottom, top) = extent
  let mut result = scale
  for value in [left, right] {
    if scale.x_axis_scale.is_valid(value) {
      result = {
        ..result,
        xmin: Double::min(result.xmin, value),
        xmax: Double::max(result.xmax, value),
      }
    }
  }
  for value in [bottom, top] {
    if scale.y_axis_scale.is_valid(value) {
      result = {
        ..result,
        ymin: Double::min(result.ymin, value),
        ymax: Double::max(result.ymax, value),
      }
    }
  }
  result
}

///|
/// Raw sticky metadata recoverable from the current typed artist geometry.
/// Keep values unfiltered; only the source Log autoscale stage drops <=0.
pub fn artist_sticky_edges(
  artists : Array[@render.Artist],
  horizontal : Bool,
) -> Array[Double] {
  let result : Array[Double] = []
  for artist in artists {
    match artist_image_extent(artist) {
      Some((left, right, bottom, top)) => {
        result.push(if horizontal { left } else { bottom })
        result.push(if horizontal { right } else { top })
      }
      None =>
        match artist {
          @render.Artist::Bar(points, _) if !horizontal =>
            for _ in points {
              result.push(0.0)
            }
          @render.Artist::BarH(points, _) if horizontal =>
            for _ in points {
              result.push(0.0)
            }
          @render.Artist::BarSegments(segments, sideways, _) if sideways ==
            horizontal =>
            for segment in segments {
              if bar_segment_extent(segment, sideways) is Some(_) {
                result.push(segment.baseline)
              }
            }
          _ => ()
        }
    }
  }
  result
}

///|
fn grouped_artist_sticky_edges(
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
    let group = if horizontal {
      panel.share_x_group()
    } else {
      panel.share_y_group()
    }
    if same_group(target_group, group, target_index, index) {
      for value in artist_sticky_edges(panel.artists(), horizontal) {
        result.push(value)
      }
    }
  }
  result
}
