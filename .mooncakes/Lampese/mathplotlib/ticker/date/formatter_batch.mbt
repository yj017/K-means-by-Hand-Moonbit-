///|
/// Copy a date formatter without sharing mutable format arrays.
pub fn DateFormatter::copy(self : DateFormatter) -> DateFormatter {
  {
    ..self,
    mode: match self.mode {
      Fixed => Fixed
      Concise(settings) =>
        Concise({
          formats: settings.formats.copy(),
          zero_formats: settings.zero_formats.copy(),
          offset_formats: settings.offset_formats.copy(),
          show_offset: settings.show_offset,
        })
      Auto(settings) => Auto({ ..settings, scaled: settings.scaled.copy(), })
    },
  }
}

///|
/// Return a formatter selecting upstream TeX string output.
pub fn DateFormatter::with_usetex(
  self : DateFormatter,
  usetex : Bool,
) -> DateFormatter {
  { ..self.copy(), usetex, }
}

///|
fn DateFormatter::converted_date(
  self : DateFormatter,
  value : Double,
) -> DateTime raise DateError {
  match self.timezone_source {
    DefaultTimezone => return get_timezone().to_datetime(value)
    NamedTimezone(name) => return get_timezone(name~).to_datetime(value)
    Captured => ()
  }
  match self.timezone {
    Some(timezone) => timezone.to_datetime(value)
    None => from_ordinal(value, offset_minutes=self.offset_minutes)
  }
}

///|
fn DateFormatter::tick_layout(
  self : DateFormatter,
  values : Array[Double],
  inverted : Bool,
) -> (Array[String], String) raise DateError {
  match self.mode {
    Concise(settings) => concise_layout(self, settings, values, inverted)
    Fixed => (values.map(value => self.format_value(value)), "")
    Auto(_) => {
      let labels : Array[String] = []
      for index in 0..<values.length() {
        labels.push(self.auto_value(values[index], Some(index)))
      }
      (labels, "")
    }
  }
}

///|
/// Format a complete tick list using scalar or concise date rules. A failed
/// batch falls back to individual value labels and has no shared offset.
pub fn DateFormatter::format_values(
  self : DateFormatter,
  values : Array[Double],
  inverted~ : Bool = false,
) -> Array[String] {
  let (labels, _) = self.tick_layout(values, inverted) catch {
    _ => return values.map(value => self.format_value(value))
  }
  labels
}

///|
/// Return shared date text for this tick list, empty for scalar formatters.
pub fn DateFormatter::offset_label(
  self : DateFormatter,
  values : Array[Double],
  inverted~ : Bool = false,
) -> String {
  // Fixed and automatic formatters inherit an empty offset. In particular,
  // asking for it must never run an automatic formatter's user callback again.
  if !(self.mode is Concise(_)) {
    return ""
  }
  let (_, offset) = self.tick_layout(values, inverted) catch { _ => return "" }
  offset
}
