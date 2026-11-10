///|
priv enum DateFormatMode {
  Fixed
  Concise(ConciseSettings)
  Auto(AutoSettings)
}

///|
fn DateFormatter::concise_settings(self : DateFormatter) -> ConciseSettings {
  match self.mode {
    Concise(settings) => settings
    _ => abort("concise formatter invariant")
  }
}

///|
/// Bind an automatic formatter to the actual locator's base unit. Scalar and
/// concise formatters retain their configuration. Used by axis adapters.
pub fn DateFormatter::with_locator_unit(
  self : DateFormatter,
  unit : Double,
) -> DateFormatter {
  match self.mode {
    Auto(settings) =>
      {
        ..self.copy(),
        mode: Auto({ scaled: settings.scaled.copy(), unit, locator: None, }),
      }
    _ => self.copy()
  }
}

///|
fn DateFormatter::auto_value(
  self : DateFormatter,
  value : Double,
  pos : Int32?,
) -> String raise DateError {
  match self.auto_settings().selected(self.format) {
    Text(format) => {
      let text = format_date(self.converted_date(value), format)
      if self.usetex {
        wrap_date_in_tex(text)
      } else {
        text
      }
    }
    Func(function) => function(value, pos)
    ValuesFunc(_) | DatesFunc(_) =>
      raise DateError::InvalidFormat(
        message="scalar date input requires Text or Func scale entry",
      )
  }
}
