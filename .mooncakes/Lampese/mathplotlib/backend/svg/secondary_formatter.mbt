///|
priv struct SecondaryTickBundle {
  major : Array[(Double, Double)]
  major_labels : Array[String]
  minor : Array[(Double, Double)]
  minor_labels : Array[String]
  offset : String
  // Some: coordinates already use the owned child's installed transform.
  // None: preserve the explicit ownerless primary-coordinate transport.
  placement : (Double, Double)?
  drawing : @render.SecondaryDrawingContext?
}

///|
fn secondary_raw_major_locations(
  axis : @render.SecondaryAxis,
  primary_ticks : Array[Double],
  lower : Double,
  upper : Double,
) -> @ticker.FormatterLocations raise @core.DataError {
  if axis.tick_group_is_null() {
    return @ticker.FormatterLocations::NdArray(
      @ticker.TickValues::from_array([]),
    )
  }
  if axis.formatter_tick_locations() is Some(locations) {
    return locations
  }
  if axis.fixed_ticks() is Some(values) {
    return @ticker.FormatterLocations::NdArray(
      @ticker.TickValues::from_array(values),
    )
  }
  let view = match axis.locator() {
    Some(@ticker.Locator::Fixed(values)) =>
      @ticker.TickValues::from_array(values)
    Some(@ticker.Locator::NamedFixed(value)) => value.tick_values(0.0, 0.0)
    Some(@ticker.Locator::Multiple(value)) =>
      @ticker.TickValues::from_array(
        value.tick_values(axis.forward()(lower), axis.forward()(upper)),
      )
    Some(locator) =>
      locator.tick_view_for_axis(axis.forward()(lower), axis.forward()(upper))
    None =>
      @ticker.TickValues::from_array(
        secondary_primary_ticks(primary_ticks, axis.tick_count()).map(
          axis.forward(),
        ),
      )
  }
  @ticker.FormatterLocations::NdArray(view)
}

///|
fn secondary_axis_bundle(
  axis : @render.SecondaryAxis,
  primary_ticks : Array[Double],
  lower : Double,
  upper : Double,
) -> SecondaryTickBundle raise @core.DataError {
  let (values, major_labels, legacy_major) = if !axis.has_placement_provider() &&
    axis.named_formatter() is None &&
    axis.minor_named_formatter() is None {
    let major = secondary_axis_ticks(axis, primary_ticks, lower, upper)
    let labels = secondary_axis_tick_labels(
      axis,
      major.map(tick => tick.1),
      lower,
      upper,
    )
    (major.map(tick => tick.1), labels, Some(major))
  } else {
    let locations = secondary_raw_major_locations(
      axis, primary_ticks, lower, upper,
    )
    let labels = if axis.tick_group_is_null() {
      []
    } else {
      match axis.named_formatter() {
        Some(formatter) => format_retained_locations(formatter, locations)
        None =>
          secondary_axis_tick_labels(
            axis,
            materialize_formatter_locations(locations),
            lower,
            upper,
          )
      }
    }
    (materialize_formatter_locations(locations), labels, None)
  }
  let minor_null = axis.tick_group_is_null(minor=true)
  let minor_locations = if minor_null {
    @ticker.FormatterLocations::Sequence([])
  } else {
    match axis.formatter_tick_locations(minor=true) {
      Some(locations) => locations
      None =>
        @ticker.FormatterLocations::NdArray(
          @ticker.TickValues::from_array(axis.minor_tick_values()),
        )
    }
  }
  let minor_labels = if minor_null {
    []
  } else {
    match axis.minor_named_formatter() {
      Some(formatter) => format_retained_locations(formatter, minor_locations)
      None => Array::make(minor_locations.length(), "")
    }
  }
  // Capture the installed child transform only after both full batches.
  // This is the source view/visibility transform stage, before late offset text.
  let (major, minor, placement) = match axis.placement() {
    Some(context) => {
      let transform = context.transform()
      let reversed = context.lower() > context.upper()
      let (lower, upper) = if reversed {
        (context.upper(), context.lower())
      } else {
        (context.lower(), context.upper())
      }
      let first = transform(lower)
      let last = transform(upper)
      // TransformedBbox sorts transformed corners, then restores the raw
      // Bbox inversion. A decreasing function does not itself invert the axis.
      let (low, high) = if first.is_nan() || last.is_nan() {
        (0.0 / 0.0, 0.0 / 0.0)
      } else if first > last {
        (last, first)
      } else {
        (first, last)
      }
      let bounds = if reversed { (high, low) } else { (low, high) }
      let major = values.map(value => (transform(value), value))
      let minor = materialize_formatter_locations(minor_locations).map(value => {
        (transform(value), value)
      })
      (major, minor, Some(bounds))
    }
    None => {
      // Standalone IR keeps its established explicit numeric transport.
      if axis.formatter_view_interval() is Some((first, last)) {
        ignore(axis.inverse()(first))
        ignore(axis.inverse()(last))
      }
      let major = match legacy_major {
        Some(major) => major
        None => values.map(value => (axis.inverse()(value), value))
      }
      let minor = materialize_formatter_locations(minor_locations).map(value => {
        (axis.inverse()(value), value)
      })
      (major, minor, None)
    }
  }
  let offset = match axis.named_formatter() {
    Some(formatter) => formatter.get_offset_checked()
    None => ""
  }
  let drawing = axis.drawing_context()
  { major, major_labels, minor, minor_labels, offset, placement, drawing, }
}

///|
// Owned positions are transformed exactly once while preparing their bundle.
// Ownerless IR retains the previous scale mapping and finite-value policy.
fn secondary_tick_fraction(
  bundle : SecondaryTickBundle,
  position : Double,
  value : Double,
  scale : @ticker_scale.Scale,
  lower : Double,
  upper : Double,
) -> Double? {
  match bundle.placement {
    Some((first, last)) => {
      let (low, high) = if first > last { (last, first) } else { (first, last) }
      let tolerance = (high - low) * 1.0e-10
      if !(low - tolerance <= position && position <= high + tolerance) {
        return None
      }
      let fraction = (position - first) / (last - first)
      if fraction.is_nan() || fraction.is_inf() {
        None
      } else {
        Some(fraction)
      }
    }
    None => {
      if !tick_in_view(position, scale, lower, upper) ||
        position.is_nan() ||
        position.is_inf() ||
        value.is_nan() ||
        value.is_inf() {
        return None
      }
      let first = scale.transform(lower)
      let last = scale.transform(upper)
      Some(
        if first == last {
          0.5
        } else {
          (scale.transform(position) - first) / (last - first)
        },
      )
    }
  }
}

///|
// With no owner metadata, retain the established x-then-y transport order.
// A sequence tiebreaker makes mixed owned/ownerless inputs a total order.
fn ordered_secondary_axes(
  panel : @render.Panel,
) -> Array[(Bool, Int32, @render.SecondaryAxis, Int64)] {
  let result : Array[(Bool, Int32, @render.SecondaryAxis, Int64)] = []
  let horizontal = panel.secondary_x()
  for index, axis in horizontal {
    result.push((true, index, axis, index.to_int64()))
  }
  for index, axis in panel.secondary_y() {
    result.push(
      (false, index, axis, horizontal.length().to_int64() + index.to_int64()),
    )
  }
  result.sort_by((first, second) => {
    let first_key = first.2
      .draw_order()
      .map(order => order.to_int64())
      .unwrap_or(first.3)
    let second_key = second.2
      .draw_order()
      .map(order => order.to_int64())
      .unwrap_or(second.3)
    if first_key < second_key {
      -1
    } else if first_key > second_key {
      1
    } else {
      first.3.compare(second.3)
    }
  })
  result
}
