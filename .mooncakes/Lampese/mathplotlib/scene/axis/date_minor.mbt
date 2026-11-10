///|
/// Set a calendar minor locator, preserving the independent major formatter.
pub fn Axis::set_minor_date_locator(
  self : Axis,
  locator : @date.DateLocator,
) -> Unit {
  self.tickers.minor_locator_kind = Date
  self.tickers.minor_locator_default = false
  self.tickers.minor_date_locator = Some(
    match self.date_timezone {
      Some(zone) if self.date_timezone_override => locator.with_timezone(zone)
      _ => locator.copy()
    },
  )
  self.tickers.minor_locator = None
  self.bind_locator_data(minor=true)
}

///|
pub fn Axis::minor_date_locator(self : Axis) -> @date.DateLocator? {
  if self.tickers.minor_locator_kind == Date {
    self.tickers.minor_date_locator.map(value => value.copy())
  } else {
    None
  }
}

///|
/// Install a copied formatter for minor dates. Its initial locator is replaced
/// by the actual minor unit whenever labels are requested.
pub fn Axis::set_minor_date_formatter(
  self : Axis,
  formatter : @date.DateFormatter,
) -> Unit {
  self.tickers.minor_formatter_kind = Date
  self.tickers.minor_formatter_default = false
  self.tickers.minor_date_formatter = Some(formatter.copy())
  self.tickers.minor_named_formatter = None
}

///|
pub fn Axis::minor_date_formatter(self : Axis) -> @date.DateFormatter? {
  if self.tickers.minor_formatter_kind != Date {
    return None
  }
  self.tickers.minor_date_formatter.map(formatter => {
    formatter.with_locator_unit(self.date_formatter_unit([], None, true))
  })
}

///|
pub fn Axis::clear_minor_date_formatter(self : Axis) -> Unit {
  self.tickers.minor_date_formatter = None
  self.tickers.minor_formatter_kind = Numeric
  self.tickers.minor_formatter_default = false
}

///|
/// Control removal of minor locations close to major ticks. The default
/// tolerance is 1e-5 of the date view span, matching upstream linear date axes.
pub fn Axis::set_minor_overlap_removal(self : Axis, enabled : Bool) -> Unit {
  self.remove_minor_overlap = enabled
}

///|
pub fn Axis::minor_overlap_removal(self : Axis) -> Bool {
  self.remove_minor_overlap
}

///|
/// Format minor dates for a viewport. Without an explicit minor formatter,
/// labels remain empty, matching the default NullFormatter behavior.
pub fn Axis::minor_tick_labels(
  self : Axis,
  values : Array[Double],
  view? : @core.Limits,
) -> Array[String] {
  if self.tickers.minor_formatter_kind == Numeric &&
    self.tickers.minor_named_formatter is Some(formatter) {
    return formatter.format_ticks(values) catch { _ => [] }
  }
  let formatter = if self.tickers.minor_formatter_kind == Date {
    self.tickers.minor_date_formatter
  } else {
    None
  }
  match formatter {
    None => Array::make(values.length(), "")
    Some(formatter) => {
      let effective_view = match view {
        Some(_) => view
        None => self.current_view_limits()
      }
      let inverted = effective_view
        .map(limits => limits.lower() > limits.upper())
        .unwrap_or(self.inverted)
      let reversed = values.length() > 1 &&
        values[0] > values[values.length() - 1]
      let ticks = if reversed { values.rev() } else { values }
      let labels = formatter
        .with_locator_unit(
          self.date_formatter_unit(values, effective_view, true),
        )
        .format_values(ticks, inverted~)
      if reversed {
        labels.rev()
      } else {
        labels
      }
    }
  }
}

///|
fn Axis::filter_date_minor_ticks(
  self : Axis,
  ticks : Array[Double],
  major : Array[Double],
  limits : @core.Limits,
) -> Array[Double] {
  if !self.remove_minor_overlap {
    return ticks
  }
  let tolerance = Double::abs(limits.upper() - limits.lower()) * 1.0e-5
  ticks.filter(value => {
    !major.any(other => Double::abs(value - other) <= tolerance)
  })
}
