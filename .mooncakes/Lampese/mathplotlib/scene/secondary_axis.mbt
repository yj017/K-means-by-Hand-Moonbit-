///|
/// Location of a secondary coordinate axis.
pub(all) enum SecondaryAxisLocation {
  Top
  Bottom
  Left
  Right
  Position(Double)
}

///|
/// Decoration side, independent of the requested secondary-axis location.
pub(all) enum SecondaryAxisAlignment {
  Top
  Bottom
  Left
  Right
}

///|
/// A coordinate axis whose values are derived from a primary axis.
pub struct SecondaryAxis {
  priv numeric_axis : @axis.Axis
  priv draw_order : Int32
  priv horizontal : Bool
  priv figure_bounds : @transforms.BBox
  priv original_bounds : @transforms.BBox
  priv mut active_bounds : @transforms.BBox
  priv mut parent_axis : @axis.Axis?
  priv mut parent_scale_name : String?
  priv mut ticks_set : Bool
  priv mut source_ticks_current : Bool
  priv mut legacy_sampling : Bool
  priv mut location : SecondaryAxisLocation
  priv mut location_locator : SecondaryLocationLocator
  priv mut alignment : SecondaryAxisAlignment
  priv mut forward : (Double) -> Double
  priv mut inverse : (Double) -> Double
  mut label : String?
}

///|
fn secondary_axis(
  location : SecondaryAxisLocation,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  horizontal~ : Bool,
  figure_bounds~ : @transforms.BBox,
  draw_order~ : Int32 = 0,
) -> SecondaryAxis {
  let original_bounds = if horizontal {
    @transforms.bbox_from_bounds(0.0, 1.0, 1.0, 0.0001)
  } else {
    @transforms.bbox_from_bounds(0.0, 1.0, 0.0001, 1.0)
  }
  let low = secondary_location_position(location) < 0.5
  let alignment = if horizontal {
    if low {
      SecondaryAxisAlignment::Bottom
    } else {
      Top
    }
  } else if low {
    SecondaryAxisAlignment::Left
  } else {
    SecondaryAxisAlignment::Right
  }
  let result : SecondaryAxis = {
    numeric_axis: @axis.axis(horizontal~),
    draw_order,
    horizontal,
    figure_bounds,
    original_bounds,
    active_bounds: original_bounds,
    parent_axis: None,
    parent_scale_name: None,
    ticks_set: false,
    source_ticks_current: false,
    legacy_sampling: false,
    location,
    location_locator: {
      position: secondary_location_position(location),
      transform: None,
    },
    alignment,
    forward,
    inverse,
    label: None,
  }
  result.numeric_axis.bind_data_interval(() => (1.0 / 0.0, -1.0 / 0.0))
  result.numeric_axis.bind_minpos(() => 1.0 / 0.0)
  result.numeric_axis.bind_shared_minpos(() => [1.0 / 0.0])
  result.numeric_axis.bind_autoscale_minpos(() => [1.0 / 0.0])
  result.numeric_axis.bind_tick_geometry(
    () => {
      let (origin, length) = result.formatter_geometry()
      // The source applies the inverse affine's already-rounded reciprocal.
      // Dividing each endpoint by 72 changes the y constructor's tick space.
      let inverse_dpi = 1.0 / 72.0
      ((origin + length) * inverse_dpi - origin * inverse_dpi) * 72.0
    },
    horizontal,
  )
  result.numeric_axis.bind_formatter_geometry(() => result.formatter_geometry())
  result
}

///|
pub fn SecondaryAxis::location(self : SecondaryAxis) -> SecondaryAxisLocation {
  self.location
}

///|
pub fn SecondaryAxis::forward(self : SecondaryAxis) -> (Double) -> Double {
  self.forward
}

///|
pub fn SecondaryAxis::inverse(self : SecondaryAxis) -> (Double) -> Double {
  self.inverse
}

///|
pub fn SecondaryAxis::set_label(self : SecondaryAxis, value : String) -> Unit {
  self.label = Some(value)
}

///|
pub fn SecondaryAxis::label(self : SecondaryAxis) -> String? {
  self.label
}

///|
/// Select the legacy parent-grid sampler only while no explicit locator owns ticks.
pub fn SecondaryAxis::set_tick_count(
  self : SecondaryAxis,
  value : Int32,
) -> Unit {
  self.numeric_axis.set_tick_count(value)
  if self.numeric_axis.locator() is None {
    self.legacy_sampling = true
    self.source_ticks_current = false
  }
}

///|
pub fn SecondaryAxis::tick_count(self : SecondaryAxis) -> Int32 {
  self.numeric_axis.tick_count()
}

///|
pub fn SecondaryAxis::set_ticks(
  self : SecondaryAxis,
  values : Array[Double],
) -> Unit raise @core.DataError {
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="secondary tick positions must be finite",
      )
    }
  }
  self.numeric_axis.set_source_ticks(values)
  self.ticks_set = true
  self.source_ticks_current = true
  self.legacy_sampling = false
}

///|
/// Return a copy of the currently retained explicit set_ticks positions.
pub fn SecondaryAxis::ticks(self : SecondaryAxis) -> Array[Double]? {
  if !self.source_ticks_current {
    return None
  }
  match self.numeric_axis.locator() {
    Some(@ticker.Locator::NamedFixed(value)) =>
      // set_source_ticks owns this buffer; only checked element mutation is
      // exposed through its view, so this compatibility projection is valid.
      Some(try! value.locations().to_array())
    _ => None
  }
}

///|
/// Install a locator in the secondary axis' own coordinates and stable context.
pub fn SecondaryAxis::set_locator(
  self : SecondaryAxis,
  locator : @ticker.Locator,
) -> Unit raise @core.DataError {
  match locator {
    @ticker.Locator::Fixed(values) =>
      for value in values {
        if value.is_nan() || value.is_inf() {
          raise @core.DataError::InvalidTicks(
            message="secondary locator values must be finite",
          )
        }
      }
    _ => ()
  }
  self.numeric_axis.set_locator(locator)
  self.source_ticks_current = false
  self.legacy_sampling = false
}

///|
pub fn SecondaryAxis::locator(self : SecondaryAxis) -> @ticker.Locator? {
  self.numeric_axis.locator()
}

///|
/// Explicit convenience extension restoring the legacy parent-grid sampler.
pub fn SecondaryAxis::clear_locator(self : SecondaryAxis) -> Unit {
  self.numeric_axis.clear_locator()
  self.source_ticks_current = false
  self.legacy_sampling = true
}

///|
pub fn SecondaryAxis::set_formatter(
  self : SecondaryAxis,
  formatter : @ticker.Formatter,
) -> Unit {
  self.numeric_axis.set_formatter(formatter)
}

///|
pub fn SecondaryAxis::formatter(self : SecondaryAxis) -> @ticker.Formatter? {
  self.numeric_axis.formatter()
}

///|
/// Clear both major formatter roles and restore explicit plain numeric labels.
pub fn SecondaryAxis::clear_formatter(self : SecondaryAxis) -> Unit {
  self.numeric_axis.clear_formatter()
}

///|
/// Add a secondary x axis derived from the primary x coordinate.
pub fn Axes::secondary_xaxis(
  self : Axes,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  location~ : SecondaryAxisLocation = SecondaryAxisLocation::Top,
  transform~ : @transforms.Affine2D? = None,
) -> SecondaryAxis raise @core.DataError {
  match location {
    SecondaryAxisLocation::Top
    | SecondaryAxisLocation::Bottom
    | SecondaryAxisLocation::Position(_) => ()
    SecondaryAxisLocation::Left | SecondaryAxisLocation::Right =>
      raise @core.DataError::InvalidTicks(
        message="secondary x axis location must be top or bottom",
      )
  }
  let result = secondary_axis(
    location,
    forward,
    inverse,
    horizontal=true,
    figure_bounds=@transforms.bbox(
      0.0,
      0.0,
      self.figure.width.to_double(),
      self.figure.height.to_double(),
    ),
    draw_order=self.state.val.secondary_x.length() +
      self.state.val.secondary_y.length(),
  )
  result.parent_axis = Some(self.x_axis())
  result.set_location(location, transform~)
  result.initialize_formatter_view()
  self.state.val.secondary_x.push(result)
  result
}

///|
/// Add a secondary y axis derived from the primary y coordinate.
pub fn Axes::secondary_yaxis(
  self : Axes,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  location~ : SecondaryAxisLocation = SecondaryAxisLocation::Right,
  transform~ : @transforms.Affine2D? = None,
) -> SecondaryAxis raise @core.DataError {
  match location {
    SecondaryAxisLocation::Left
    | SecondaryAxisLocation::Right
    | SecondaryAxisLocation::Position(_) => ()
    SecondaryAxisLocation::Top | SecondaryAxisLocation::Bottom =>
      raise @core.DataError::InvalidTicks(
        message="secondary y axis location must be left or right",
      )
  }
  let result = secondary_axis(
    location,
    forward,
    inverse,
    horizontal=false,
    figure_bounds=@transforms.bbox(
      0.0,
      0.0,
      self.figure.width.to_double(),
      self.figure.height.to_double(),
    ),
    draw_order=self.state.val.secondary_x.length() +
      self.state.val.secondary_y.length(),
  )
  result.parent_axis = Some(self.y_axis())
  result.set_location(location, transform~)
  result.initialize_formatter_view()
  self.state.val.secondary_y.push(result)
  result
}

///|
/// Add a secondary x axis to the default axes panel.
pub fn Figure::secondary_xaxis(
  self : Figure,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  location~ : SecondaryAxisLocation = SecondaryAxisLocation::Top,
  transform~ : @transforms.Affine2D? = None,
) -> SecondaryAxis raise @core.DataError {
  self.axes().secondary_xaxis(forward, inverse, location~, transform~)
}

///|
/// Add a secondary y axis to the default axes panel.
pub fn Figure::secondary_yaxis(
  self : Figure,
  forward : (Double) -> Double,
  inverse : (Double) -> Double,
  location~ : SecondaryAxisLocation = SecondaryAxisLocation::Right,
  transform~ : @transforms.Affine2D? = None,
) -> SecondaryAxis raise @core.DataError {
  self.axes().secondary_yaxis(forward, inverse, location~, transform~)
}
