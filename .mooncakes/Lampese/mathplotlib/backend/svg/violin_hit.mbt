///|
priv struct RenderedViolinGroup {
  index : Int32
  base_index : Int32
  stat : @render.ViolinStats
  position : Double
  horizontal : Bool
}

///|
priv struct RenderedViolinBody {
  group : RenderedViolinGroup
  upper : Array[@core.Point]
  lower : Array[@core.Point]
  fill_visible : Bool
  stroke_visible : Bool
}

///|
priv struct RenderedViolinLine {
  group : RenderedViolinGroup
  part : @drawing.ViolinPart
  value : Double
  slot : Int32
  segment : (Double, Double, Double, Double)
}

///|
fn violin_line_callback(
  collect : ((RenderedViolinLine) -> Unit)?,
  group : RenderedViolinGroup,
  part : @drawing.ViolinPart,
  value : Double,
  slot : Int32,
  style : @core.Style,
) -> (((Double, Double, Double, Double)) -> Unit)? {
  if !statistics_stroke_visible(style) {
    return None
  }
  collect.map(collect => {
    segment => collect({ group, part, value, slot, segment, })
  })
}

///|
fn append_drawing_violin_target(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  group : RenderedViolinGroup,
  part : @drawing.ViolinPart,
  value : Double,
  slot : Int32,
  shape : @drawing.HitShape,
  anchor : (Double, Double),
  metadata : @render.HitMetadata,
  bounds : (Double, Double, Double, Double),
) -> Unit {
  let stat = group.stat
  for
    coordinate in [
      stat.mean(),
      stat.median(),
      stat.min(),
      stat.max(),
      group.position,
      value,
      anchor.0,
      anchor.1,
    ] {
    if !violin_screen_finite(coordinate) {
      return
    }
  }
  if stat.min() > stat.max() {
    return
  }
  let point = @drawing.hit_point(
    panel_index,
    artist_index,
    group.base_index + slot,
    if group.horizontal {
      value
    } else {
      group.position
    },
    if group.horizontal {
      group.position
    } else {
      value
    },
    anchor.0,
    anchor.1,
  )
  let info = @drawing.hit_info(
    point,
    Violin,
    value~,
    series=metadata.series(),
    violin=Some(
      @drawing.violin_info(
        group.index,
        position=group.position,
        horizontal=group.horizontal,
        mean=stat.mean(),
        median=stat.median(),
        minimum=stat.min(),
        maximum=stat.max(),
        part~,
      ),
    ),
  )
  output.points.push(point)
  output.targets.push(@drawing.hit_target(info, shape, bounds))
}

///|
fn collect_drawing_violin_line(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  line : RenderedViolinLine,
  metadata : @render.HitMetadata,
  bounds : (Double, Double, Double, Double),
) -> Unit {
  guard violin_visible_segment(line.segment, bounds) is Some((x0, y0, x1, y1)) else {
    return
  }
  if x0 == x1 && y0 == y1 {
    return
  }
  append_drawing_violin_target(
    output,
    panel_index,
    artist_index,
    line.group,
    line.part,
    line.value,
    line.slot,
    Segment(x0, y0, x1, y1),
    (x0 / 2.0 + x1 / 2.0, y0 / 2.0 + y1 / 2.0),
    metadata,
    bounds,
  )
}

///|
fn collect_drawing_violin_body(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  body : RenderedViolinBody,
  scale : Scale,
  bounds : (Double, Double, Double, Double),
  metadata : @render.HitMetadata,
) -> Unit {
  let group = body.group
  let coords = group.stat.coords()
  let densities = group.stat.vals()
  let (left, top, width, height) = bounds
  let upper = body.upper.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let lower = body.lower.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let count = upper.length()
  let primary = (p : (Double, Double)) => {
    if group.horizontal {
      p.0
    } else {
      p.1
    }
  }
  let direction = primary(upper[1]) - primary(upper[0])
  if direction == 0.0 || !violin_screen_finite(direction) {
    return
  }
  for index in 0..<count {
    for
      value in [
        upper[index].0,
        upper[index].1,
        lower[index].0,
        lower[index].1,
        coords[index],
        densities[index],
      ] {
      if !violin_screen_finite(value) {
        return
      }
    }
    if densities[index] < 0.0 || primary(upper[index]) != primary(lower[index]) {
      return
    }
    if index > 0 {
      let delta = primary(upper[index]) - primary(upper[index - 1])
      if delta == 0.0 ||
        !violin_screen_finite(delta) ||
        (delta > 0.0) != (direction > 0.0) {
        return
      }
    }
  }
  // Keep all filled pieces before any outlines, matching polygon fill/stroke.
  if body.fill_visible {
    for index in 0..<(count - 1) {
      let middle_up = band_midpoint(upper[index], upper[index + 1])
      let middle_low = band_midpoint(lower[index], lower[index + 1])
      for
        (sample, a, b, c, d) in [
          (index, upper[index], middle_up, middle_low, lower[index]),
          (index + 1, middle_up, upper[index + 1], lower[index + 1], middle_low),
        ] {
        guard violin_visible_quad_anchor([a, b, c, d], bounds) is Some(anchor) else {
          continue
        }
        append_drawing_violin_target(
          output,
          panel_index,
          artist_index,
          group,
          Body(sample, coords[sample], densities[sample]),
          coords[sample],
          sample,
          Quadrilateral(a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1),
          anchor,
          metadata,
          bounds,
        )
      }
    }
  }
  if body.stroke_visible {
    for index in 0..<(count - 1) {
      for edge in [upper, lower] {
        let middle = band_midpoint(edge[index], edge[index + 1])
        for
          (sample, a, b) in [
            (index, edge[index], middle),
            (index + 1, middle, edge[index + 1]),
          ] {
          collect_drawing_violin_line(
            output,
            panel_index,
            artist_index,
            {
              group,
              part: Body(sample, coords[sample], densities[sample]),
              value: coords[sample],
              slot: sample,
              segment: (a.0, a.1, b.0, b.1),
            },
            metadata,
            bounds,
          )
        }
      }
    }
    for index in [0, count - 1] {
      let a = upper[index]
      let b = lower[index]
      collect_drawing_violin_line(
        output,
        panel_index,
        artist_index,
        {
          group,
          part: Body(index, coords[index], densities[index]),
          value: coords[index],
          slot: index,
          segment: (a.0, a.1, b.0, b.1),
        },
        metadata,
        bounds,
      )
    }
  }
}
