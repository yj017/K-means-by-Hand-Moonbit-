///|
/// Bind local artist data without changing the locator's owning axis.
pub fn Axis::bind_data_interval(
  self : Axis,
  provider : () -> (Double, Double),
) -> Unit {
  self.data_interval_provider = Some(provider)
}

///|
pub fn Axis::data_interval(self : Axis) -> @core.Limits {
  match self.data_interval_provider {
    Some(provider) => {
      let (lower, upper) = provider()
      @core.limits(lower, upper)
    }
    None => @core.limits(1.0 / 0.0, -1.0 / 0.0)
  }
}

///|
/// Rebind after setting a shared locator so its last explicit owner supplies data.
pub fn Axis::bind_locator_data(self : Axis, minor~ : Bool = false) -> Unit {
  if minor && self.tickers.minor_locator_kind == Date {
    self.tickers.minor_date_view_provider = Some(() => {
      self.view_interval_checked()
    })
    return
  }
  if !minor && self.tickers.major_locator_kind == Date {
    self.tickers.major_date_view_provider = Some(() => {
      self.view_interval_checked()
    })
    return
  }
  if (minor && self.tickers.minor_locator_kind != Numeric) ||
    (!minor && self.tickers.major_locator_kind != Numeric) {
    return
  }
  let provider = fn() {
    let values = self.data_interval()
    (values.lower(), values.upper())
  }
  if minor {
    match self.tickers.minor_locator {
      Some(@ticker.MinorLocator::NamedLogit(value)) =>
        self.bind_logit_context(value)
      Some(@ticker.MinorLocator::NamedAsinh(value)) =>
        value.bind_view_interval(() => self.view_interval_checked())
      Some(@ticker.MinorLocator::NamedSymLog(value)) =>
        value.bind_view_interval(() => self.view_interval_checked())
      Some(@ticker.MinorLocator::NamedLog(value)) =>
        self.bind_log_context(value)
      Some(@ticker.MinorLocator::NamedAutoMinor(value)) =>
        self.bind_auto_minor_context(value)
      Some(@ticker.MinorLocator::Index(value)) =>
        value.bind_data_interval(provider)
      Some(@ticker.MinorLocator::NamedMaxN(value)) =>
        self.bind_maxn_context(value)
      Some(@ticker.MinorLocator::NamedAuto(value)) =>
        self.bind_maxn_context(value.as_maxn_locator())
      _ => ()
    }
  } else {
    match self.tickers.locator {
      Some(@ticker.Locator::NamedLogit(value)) => self.bind_logit_context(value)
      Some(@ticker.Locator::NamedAsinh(value)) =>
        value.bind_view_interval(() => self.view_interval_checked())
      Some(@ticker.Locator::NamedSymLog(value)) =>
        value.bind_view_interval(() => self.view_interval_checked())
      Some(@ticker.Locator::NamedLog(value)) => self.bind_log_context(value)
      Some(@ticker.Locator::Index(value)) => value.bind_data_interval(provider)
      Some(@ticker.Locator::NamedMaxN(value)) => self.bind_maxn_context(value)
      Some(@ticker.Locator::NamedAuto(value)) =>
        self.bind_maxn_context(value.as_maxn_locator())
      _ => ()
    }
  }
}

///|
/// New named numeric locators preserve their direct errors in checked rendering.
pub fn Axis::tick_values_checked(
  self : Axis,
  automatic : @core.Limits,
) -> Array[Double] raise @core.DataError {
  if self.tickers.major_locator_kind == Category {
    return self.tickers.category_locator_units
      .map(units => units.positions())
      .unwrap_or([])
  }
  if self.tickers.major_locator_kind == Date {
    return self.date_locator_tick_values_checked(
      self.limits.unwrap_or(automatic),
      false,
    )
  }
  if (
      self.tickers.named_formatter is Some(_) ||
      self.tickers.minor_named_formatter is Some(_)
    ) &&
    self.tickers.fixed_ticks is None &&
    self.numeric_tickers_active() &&
    self.tickers.locator is Some(@ticker.Locator::Fixed(values)) {
    return values.copy()
  }
  if self.tickers.fixed_ticks is None &&
    self.tickers.major_locator_kind == Numeric {
    if self.tickers.locator
      is Some(
        @ticker.Locator::NamedLogit(_)
        | @ticker.Locator::NamedAsinh(_)
        | @ticker.Locator::NamedSymLog(_)
        | @ticker.Locator::NamedLog(_)
        | @ticker.Locator::Null(_)
        | @ticker.Locator::NamedLinear(_)
        | @ticker.Locator::Index(_)
        | @ticker.Locator::NamedFixed(_)
        | @ticker.Locator::NamedMaxN(_)
        | @ticker.Locator::NamedAuto(_)
      ) {
      let limits = self.limits.unwrap_or(automatic)
      let previous = self.tick_layout_view
      if previous is None && !self.has_view_interval_provider() {
        self.tick_layout_view = Some((limits.lower(), limits.upper()))
      }
      defer {
        self.tick_layout_view = previous
      }
      return self.tickers.locator
        .unwrap()
        .tick_values_for_axis(limits.lower(), limits.upper())
    }
  }
  self.tick_values(automatic)
}

///|
pub fn Axis::minor_tick_values_checked(
  self : Axis,
  automatic : @core.Limits,
) -> Array[Double] raise @core.DataError {
  if self.tickers.minor_locator_kind == Date {
    let limits = self.limits.unwrap_or(automatic)
    let ticks = self.date_locator_tick_values_checked(limits, true)
    if !self.remove_minor_overlap {
      return ticks
    }
    let major = self.major_tick_view_checked().to_array()
    return self.filter_numeric_minor_ticks(ticks, major)
  }
  if self.tickers.minor_locator_kind == Numeric {
    if self.tickers.minor_locator is Some(@ticker.MinorLocator::Null(value)) {
      let ticks = value.call()
      if self.remove_minor_overlap {
        // Direct Axis getters still read majors/view; rendering skips Null earlier.
        let major = self.major_tick_view_checked().to_array()
        return self.filter_numeric_minor_ticks(ticks, major)
      }
      return ticks
    }
    let typed_formatter = self.tickers.minor_formatter_kind != Numeric
    let raw_named_fixed = (
        self.scale.is_logit() ||
        self.tickers.minor_named_formatter is Some(_) ||
        typed_formatter
      ) &&
      self.tickers.minor_locator is Some(@ticker.MinorLocator::NamedFixed(_))
    let raw_legacy_fixed = (
        self.tickers.minor_named_formatter is Some(_) || typed_formatter
      ) &&
      self.tickers.minor_locator is Some(@ticker.MinorLocator::Fixed(_))
    if self.tickers.minor_locator
      is Some(
        @ticker.MinorLocator::NamedAutoMinor(_)
        | @ticker.MinorLocator::NamedLog(_)
        | @ticker.MinorLocator::NamedLogit(_)
        | @ticker.MinorLocator::NamedAsinh(_)
        | @ticker.MinorLocator::NamedSymLog(_)
      ) ||
      raw_named_fixed ||
      raw_legacy_fixed {
      let limits = self.limits.unwrap_or(automatic)
      let previous = self.tick_layout_view
      if previous is None && !self.has_view_interval_provider() {
        self.tick_layout_view = Some((limits.lower(), limits.upper()))
      }
      defer {
        self.tick_layout_view = previous
      }
      // Source minor.call reads its own owner first. Axis overlap reads major again.
      let ticks = match self.tickers.minor_locator.unwrap() {
        @ticker.MinorLocator::Fixed(values) => values.copy()
        @ticker.MinorLocator::NamedFixed(value) => {
          let locations = value.tick_values(0.0, 0.0)
          if typed_formatter {
            locations.to_array()
          } else {
            locations
            .view(0, 1, Int32::min(100000, locations.length()))
            .to_array()
          }
        }
        @ticker.MinorLocator::NamedAutoMinor(value) => value.call()
        @ticker.MinorLocator::NamedLog(value) => value.call()
        @ticker.MinorLocator::NamedLogit(value) => value.call()
        @ticker.MinorLocator::NamedAsinh(value) => value.call()
        @ticker.MinorLocator::NamedSymLog(value) => value.call()
        _ => []
      }
      if !self.remove_minor_overlap {
        return ticks
      }
      let major = self.major_tick_view_checked().to_array()
      return self.filter_numeric_minor_ticks(ticks, major)
    }
    if self.tickers.minor_locator
      is Some(
        @ticker.MinorLocator::NamedLinear(_)
        | @ticker.MinorLocator::Index(_)
        | @ticker.MinorLocator::NamedFixed(_)
        | @ticker.MinorLocator::NamedMaxN(_)
        | @ticker.MinorLocator::NamedAuto(_)
      ) {
      let limits = self.limits.unwrap_or(automatic)
      let previous = self.tick_layout_view
      if previous is None && !self.has_view_interval_provider() {
        self.tick_layout_view = Some((limits.lower(), limits.upper()))
      }
      defer {
        self.tick_layout_view = previous
      }
      let major = self.tick_values_checked(automatic)
      let ticks = self.tickers.minor_locator
        .unwrap()
        .tick_values_for_axis(major, limits.lower(), limits.upper())
      return ticks
    }
  }
  self.minor_tick_values(automatic)
}

///|
fn Axis::bind_auto_minor_context(
  self : Axis,
  value : @ticker.AutoMinorLocator,
) -> Unit {
  value.bind_scale(() => self.numeric_scale_name())
  value.bind_axis_name(() => if self.tick_horizontal { "x" } else { "y" })
  value.bind_major_ticks(() => self.major_tick_view_checked())
  value.bind_view_interval(() => self.view_interval_checked())
}

///|
fn Axis::numeric_scale_name(self : Axis) -> String {
  self.coordinate_scale_name()
}

///|
/// Obtain majors in source order while preserving borrowed integer storage.
fn Axis::major_tick_view_checked(
  self : Axis,
) -> @ticker.TickValues raise @core.DataError {
  if self.tickers.major_locator_kind != Numeric {
    let (lower, upper) = self.view_interval_checked()
    return @ticker.TickValues::from_array(
      self.tick_values_checked(@core.limits(lower, upper)),
    )
  }
  if self.tickers.fixed_ticks is Some(values) {
    return @ticker.TickValues::from_array(values.copy())
  }
  if self.tickers.major_locator_kind == Numeric {
    match self.tickers.locator {
      Some(@ticker.Locator::Fixed(values)) if self.tickers.named_formatter
        is Some(_) ||
        self.tickers.minor_named_formatter is Some(_) =>
        return @ticker.TickValues::from_array(values.copy())
      Some(@ticker.Locator::NamedFixed(value)) =>
        return value.tick_values(0.0, 0.0)
      Some(@ticker.Locator::Null(_)) =>
        return @ticker.TickValues::from_array([])
      Some(locator) if locator
        is (@ticker.Locator::NamedLogit(_)
        | @ticker.Locator::NamedAsinh(_)
        | @ticker.Locator::NamedSymLog(_)
        | @ticker.Locator::NamedLog(_)
        | @ticker.Locator::Index(_)
        | @ticker.Locator::NamedMaxN(_)
        | @ticker.Locator::NamedAuto(_)) =>
        return locator.tick_view_for_axis(0.0, 0.0)
      Some(@ticker.Locator::NamedLinear(value)) => {
        let (lower, upper) = self.view_interval_checked()
        return value.tick_values(lower, upper)
      }
      _ => ()
    }
  }
  let (lower, upper) = self.view_interval_checked()
  @ticker.TickValues::from_array(
    self.tick_values_checked(@core.limits(lower, upper)),
  )
}

///|
// Date objects share ticker state, while checked conversion/selection errors
// remain visible to the same Axis and SVG pipeline as named numeric errors.
fn Axis::date_locator_tick_values_checked(
  self : Axis,
  limits : @core.Limits,
  minor : Bool,
) -> Array[Double] raise @core.DataError {
  let previous = self.tick_layout_view
  if previous is None && !self.has_view_interval_provider() {
    self.tick_layout_view = Some((limits.lower(), limits.upper()))
  }
  defer {
    self.tick_layout_view = previous
  }
  let provider = if minor {
    self.tickers.minor_date_view_provider
  } else {
    self.tickers.major_date_view_provider
  }
  let limits = match provider {
    Some(provider) => {
      let (lower, upper) = provider()
      @core.limits(lower, upper)
    }
    None => limits
  }
  let locator = if minor {
    self.tickers.minor_date_locator
  } else {
    self.tickers.date_locator
  }
  if locator is Some(locator) {
    return locator.tick_values_checked(limits.lower(), limits.upper()) catch {
      @date.DateError::InvalidDate(message~)
      | @date.DateError::InvalidFormat(message~) =>
        raise @core.DataError::InvalidTicks(message~)
    }
  }
  if !minor && self.tickers.automatic_date_locator is Some(locator) {
    return locator.tick_values(limits.lower(), limits.upper()) catch {
      @date.DateError::InvalidDate(message~)
      | @date.DateError::InvalidFormat(message~) =>
        raise @core.DataError::InvalidTicks(message~)
    }
  }
  []
}

///|
fn Axis::filter_numeric_minor_ticks(
  self : Axis,
  ticks : Array[Double],
  major : Array[Double],
) -> Array[Double] raise @core.DataError {
  let mask = self.numeric_minor_selection_mask(ticks, major)
  let selected : Array[Double] = []
  for index, tick in ticks {
    if mask[index] {
      selected.push(tick)
    }
  }
  selected
}

///|
fn Axis::numeric_minor_selection_mask(
  self : Axis,
  ticks : Array[Double],
  major : Array[Double],
) -> Array[Bool] raise @core.DataError {
  // Axis.get_minorticklocs captures one transform after both locator queries.
  // Function callbacks run on minors, then majors, before the late view read.
  let transform = self.minor_overlap_transform()
  let transformed_ticks = ticks.map(transform)
  let transformed_major = major.map(transform)
  let (lower, upper) = self.view_interval_checked()
  let lo = transform(lower)
  let hi = transform(upper)
  let tolerance = Double::abs(hi - lo) * 1.0e-5
  transformed_ticks.map(transformed => {
    !transformed_major.any(other => {
      transformed == other ||
      (
        !other.is_nan() &&
        !other.is_inf() &&
        Double::abs(transformed - other) <= tolerance
      )
    })
  })
}

///|
/// Rendering skips each NullLocator tick group before asking for labels or offsets.
pub fn Axis::tick_group_is_null(self : Axis, minor~ : Bool = false) -> Bool {
  if minor {
    self.tickers.minor_locator_kind == Numeric &&
    self.tickers.minor_locator is Some(@ticker.MinorLocator::Null(_))
  } else {
    self.tickers.major_locator_kind == Numeric &&
    self.tickers.locator is Some(@ticker.Locator::Null(_))
  }
}

///|
// Source LogTransform uses nonpositive="clip" for tick overlap coordinates.
fn Axis::minor_overlap_transform(self : Axis) -> (Double) -> Double {
  if self.function_scale is Some(_) {
    return self.coordinate_transform()
  }
  let scale = self.scale
  fn(value) {
    if scale.is_log() && value <= 0.0 {
      -1000.0
    } else {
      scale.transform(value)
    }
  }
}
