///|
/// Bind the live optional linthresh attribute of the axis's actual transform.
pub fn FormatterAxisBinding::bind_transform_linthresh(
  self : FormatterAxisBinding,
  provider : () -> ScalarNumber? raise @core.DataError,
) -> Unit {
  self.transform_linthresh_provider = Some(provider)
}

///|
/// Remove transform metadata without changing the view or pixel providers.
pub fn FormatterAxisBinding::clear_transform_linthresh(
  self : FormatterAxisBinding,
) -> Unit {
  self.transform_linthresh_provider = None
}

///|
/// Probe only the transform attribute; callers own any AttributeError fallback.
pub fn FormatterAxisBinding::transform_linthresh(
  self : FormatterAxisBinding,
) -> ScalarNumber? raise @core.DataError {
  match self.transform_linthresh_provider {
    Some(provider) => provider()
    None => None
  }
}
