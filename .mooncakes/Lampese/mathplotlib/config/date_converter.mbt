///|
/// Select the default date formatter for subsequently enabled date axes.
pub fn date_converter() -> String {
  current.val.date_converter
}

///|
/// Accept the upstream "auto" and "concise" converter names.
pub fn set_date_converter(value : String) -> Unit raise @core.DataError {
  if value != "auto" && value != "concise" {
    raise @core.DataError::InvalidTicks(
      message="date converter must be auto or concise",
    )
  }
  current.val.date_converter = value
}

///|
pub fn RcParams::date_converter(self : RcParams) -> String {
  self.date_converter
}
