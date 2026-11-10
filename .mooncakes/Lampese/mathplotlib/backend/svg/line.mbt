///|
fn append_line_segment(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  line_alpha~ : Double? = None,
  line_dashes~ : (Double, Array[Double])? = None,
  source_start~ : Int32 = 0,
  on_segment~ : ((Array[@core.Point], Int32) -> Unit)? = None,
) -> Unit {
  if points.length() == 0 {
    return
  }
  let attributes = [
    ("fill", "none"),
    ("stroke", style.color()),
    ("stroke-width", float_text(style.width())),
    ("points", points_text(scale, left, top, plot_width, plot_height, points)),
  ]
  if line_alpha is Some(alpha) {
    attributes.push(("stroke-opacity", float_text(alpha)))
  }
  if line_dashes is Some((offset, sequence)) {
    let text = StringBuilder()
    for index, value in sequence {
      if index > 0 {
        text.write_string(",")
      }
      text.write_string(float_text(value))
    }
    attributes.push(("stroke-dasharray", text.to_string()))
    attributes.push(("stroke-dashoffset", float_text(offset)))
  }
  try! writer.empty_element("polyline", attributes)
  if on_segment is Some(capture) {
    capture(points, source_start)
  }
}

///|
fn append_line(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  line_alpha~ : Double? = None,
  line_dashes~ : (Double, Array[Double])? = None,
  on_segment~ : ((Array[@core.Point], Int32) -> Unit)? = None,
) -> Unit {
  let mut segment : Array[@core.Point] = []
  let mut source_start = 0
  for i, p in points {
    if valid_point(scale, p) {
      segment.push(p)
    } else if segment.length() > 0 {
      append_line_segment(
        writer,
        scale,
        left,
        top,
        plot_width,
        plot_height,
        segment,
        style,
        line_alpha~,
        line_dashes~,
        source_start~,
        on_segment~,
      )
      segment = []
      source_start = i + 1
    } else {
      source_start = i + 1
    }
  }
  if segment.length() > 0 {
    append_line_segment(
      writer,
      scale,
      left,
      top,
      plot_width,
      plot_height,
      segment,
      style,
      line_alpha~,
      line_dashes~,
      source_start~,
      on_segment~,
    )
  }
}

///|
// Only true Line artists consume this carrier. Errorbar's center polyline
// keeps append_line's default solid behavior.
fn append_line_artist(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  points : Array[@core.Point],
  style : @core.Style,
  on_segment~ : ((Array[@core.Point], Int32) -> Unit)? = None,
) -> Unit raise @core.DataError {
  let stroke = style.line_stroke()
  if stroke.linestyle() == "None" || points.is_empty() {
    return
  }
  let line_dashes = if style.width() > 0.0 {
    match stroke.dash_sequence() {
      Some(sequence) => {
        // Original GC checks all negative entries before testing positivity.
        // This happens for nonempty paths even when every point is nonfinite.
        for value in sequence {
          if value < 0.0 {
            raise @core.DataError::InvalidTicks(
              message="ValueError: All values in the dash list must be non-negative",
            )
          }
        }
        let mut positive = false
        for value in sequence {
          if value > 0.0 {
            positive = true
          }
        }
        if !sequence.is_empty() && !positive {
          raise @core.DataError::InvalidTicks(
            message="ValueError: At least one value in the dash list must be positive",
          )
        }
        Some((stroke.dash_offset(), sequence))
      }
      None => None
    }
  } else {
    None
  }
  append_line(
    writer,
    scale,
    left,
    top,
    plot_width,
    plot_height,
    points,
    style,
    line_alpha=style.line_alpha(),
    line_dashes~,
    on_segment~,
  )
}

///|
fn append_line_context(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  context : @render.LineDrawingContext,
  on_segment~ : ((Array[@core.Point], Int32) -> Unit)? = None,
) -> Unit raise @core.DataError {
  let current = context.points()
  append_line_artist(
    writer,
    scale,
    left,
    top,
    plot_width,
    plot_height,
    current,
    context.first_style(),
    on_segment~,
  )
  if context.resolve_foreground_style() is Some(foreground) {
    append_line_artist(
      writer, scale, left, top, plot_width, plot_height, current, foreground,
    )
  }
  context.complete()
}
