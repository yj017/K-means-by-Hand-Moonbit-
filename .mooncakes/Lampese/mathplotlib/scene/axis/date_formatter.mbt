///|
/// Set a copied date formatter while preserving locators and fixed ticks/labels.
/// The formatter's timezone affects labels independently of the tick locator.
/// Use Axis::set_date_timezone/offset to update both labels and tick positions.
pub fn Axis::set_date_formatter(
  self : Axis,
  formatter : @date.DateFormatter,
) -> Unit {
  self.tickers.major_formatter_kind = Date
  self.tickers.major_formatter_default = false
  self.tickers.date_format = Some(formatter.format())
  self.tickers.named_formatter = None
  self.tickers.formatter = None
  self.tickers.fixed_labels = None
  self.tickers.date_formatter = Some(formatter.copy())
  self.tickers.date_formatter_default = false
}

///|
/// Return a copy of the configured date formatter, if any.
pub fn Axis::date_formatter(self : Axis) -> @date.DateFormatter? {
  if self.tickers.major_formatter_kind != Date {
    return None
  }
  self.tickers.date_formatter.map(formatter => {
    formatter.with_locator_unit(self.date_formatter_unit([], None, false))
  })
}

///|
fn Axis::sync_default_date_formatter(self : Axis) -> Unit {
  if !self.tickers.date_formatter_default || self.date_timezone_is_default {
    return
  }
  self.tickers.date_formatter = self.tickers.date_formatter.map(formatter => {
    match self.date_timezone {
      Some(timezone) => formatter.with_timezone(timezone)
      None => try! formatter.with_offset(self.date_offset_minutes)
    }
  })
}

///|
fn Axis::date_formatter_unit(
  self : Axis,
  values : Array[Double],
  view : @core.Limits?,
  minor : Bool,
) -> Double {
  let limits = match view {
    Some(_) => view
    None => self.current_view_limits()
  }
  let limits = limits.map(bounds => {
    self.date_nonsingular_bounds(bounds.lower(), bounds.upper())
  })
  let kind = if minor {
    self.tickers.minor_locator_kind
  } else {
    self.tickers.major_locator_kind
  }
  if kind != Date {
    return 1.0
  }
  let concrete = if minor {
    self.tickers.minor_date_locator
  } else {
    self.tickers.date_locator
  }
  if concrete is Some(_) {
    if concrete is Some(locator) {
      if locator.automatic_locator() is Some(auto) {
        match limits {
          Some(bounds) =>
            ignore(auto.get_locator_for_range(bounds.lower(), bounds.upper())) catch {
              _ => ()
            }
          None => ()
        }
      }
      return locator.unit_scale()
    }
  }
  if minor {
    return 1.0
  }
  if self.tickers.automatic_date_locator is Some(auto) {
    match limits {
      Some(bounds) =>
        ignore(auto.get_locator_for_range(bounds.lower(), bounds.upper())) catch {
          _ => ()
        }
      None =>
        if values.length() >= 2 {
          ignore(
            auto.get_locator_for_range(values[0], values[values.length() - 1]),
          ) catch {
            _ => ()
          }
        }
    }
    return auto.unit_scale()
  }
  1.0
}

///|
// Matplotlib's date locators supply ascending ticks even on an inverted axis.
// This port returns reversed generated ticks, so normalize just that path for
// the batch formatter and restore label order afterwards. Fixed ticks retain
// their explicit caller order, as with upstream FixedLocator.
fn Axis::date_formatter_values(
  self : Axis,
  values : Array[Double],
  view : @core.Limits?,
) -> (Array[Double], Bool, Bool) {
  let effective_view = match view {
    Some(_) => view
    None => self.limits
  }
  let inverted = match effective_view {
    Some(limits) => limits.lower() > limits.upper()
    None => self.inverted
  }
  let reversed = self.tickers.major_locator_kind == Date &&
    values.length() > 1 &&
    values[0] > values[values.length() - 1]
  (if reversed { values.rev() } else { values }, inverted, reversed)
}
