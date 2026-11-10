///|
/// Stable typed identity used by explicitly installed named formatters.
pub fn Axis::formatter_axis_binding(
  self : Axis,
) -> @ticker.FormatterAxisBinding {
  self.formatter_axis_binding
}

///|
pub fn Axis::formatter_warnings(self : Axis) -> Array[String] {
  self.formatter_messages.copy()
}

///|
fn Axis::check_named_formatter_install(
  self : Axis,
  formatter : @ticker.BaseFormatter,
  minor : Bool,
) -> Unit {
  self.formatter_messages.clear()
  let fixed_locator = if minor {
    self.tickers.minor_locator_kind == Numeric &&
    self.tickers.minor_locator
    is Some(
      @ticker.MinorLocator::NamedFixed(_)
      | @ticker.MinorLocator::Fixed(_)
    )
  } else {
    self.tickers.major_locator_kind == Numeric &&
    (
      self.tickers.fixed_ticks is Some(_) ||
      self.tickers.locator
      is Some(@ticker.Locator::NamedFixed(_) | @ticker.Locator::Fixed(_))
    )
  }
  if formatter.fixed_formatter() is Some(fixed) &&
    fixed.seq().length() > 0 &&
    !fixed_locator {
    self.formatter_messages.push(
      "FixedFormatter should only be used together with FixedLocator",
    )
  }
}

///|
/// Install a live checked formatter independently of the legacy pure helpers.
pub fn Axis::set_named_formatter(
  self : Axis,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.check_named_formatter_install(formatter, false)
  self.tickers.major_formatter_kind = Numeric
  self.tickers.major_formatter_default = false
  self.tickers.named_formatter = Some(formatter)
  self.tickers.formatter = None
  self.tickers.date_formatter = None
  self.tickers.date_format = None
  self.tickers.fixed_labels = None
  self.bind_formatter_axis()
}

///|
pub fn Axis::named_formatter(self : Axis) -> @ticker.BaseFormatter? {
  if self.tickers.major_formatter_kind == Numeric {
    self.tickers.named_formatter
  } else {
    None
  }
}

///|
pub fn Axis::set_minor_named_formatter(
  self : Axis,
  formatter : @ticker.BaseFormatter,
) -> Unit {
  self.check_named_formatter_install(formatter, true)
  self.tickers.minor_formatter_kind = Numeric
  self.tickers.minor_formatter_default = false
  self.tickers.minor_named_formatter = Some(formatter)
  self.tickers.minor_date_formatter = None
  self.bind_formatter_axis(minor=true)
}

///|
pub fn Axis::minor_named_formatter(self : Axis) -> @ticker.BaseFormatter? {
  if self.tickers.minor_formatter_kind == Numeric {
    self.tickers.minor_named_formatter
  } else {
    None
  }
}

///|
pub fn Axis::clear_named_formatter(self : Axis) -> Unit {
  self.tickers.major_formatter_kind = Numeric
  self.tickers.major_formatter_default = false
  self.tickers.named_formatter = None
}

///|
pub fn Axis::clear_minor_named_formatter(self : Axis) -> Unit {
  self.tickers.minor_formatter_kind = Numeric
  self.tickers.minor_formatter_default = false
  self.tickers.minor_named_formatter = None
}

///|
/// Rebind installed handles after shared-axis installation or removal.
pub fn Axis::bind_formatter_axis(self : Axis, minor~ : Bool = false) -> Unit {
  let formatter = if minor {
    self.minor_named_formatter()
  } else {
    self.named_formatter()
  }
  if formatter is Some(formatter) {
    formatter.set_axis(Some(self.formatter_axis_binding))
  }
}

///|
/// Keep a locator's borrowed numeric view until the corresponding batch ends.
pub fn Axis::formatter_tick_locations_checked(
  self : Axis,
  automatic : @core.Limits,
  minor~ : Bool = false,
) -> @ticker.FormatterLocations raise @core.DataError {
  let active = if minor {
    self.minor_named_formatter()
  } else {
    self.named_formatter()
  }
  let kind = if minor {
    self.tickers.minor_locator_kind
  } else {
    self.tickers.major_locator_kind
  }
  if kind == Category {
    let values = self.tickers.category_locator_units
      .map(units => {
        Array::makei(units.labels().length(), index => {
          @bigint.BigInt::from_int(index)
        })
      })
      .unwrap_or([])
    return @ticker.FormatterLocations::Integers(values)
  }
  let formatter_kind = if minor {
    self.tickers.minor_formatter_kind
  } else {
    self.tickers.major_formatter_kind
  }
  if active is None && formatter_kind == Numeric {
    return @ticker.FormatterLocations::Sequence(
      if minor {
        self.minor_tick_values_checked(automatic)
      } else {
        self.tick_values_checked(automatic)
      },
    )
  }
  let limits = self.limits.unwrap_or(automatic)
  let previous = self.tick_layout_view
  if previous is None && !self.has_view_interval_provider() {
    self.tick_layout_view = Some((limits.lower(), limits.upper()))
  }
  defer {
    self.tick_layout_view = previous
  }
  let view = if minor {
    self.raw_formatter_minor_view_checked(limits)
  } else if kind == Date {
    self.major_tick_view_checked()
  } else if self.tickers.fixed_ticks is Some(values) {
    @ticker.TickValues::from_array(values)
  } else if self.tickers.locator is Some(@ticker.Locator::Fixed(values)) {
    @ticker.TickValues::from_array(values)
  } else if self.tickers.locator is Some(@ticker.Locator::Multiple(locator)) {
    let (lower, upper) = self.view_interval_checked()
    @ticker.TickValues::from_array(locator.tick_values(lower, upper))
  } else {
    self.major_tick_view_checked()
  }
  if minor && self.remove_minor_overlap {
    let major = self.major_tick_view_checked().to_array()
    let mask = self.numeric_minor_selection_mask(view.to_array(), major)
    return @ticker.FormatterLocations::NdArray(view.select_mask(mask))
  }
  @ticker.FormatterLocations::NdArray(view)
}

///|
fn Axis::raw_formatter_minor_view_checked(
  self : Axis,
  limits : @core.Limits,
) -> @ticker.TickValues raise @core.DataError {
  if self.tickers.minor_locator_kind == Date {
    return @ticker.TickValues::from_array(
      self.date_locator_tick_values_checked(limits, true),
    )
  }
  if self.tickers.minor_locator_kind == Category {
    return @ticker.TickValues::from_array([])
  }
  let values = match self.tickers.minor_locator {
    None => return @ticker.TickValues::from_array([])
    Some(@ticker.MinorLocator::NamedFixed(locator)) =>
      return locator.tick_values(0.0, 0.0)
    Some(@ticker.MinorLocator::Fixed(values)) =>
      return @ticker.TickValues::from_array(values)
    Some(@ticker.MinorLocator::NamedLinear(locator)) =>
      return locator.tick_values(limits.lower(), limits.upper())
    Some(@ticker.MinorLocator::Multiple(locator)) => {
      let (lower, upper) = self.view_interval_checked()
      locator.tick_values(lower, upper)
    }
    Some(@ticker.MinorLocator::NamedLogit(locator)) => locator.call()
    Some(@ticker.MinorLocator::NamedAsinh(locator)) => locator.call()
    Some(@ticker.MinorLocator::NamedSymLog(locator)) => locator.call()
    Some(@ticker.MinorLocator::NamedLog(locator)) => locator.call()
    Some(@ticker.MinorLocator::NamedAutoMinor(locator)) => locator.call()
    Some(@ticker.MinorLocator::Null(locator)) => locator.call()
    Some(@ticker.MinorLocator::Index(locator)) => locator.call()
    Some(@ticker.MinorLocator::NamedMaxN(locator)) => locator.call()
    Some(@ticker.MinorLocator::NamedAuto(locator)) => locator.call()
    Some(_) => self.minor_tick_values_checked(limits)
  }
  @ticker.TickValues::from_array(values)
}

///|
pub fn Axis::tick_labels_checked(
  self : Axis,
  values : Array[Double],
  view? : @core.Limits,
) -> Array[String] raise @core.DataError {
  if self.tickers.major_formatter_kind == Category {
    return match self.category_for_labels() {
      Some(units) => units.format_values(values)
      None => Array::make(values.length(), "")
    }
  }
  if self.tickers.major_formatter_kind == Numeric &&
    self.tickers.named_formatter is Some(formatter) {
    return formatter.format_ticks(values)
  }
  self.tick_labels_with_view(values, view)
}

///|
pub fn Axis::minor_tick_labels_checked(
  self : Axis,
  values : Array[Double],
  view? : @core.Limits,
) -> Array[String] raise @core.DataError {
  if self.tickers.minor_formatter_kind == Numeric &&
    self.tickers.minor_named_formatter is Some(formatter) {
    return formatter.format_ticks(values)
  }
  match view {
    Some(view) => self.minor_tick_labels(values, view~)
    None => self.minor_tick_labels(values)
  }
}

///|
/// Read the live major offset after its batch, without formatting a second time.
pub fn Axis::formatter_offset_label_checked(
  self : Axis,
  values : Array[Double],
  view? : @core.Limits,
) -> String raise @core.DataError {
  if self.tickers.major_formatter_kind == Numeric &&
    self.tickers.named_formatter is Some(formatter) {
    return formatter.get_offset_checked()
  }
  self.formatter_offset_label_with_view(values, view)
}
