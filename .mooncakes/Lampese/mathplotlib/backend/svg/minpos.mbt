///|
/// Smallest positive local artist coordinate, independent of the displayed scales.
pub fn artist_minpos(
  artists : Array[@render.Artist],
  horizontal : Bool,
) -> Double {
  let mut data = artists_data_scale(
    artists,
    if horizontal {
      @ticker_scale.Log
    } else {
      @ticker_scale.Linear
    },
    if horizontal {
      @ticker_scale.Linear
    } else {
      @ticker_scale.Log
    },
  )
  // The existing collector stores box centers. Include the actual fixed box
  // and cap endpoints used by append_boxplot for minimum-positive metadata.
  for artist in artists {
    match artist {
      @render.Artist::BoxPlot(stats, sideways, _) =>
        for index, stat in stats {
          let position = Double::from_int(index + 1)
          for
            (value, half_width) in [
              (stat.q1(), 0.3),
              (stat.q3(), 0.3),
              (stat.median(), 0.3),
              (stat.lower_whisker(), 0.1),
              (stat.upper_whisker(), 0.1),
            ] {
            for edge in [position - half_width, position + half_width] {
              data = include_point(
                data,
                if sideways {
                  @core.point(value, edge)
                } else {
                  @core.point(edge, value)
                },
              )
            }
          }
        }
      _ => ()
    }
  }
  if horizontal {
    data.xmin
  } else {
    data.ymin
  }
}
