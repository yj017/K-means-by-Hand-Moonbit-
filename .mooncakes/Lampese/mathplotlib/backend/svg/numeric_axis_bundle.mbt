///|
priv struct AxisTickBundle {
  major : Array[Double]
  major_labels : Array[String]
  minor : Array[Double]
  minor_labels : Array[String]
  offset : String
}

///|
// Formatting can mutate state or raise, so resolve one axis in source order.
fn numeric_axis_bundle(
  axis : @axis.Axis,
  view : @core.Limits,
) -> AxisTickBundle raise @core.DataError {
  let initial_interval = axis.current_view_limits()
  let major_null = axis.tick_group_is_null()
  let (major, major_labels) = if major_null {
    ([], [])
  } else {
    let locations = axis.formatter_tick_locations_checked(view)
    let labels = match (axis.named_formatter(), locations) {
      (Some(formatter), @ticker.FormatterLocations::NdArray(_))
      | (Some(formatter), @ticker.FormatterLocations::Integers(_)) =>
        format_retained_locations(formatter, locations)
      _ =>
        axis.tick_labels_checked(
          materialize_formatter_locations(locations),
          view~,
        )
    }
    (materialize_formatter_locations(locations), labels)
  }
  let minor_null = axis.tick_group_is_null(minor=true)
  // Major callbacks may have explicitly changed the live view.
  let view = match (initial_interval, axis.current_view_limits()) {
    (Some(before), Some(after)) =>
      if before.lower().reinterpret_as_uint64() !=
        after.lower().reinterpret_as_uint64() ||
        before.upper().reinterpret_as_uint64() !=
        after.upper().reinterpret_as_uint64() {
        after
      } else {
        view
      }
    (None, Some(after)) => after
    _ => view
  }
  let (minor, minor_labels) = if minor_null {
    ([], [])
  } else {
    let locations = axis.formatter_tick_locations_checked(view, minor=true)
    let labels = match (axis.minor_named_formatter(), locations) {
      (Some(formatter), @ticker.FormatterLocations::NdArray(_))
      | (Some(formatter), @ticker.FormatterLocations::Integers(_)) =>
        format_retained_locations(formatter, locations)
      _ =>
        axis.minor_tick_labels_checked(
          materialize_formatter_locations(locations),
          view~,
        )
    }
    (materialize_formatter_locations(locations), labels)
  }
  let offset = if major_null && axis.named_formatter() is None {
    ""
  } else {
    axis.formatter_offset_label_checked(major, view~)
  }
  { major, major_labels, minor, minor_labels, offset, }
}

///|
fn format_retained_locations(
  formatter : @ticker.BaseFormatter,
  locations : @ticker.FormatterLocations,
) -> Array[String] raise @core.DataError {
  match locations {
    Sequence(values) => formatter.format_ticks(values)
    Integers(values) => formatter.format_ticks_integers(values)
    NdArray(values) => formatter.format_ticks_view(values)
    // Extra typed snapshots belong to formatter caches. Axis providers retain
    // Sequence/NdArray inputs; geometry materialization uses Double coordinates.
    Typed(_) =>
      formatter.format_ticks(materialize_formatter_locations(locations))
  }
}

///|
fn materialize_formatter_locations(
  locations : @ticker.FormatterLocations,
) -> Array[Double] raise @core.DataError {
  match locations {
    Sequence(values) => values.copy()
    Integers(values) => {
      let result : Array[Double] = []
      for index in 0..<values.length() {
        result.push(locations.get(index))
      }
      result
    }
    NdArray(values) => values.to_array()
    Typed(values) => {
      let result : Array[Double] = []
      for index in 0..<values.length() {
        result.push(values.get(index))
      }
      result
    }
  }
}
