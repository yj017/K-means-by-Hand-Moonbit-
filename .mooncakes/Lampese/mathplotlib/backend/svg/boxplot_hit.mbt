///|
fn append_drawing_box_target(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  sample : RenderedBoxPlot,
  metadata : @render.HitMetadata,
  bounds : (Double, Double, Double, Double),
  part : @drawing.BoxPart,
  value : Double,
  shape : @drawing.HitShape,
  screen_x : Double,
  screen_y : Double,
) -> Unit {
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    sample.source_index,
    if sample.horizontal {
      value
    } else {
      sample.position
    },
    if sample.horizontal {
      sample.position
    } else {
      value
    },
    screen_x,
    screen_y,
  )
  let stat = sample.stat
  let info = @drawing.hit_info(
    point,
    BoxPlot,
    value~,
    series=metadata.series(),
    box=Some(
      @drawing.box_info(
        sample.source_index,
        q1=stat.q1(),
        median=stat.median(),
        q3=stat.q3(),
        lower_whisker=stat.lower_whisker(),
        upper_whisker=stat.upper_whisker(),
        part~,
      ),
    ),
  )
  output.points.push(point)
  output.targets.push(@drawing.hit_target(info, shape, bounds))
}

///|
fn collect_drawing_boxplot(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  sample : RenderedBoxPlot,
  metadata : @render.HitMetadata,
  bounds : (Double, Double, Double, Double),
) -> Unit {
  let stat = sample.stat
  for
    coordinate in [
      stat.lower_whisker(),
      stat.q1(),
      stat.median(),
      stat.q3(),
      stat.upper_whisker(),
    ] {
    if coordinate.is_nan() || coordinate.is_inf() {
      return
    }
  }
  let (left, top, width, height) = bounds
  let (x, y, box_width, box_height) = sample.rectangle
  let x0 = Double::max(x, left)
  let x1 = Double::min(x + box_width, left + width)
  let y0 = Double::max(y, top)
  let y1 = Double::min(y + box_height, top + height)
  if sample.fill_visible &&
    !x.is_nan() &&
    !x.is_inf() &&
    !y.is_nan() &&
    !y.is_inf() &&
    !box_width.is_nan() &&
    !box_width.is_inf() &&
    !box_height.is_nan() &&
    !box_height.is_inf() &&
    box_width > 0.0 &&
    box_height > 0.0 &&
    !x0.is_nan() &&
    !x1.is_nan() &&
    !y0.is_nan() &&
    !y1.is_nan() &&
    !x0.is_inf() &&
    !x1.is_inf() &&
    !y0.is_inf() &&
    !y1.is_inf() &&
    x0 < x1 &&
    y0 < y1 {
    append_drawing_box_target(
      output,
      panel_index,
      artist_index,
      sample,
      metadata,
      bounds,
      Box,
      stat.median(),
      Rectangle(x, y, box_width, box_height),
      (x0 + x1) / 2.0,
      (y0 + y1) / 2.0,
    )
  }
  if sample.stroke_visible {
    // An unfilled box has only its original outline, not an interactive interior
    // or edges invented at the viewport's clipping boundary.
    if !sample.fill_visible && box_width > 0.0 && box_height > 0.0 {
      for
        segment in [
          (x, y, x + box_width, y),
          (x + box_width, y, x + box_width, y + box_height),
          (x + box_width, y + box_height, x, y + box_height),
          (x, y + box_height, x, y),
        ] {
        guard visible_error_segment(segment, bounds)
          is Some((sx0, sy0, sx1, sy1)) else {
          continue
        }
        if sx0 == sx1 && sy0 == sy1 {
          continue
        }
        append_drawing_box_target(
          output,
          panel_index,
          artist_index,
          sample,
          metadata,
          bounds,
          Box,
          stat.median(),
          Segment(sx0, sy0, sx1, sy1),
          (sx0 + sx1) / 2.0,
          (sy0 + sy1) / 2.0,
        )
      }
    }
    // These are the five actually emitted lines, in their original paint order.
    // A zero-length whisker has no visible butt-capped stroke; the real median
    // line still makes a constant-valued group interactive.
    let parts : Array[(@drawing.BoxPart, Double)] = [
      (LowerWhisker, stat.lower_whisker()),
      (UpperWhisker, stat.upper_whisker()),
      (Box, stat.median()),
      (LowerCap, stat.lower_whisker()),
      (UpperCap, stat.upper_whisker()),
    ]
    for index, (part, value) in parts {
      let segment = sample.segments[index]
      if segment.0 == segment.2 && segment.1 == segment.3 {
        continue
      }
      guard visible_error_segment(segment, bounds) is Some((sx0, sy0, sx1, sy1)) else {
        continue
      }
      if sx0 == sx1 && sy0 == sy1 {
        continue
      }
      // Different cap anchors remain distinguishable in exact-point metadata
      // lookup when constant groups paint both caps on the same centerline.
      let fraction = match part {
        LowerCap => 0.25
        UpperCap => 0.75
        _ => 0.5
      }
      append_drawing_box_target(
        output,
        panel_index,
        artist_index,
        sample,
        metadata,
        bounds,
        part,
        value,
        Segment(sx0, sy0, sx1, sy1),
        sx0 + (sx1 - sx0) * fraction,
        sy0 + (sy1 - sy0) * fraction,
      )
    }
  }
  for (value, sx, sy) in sample.fliers {
    if !value.is_nan() &&
      !value.is_inf() &&
      !sx.is_nan() &&
      !sx.is_inf() &&
      !sy.is_nan() &&
      !sy.is_inf() &&
      sx >= left &&
      sx <= left + width &&
      sy >= top &&
      sy <= top + height {
      append_drawing_box_target(
        output,
        panel_index,
        artist_index,
        sample,
        metadata,
        bounds,
        Outlier(value),
        value,
        Point,
        sx,
        sy,
      )
    }
  }
}
