///|
/// Live string-unit mapping shared by installed category tickers and axes.
/// The separate ticker/category convenience converter remains persistent.
pub struct CategoryUnits {
  priv labels : Array[String]
}

///|
pub fn CategoryUnits::new(labels : Array[String]) -> CategoryUnits {
  let result : CategoryUnits = { labels: [], }
  ignore(result.encode(labels))
  result
}

///|
pub fn CategoryUnits::labels(self : CategoryUnits) -> Array[String] {
  self.labels.copy()
}

///|
pub fn CategoryUnits::positions(self : CategoryUnits) -> Array[Double] {
  Array::makei(self.labels.length(), index => index.to_double())
}

///|
pub fn CategoryUnits::encode(
  self : CategoryUnits,
  values : Array[String],
) -> Array[Double] {
  values.map(value => {
    let mut found : Int32? = None
    for index, label in self.labels {
      if label == value {
        found = Some(index)
        break
      }
    }
    let index = match found {
      Some(index) => index
      None => {
        let index = self.labels.length()
        self.labels.push(value)
        index
      }
    }
    index.to_double()
  })
}

///|
pub fn CategoryUnits::format_values(
  self : CategoryUnits,
  values : Array[Double],
) -> Array[String] raise @core.DataError {
  values.map(value => {
    if value.is_nan() {
      raise @core.DataError::InvalidTicks(
        message="cannot convert float NaN to integer",
      )
    }
    if value.is_inf() {
      raise @core.DataError::InvalidTicks(
        message="cannot convert float infinity to integer",
      )
    }
    if value < -1.0 || value > self.labels.length().to_double() + 1.0 {
      ""
    } else {
      let lower = value.floor()
      let fraction = value - lower
      let rounded = lower +
        (if fraction > 0.5 || (fraction == 0.5 && lower % 2.0 != 0.0) {
          1.0
        } else {
          0.0
        })
      if rounded >= 0.0 && rounded < self.labels.length().to_double() {
        self.labels[rounded.to_int()]
      } else {
        ""
      }
    }
  })
}

///|
pub(all) enum AxisUnitTag {
  Date(@date.DateTimeZone)
  Category(CategoryUnits)
}

///|
priv enum AxisUnitConverter {
  DefaultDate
  ExplicitDate(@date.DateConverter)
  Category
}

///|
priv struct AxisUnitState {
  mut converter : AxisUnitConverter?
  mut explicit : Bool
  mut unit : AxisUnitTag?
  mut group : (() -> Array[Axis])?
  mut data_mutated : (() -> Bool)?
  mut changed : (() -> Unit raise @core.DataError)?
}

///|
fn AxisUnitState::new() -> AxisUnitState {
  {
    converter: None,
    explicit: false,
    unit: None,
    group: None,
    data_mutated: None,
    changed: None,
  }
}

///|
fn Axis::reset_unit_state(self : Axis) -> Unit {
  self.units_state.converter = None
  self.units_state.explicit = false
  self.units_state.unit = None
}

///|
pub fn Axis::bind_unit_group(self : Axis, provider : () -> Array[Axis]) -> Unit {
  self.units_state.group = Some(provider)
}

///|
pub fn Axis::bind_unit_data_mutated(self : Axis, provider : () -> Bool) -> Unit {
  self.units_state.data_mutated = Some(provider)
}

///|
pub fn Axis::bind_units_changed(
  self : Axis,
  provider : () -> Unit raise @core.DataError,
) -> Unit {
  self.units_state.changed = Some(provider)
}

///|
/// Converter presence and unit presence are independent on shared axes.
pub fn Axis::have_units(self : Axis) -> Bool {
  self.units_state.converter is Some(_) || self.units_state.unit is Some(_)
}

///|
pub fn Axis::unit_tag(self : Axis) -> AxisUnitTag? {
  self.units_state.unit
}

///|
pub fn Axis::unit_converter_explicit(self : Axis) -> Bool {
  self.units_state.explicit
}

///|
pub fn Axis::unit_converter_kind(self : Axis) -> String? {
  self.units_state.converter.map(value => {
    match value {
      DefaultDate => "default_date"
      ExplicitDate(_) => "explicit_date"
      Category => "category"
    }
  })
}

///|
pub fn Axis::get_category_units(self : Axis) -> CategoryUnits? {
  match self.units_state.unit {
    Some(Category(value)) => Some(value)
    _ => None
  }
}

///|
fn same_unit_tag(left : AxisUnitTag?, right : AxisUnitTag?) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(Date(a)), Some(Date(b))) => a.unit_equal(b)
    (Some(Category(a)), Some(Category(b))) => physical_equal(a, b)
    _ => false
  }
}

///|
fn Axis::units_date_converter(self : Axis) -> @date.DateConverter? {
  match self.units_state.converter {
    Some(DefaultDate) => Some(@date.default_date_converter())
    Some(ExplicitDate(value)) => Some(value)
    _ => None
  }
}

///|
fn Axis::units_date_info(
  self : Axis,
  converter : @date.DateConverter,
) -> @date.DateAxisInfo raise @core.DataError {
  let zone = match self.units_state.unit {
    None => None
    Some(Date(zone)) => Some(zone)
    Some(Category(_)) =>
      raise @core.DataError::InvalidTicks(
        message="date converter requires a date timezone unit",
      )
  }
  self.checked_date_axisinfo(converter, unit?=zone)
}

///|
/// Source set_converter assigns and marks explicit without updating axis info.
pub fn Axis::set_explicit_date_converter(
  self : Axis,
  converter : @date.DateConverter,
) -> Unit raise @core.DataError {
  if self.units_state.explicit {
    if self.units_state.converter is Some(ExplicitDate(current)) &&
      physical_equal(current, converter) {
      return
    }
    raise @core.DataError::InvalidTicks(
      message="Axis already has an explicit converter set",
    )
  }
  self.units_state.converter = Some(ExplicitDate(converter))
  self.units_state.explicit = true
}

///|
/// Reconsider converter defaults role by role, retaining explicit user slots.
pub fn Axis::update_unit_axisinfo(self : Axis) -> Unit raise @core.DataError {
  match self.units_state.converter {
    None => return
    Some(DefaultDate) | Some(ExplicitDate(_)) => {
      let converter = self.units_date_converter().unwrap()
      let info = self.units_date_info(converter)
      self.date_converter = Some(converter)
      if self.date_format is None {
        self.date_format = Some("")
      }
      self.date_timezone = info.major_locator().timezone()
      self.date_offset_minutes = info.major_locator().offset_minutes()
      self.date_timezone_is_default = self.units_state.unit is None
      self.date_timezone_override = false
      self.install_date_unit_defaults(info)
    }
    Some(Category) => {
      let units = match self.get_category_units() {
        Some(value) => value
        None =>
          raise @core.DataError::InvalidTicks(
            message="categorical converter requires category units",
          )
      }
      self.install_category_unit_defaults(units)
    }
  }
  self.set_unit_default_intervals()
}

///|
fn Axis::set_unit_default_intervals(self : Axis) -> Unit raise @core.DataError {
  if self.units_state.data_mutated is Some(provider) && provider() {
    return
  }
  let (first, last) = self.lifecycle_view_interval_checked()
  if first != 0.0 || last != 1.0 {
    return
  }
  if self.units_date_converter() is Some(converter) {
    // The source asks axisinfo a second time at the default-interval stage.
    let info = self.units_date_info(converter)
    let (first, last) = info.default_limits()
    let view = @core.limits(first.to_ordinal(), last.to_ordinal())
    self.stored_view = view
    self.inverted = view.lower() > view.upper()
    if self.autoscale_enabled {
      self.limits = None
      self.auto_view = Some(view)
    } else {
      self.limits = Some(view)
      self.auto_view = None
    }
    if self.tick_layout_view is Some(_) {
      self.tick_layout_view = Some((view.lower(), view.upper()))
    }
  }
}

///|
/// Assign each sibling before info/callbacks; failures leave preceding changes.
pub fn Axis::set_unit_tag(
  self : Axis,
  unit : AxisUnitTag?,
) -> Unit raise @core.DataError {
  if same_unit_tag(self.units_state.unit, unit) {
    return
  }
  let axes = match self.units_state.group {
    Some(provider) => provider()
    None => [self]
  }
  for axis in axes {
    axis.units_state.unit = unit
    axis.update_unit_axisinfo()
    if axis.units_state.changed is Some(provider) {
      provider()
    }
  }
}

///|
/// Select the implicit date converter from explicit naive/aware input.
pub fn Axis::update_date_units(
  self : Axis,
  values : Array[@date.RRuleDateTime],
) -> Bool raise @core.DataError {
  if values.is_empty() && !self.units_state.explicit {
    return false
  }
  if self.units_state.explicit && self.units_state.converter is Some(Category) {
    if !values.is_empty() {
      raise @core.DataError::InvalidTicks(
        message="'value' must be an instance of str or bytes, not a datetime.datetime",
      )
    }
    if self.units_state.unit is None {
      self.set_unit_tag(Some(AxisUnitTag::Category(CategoryUnits::new([]))))
    }
    return true
  }
  let need_new = if self.units_state.explicit {
    false
  } else {
    let changed = !(self.units_state.converter is Some(DefaultDate))
    self.units_state.converter = Some(DefaultDate)
    changed
  }
  let unit = if values.is_empty() {
    None
  } else {
    values[0].timezone().map(zone => AxisUnitTag::Date(zone))
  }
  if unit is Some(_) && self.units_state.unit is None {
    self.set_unit_tag(unit)
  } else if need_new {
    self.update_unit_axisinfo()
  }
  true
}

///|
/// Select/update live string units, without resetting installed user tickers.
pub fn Axis::update_category_units(
  self : Axis,
  values : Array[String],
) -> Bool raise @core.DataError {
  if values.is_empty() && !self.units_state.explicit {
    return false
  }
  if self.units_state.explicit &&
    !(self.units_state.converter is Some(Category)) {
    return true
  }
  let need_new = !self.units_state.explicit &&
    !(self.units_state.converter is Some(Category))
  self.units_state.converter = Some(Category)
  match self.units_state.unit {
    None =>
      self.set_unit_tag(Some(AxisUnitTag::Category(CategoryUnits::new(values))))
    Some(Category(units)) => ignore(units.encode(values))
    Some(Date(_)) =>
      raise @core.DataError::InvalidTicks(
        message="'datetime.timezone' object has no attribute 'update'",
      )
  }
  // default_units has already stored a non-None unit, so the original outer
  // update_units also updates info on a newly selected converter.
  if need_new {
    self.update_unit_axisinfo()
  }
  true
}

///|
pub fn Axis::convert_category_units(
  self : Axis,
  values : Array[String],
) -> Array[Double] raise @core.DataError {
  if self.units_state.converter is None {
    if values.is_empty() {
      return []
    }
    // convert_units discovers a converter but does not run default_units or
    // axisinfo. Shared peers may already have units but no local converter.
    self.units_state.converter = Some(Category)
  }
  match self.units_state.converter {
    Some(Category) =>
      match self.get_category_units() {
        Some(units) => units.encode(values)
        None =>
          raise @core.DataError::InvalidTicks(
            message="Missing category information for StrCategoryConverter",
          )
      }
    _ =>
      if values.is_empty() {
        []
      } else {
        raise @core.DataError::InvalidTicks(
          message="unsupported typed date conversion of string category values: NumPy datetime64 string grammar is not represented",
        )
      }
  }
}

///|
pub fn Axis::convert_date_units(
  self : Axis,
  values : Array[@date.RRuleDateTime],
) -> Array[Double] raise @core.DataError {
  if values.is_empty() {
    return []
  }
  if self.units_state.converter is None {
    self.units_state.converter = Some(DefaultDate)
  }
  if self.units_state.converter is Some(Category) {
    raise @core.DataError::InvalidTicks(
      message="categorical converter cannot convert datetime values",
    )
  }
  values.map(value => {
    value.to_ordinal() catch {
      @date.DateError::InvalidDate(message~)
      | @date.DateError::InvalidFormat(message~) =>
        raise @core.DataError::InvalidTicks(message~)
    }
  })
}

///|
fn Axis::replace_category_units_extension(
  self : Axis,
  units : CategoryUnits,
) -> Unit {
  self.units_state.converter = Some(Category)
  self.units_state.explicit = false
  self.units_state.unit = Some(AxisUnitTag::Category(units))
}

///|
fn Axis::clear_category_units_extension(self : Axis) -> Unit {
  if self.units_state.converter is Some(Category) ||
    self.units_state.unit is Some(AxisUnitTag::Category(_)) {
    self.units_state.converter = None
    self.units_state.explicit = false
    self.units_state.unit = None
  }
}

///|
fn Axis::clear_date_units_extension(self : Axis) -> Unit {
  if self.units_state.converter is Some(DefaultDate | ExplicitDate(_)) ||
    self.units_state.unit is Some(AxisUnitTag::Date(_)) {
    self.units_state.converter = None
    self.units_state.explicit = false
    self.units_state.unit = None
  }
}

///|
/// Explicitly select the builtin categorical converter, without installing info.
pub fn Axis::set_explicit_category_converter(
  self : Axis,
) -> Unit raise @core.DataError {
  if self.units_state.explicit &&
    !(self.units_state.converter is Some(Category)) {
    raise @core.DataError::InvalidTicks(
      message="Axis already has an explicit converter set",
    )
  }
  self.units_state.converter = Some(Category)
  self.units_state.explicit = true
}
