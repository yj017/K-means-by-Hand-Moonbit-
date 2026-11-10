///|
fn date_autoformatter_index(unit : String) -> Int32 raise @core.DataError {
  match unit {
    "year" => 0
    "month" => 1
    "day" => 2
    "hour" => 3
    "minute" => 4
    "second" => 5
    "microsecond" => 6
    _ =>
      raise @core.DataError::InvalidTicks(
        message="unknown date autoformatter unit: " + unit,
      )
  }
}

///|
/// Return copied defaults in year/month/day/hour/minute/second/microsecond order.
pub fn date_autoformats() -> Array[String] {
  current.val.date_autoformats.copy()
}

///|
/// Read a date.autoformatter default by its unit name, such as "minute".
pub fn date_autoformatter(unit : String) -> String raise @core.DataError {
  current.val.date_autoformats[date_autoformatter_index(unit)]
}

///|
/// Configure newly constructed automatic date formatters. Existing objects
/// retain the defaults captured when they were constructed.
pub fn set_date_autoformatter(
  unit : String,
  format : String,
) -> Unit raise @core.DataError {
  current.val.date_autoformats[date_autoformatter_index(unit)] = format
}

///|
pub fn RcParams::date_autoformats(self : RcParams) -> Array[String] {
  self.date_autoformats.copy()
}

///|
pub fn RcParams::date_autoformatter(
  self : RcParams,
  unit : String,
) -> String raise @core.DataError {
  self.date_autoformats[date_autoformatter_index(unit)]
}
