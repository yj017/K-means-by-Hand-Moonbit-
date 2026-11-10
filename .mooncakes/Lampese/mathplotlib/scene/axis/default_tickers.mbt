///|
// Each installed ticker slot has its own geometry/formatting role.
priv enum AxisTickerKind {
  Numeric
  Date
  Category
} derive(Eq)

///|
// Numeric ticker state is shared independently from an Axis's geometry/context.
priv struct AxisNumericTickers {
  mut major_locator_kind : AxisTickerKind
  mut minor_locator_kind : AxisTickerKind
  mut major_formatter_kind : AxisTickerKind
  mut minor_formatter_kind : AxisTickerKind
  mut major_date_view_provider : (() -> (Double, Double) raise @core.DataError)?
  mut minor_date_view_provider : (() -> (Double, Double) raise @core.DataError)?
  mut automatic_date_locator : @date.AutoDateLocator?
  mut date_locator : @date.DateLocator?
  mut date_formatter : @date.DateFormatter?
  mut date_formatter_default : Bool
  mut minor_date_locator : @date.DateLocator?
  mut minor_date_formatter : @date.DateFormatter?
  mut date_format : String?
  mut category_locator_units : CategoryUnits?
  mut category_formatter_units : CategoryUnits?
  mut locator : @ticker.Locator?
  mut minor_locator : @ticker.MinorLocator?
  mut named_formatter : @ticker.BaseFormatter?
  mut minor_named_formatter : @ticker.BaseFormatter?
  mut formatter : @ticker.Formatter?
  mut fixed_ticks : Array[Double]?
  mut fixed_labels : Array[String]?
  mut major_locator_default : Bool
  mut minor_locator_default : Bool
  mut major_formatter_default : Bool
  mut minor_formatter_default : Bool
}

///|
fn AxisNumericTickers::new() -> AxisNumericTickers {
  {
    major_locator_kind: Numeric,
    minor_locator_kind: Numeric,
    major_formatter_kind: Numeric,
    minor_formatter_kind: Numeric,
    major_date_view_provider: None,
    minor_date_view_provider: None,
    automatic_date_locator: None,
    date_locator: None,
    date_formatter: None,
    date_formatter_default: false,
    minor_date_locator: None,
    minor_date_formatter: None,
    date_format: None,
    category_locator_units: None,
    category_formatter_units: None,
    locator: None,
    minor_locator: None,
    named_formatter: None,
    minor_named_formatter: None,
    formatter: None,
    fixed_ticks: None,
    fixed_labels: None,
    major_locator_default: true,
    minor_locator_default: true,
    major_formatter_default: true,
    minor_formatter_default: true,
  }
}

///|
// Converter metadata can outlive explicit ticker replacement.
fn Axis::numeric_tickers_active(self : Axis) -> Bool {
  self.tickers.major_locator_kind == Numeric
}

///|
fn Axis::category_for_ticks(self : Axis) -> CategoryUnits? {
  if self.tickers.major_locator_kind == Category {
    self.tickers.category_locator_units
  } else {
    None
  }
}

///|
fn Axis::category_for_labels(self : Axis) -> CategoryUnits? {
  if self.tickers.major_formatter_kind == Category {
    self.tickers.category_formatter_units
  } else {
    None
  }
}

///|
fn Axis::date_format_for_ticks(self : Axis) -> String? {
  if self.tickers.major_locator_kind == Date {
    Some(self.date_format.unwrap_or(""))
  } else {
    None
  }
}

///|
fn Axis::date_format_for_labels(self : Axis) -> String? {
  if self.tickers.major_formatter_kind == Date {
    Some(self.tickers.date_format.unwrap_or(""))
  } else {
    None
  }
}

///|
/// Share numeric ticker slots without changing geometry or object ownership.
pub fn Axis::share_numeric_tickers(self : Axis, source : Axis) -> Unit {
  self.tickers = source.tickers
}

///|
/// Inherit geometry without reinstalling tickers, as shared-axis linking does.
pub fn Axis::inherit_scale_from(self : Axis, source : Axis) -> Unit {
  self.scale = source.scale
  self.function_scale = source.function_scale
}

///|
pub fn Axis::is_default_locator(self : Axis, minor~ : Bool = false) -> Bool {
  if minor {
    self.tickers.minor_locator_default
  } else {
    self.tickers.major_locator_default
  }
}

///|
pub fn Axis::is_default_formatter(self : Axis, minor~ : Bool = false) -> Bool {
  if minor {
    self.tickers.minor_formatter_default
  } else {
    self.tickers.major_formatter_default
  }
}

///|
// Called only after the complete per-scale installation succeeds.
fn Axis::mark_scale_defaults(self : Axis) -> Unit {
  self.tickers.major_locator_default = true
  self.tickers.minor_locator_default = true
  self.tickers.major_formatter_default = true
  self.tickers.minor_formatter_default = true
}

///|
/// Query the current major locator's nonsingular range for empty data.
pub fn Axis::locator_default_limits(
  self : Axis,
) -> (Double, Double) raise @core.DataError {
  self.locator_nonsingular(-1.0 / 0.0, 1.0 / 0.0)
}

///|
fn Axis::locator_nonsingular(
  self : Axis,
  lower : Double,
  upper : Double,
) -> (Double, Double) raise @core.DataError {
  if self.tickers.major_locator_kind == Date {
    return match self.tickers.date_locator {
      Some(locator) => locator.nonsingular(lower, upper)
      None =>
        match self.tickers.automatic_date_locator {
          Some(locator) => locator.nonsingular(lower, upper)
          None => @ticker.NullLocator::new().nonsingular(lower, upper)
        }
    }
  }
  if self.tickers.major_locator_kind == Category {
    return @ticker.NullLocator::new().nonsingular(lower, upper)
  }
  match self.tickers.locator {
    Some(@ticker.Locator::NamedLogit(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedAsinh(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedSymLog(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedLog(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedMaxN(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedAuto(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedLinear(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::Index(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::NamedFixed(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::Multiple(value)) => value.nonsingular(lower, upper)
    Some(@ticker.Locator::Null(value)) => value.nonsingular(lower, upper)
    _ => @ticker.NullLocator::new().nonsingular(lower, upper)
  }
}

///|
/// Finalize a numeric view after a linear lifecycle reset.
/// The outer Scene operation controls sibling propagation and target inheritance.
pub fn Axis::set_cleared_view_limits(
  self : Axis,
  lower : Double,
  upper : Double,
  automatic~ : Bool,
) -> Unit raise @core.DataError {
  if self.scale.is_nonlinear() {
    raise @core.DataError::InvalidTicks(
      message="clear view finalization requires linear geometry",
    )
  }
  if !@core.limits(lower, upper).is_finite() {
    raise @core.DataError::NonFiniteLimit(axis="axis")
  }
  let reversed = lower > upper
  let (first, last) = self.locator_nonsingular(lower, upper)
  // Source Axis.limit_range_for_scale reads own minpos even for LinearScale.
  let (first, last) = self.scale.limit_range_for_scale(
    first,
    last,
    self.get_minpos(),
  )
  let low = Double::min(first, last)
  let high = Double::max(first, last)
  let view = if reversed {
    @core.limits(high, low)
  } else {
    @core.limits(low, high)
  }
  if automatic {
    self.limits = None
    self.auto_view = Some(view)
  } else {
    self.limits = Some(view)
    self.auto_view = None
  }
  self.inverted = reversed
  self.stored_view = view
  self.autoscale_enabled = automatic
  self.autoscale_pending = false
  if self.tick_layout_view is Some(_) {
    self.tick_layout_view = Some((view.lower(), view.upper()))
  }
}

///|
// Converter axisinfo never overwrites a manually selected slot.
fn Axis::install_date_unit_defaults(
  self : Axis,
  info : @date.DateAxisInfo,
) -> Unit {
  // Keep the convenience snapshot available even with an explicit numeric slot.
  if self.tickers.automatic_date_locator is None {
    self.tickers.automatic_date_locator = Some(
      self.make_default_date_locator(info),
    )
  }
  if self.tickers.major_locator_default {
    self.tickers.major_locator_kind = Date
    self.tickers.locator = None
    self.tickers.fixed_ticks = None
    self.tickers.date_locator = None
    self.tickers.automatic_date_locator = Some(
      self.make_default_date_locator(info),
    )
    self.bind_locator_data()
    self.tickers.major_locator_default = true
  }
  if self.tickers.major_formatter_default {
    self.tickers.major_formatter_kind = Date
    self.tickers.named_formatter = None
    self.tickers.formatter = None
    self.tickers.fixed_labels = None
    self.tickers.date_format = Some("")
    self.tickers.date_formatter = Some(info.major_formatter())
    self.tickers.date_formatter_default = true
    self.tickers.major_formatter_default = true
  }
  if self.label_default {
    self.label = Some(info.label())
  }
}

///|
fn Axis::install_category_unit_defaults(
  self : Axis,
  units : CategoryUnits,
) -> Unit {
  if self.tickers.major_locator_default {
    self.tickers.major_locator_kind = Category
    self.tickers.locator = None
    self.tickers.fixed_ticks = None
    self.tickers.category_locator_units = Some(units)
    self.tickers.major_locator_default = true
  }
  if self.tickers.major_formatter_default {
    self.tickers.major_formatter_kind = Category
    self.tickers.named_formatter = None
    self.tickers.formatter = None
    self.tickers.fixed_labels = None
    self.tickers.category_formatter_units = Some(units)
    self.tickers.major_formatter_default = true
  }
}
