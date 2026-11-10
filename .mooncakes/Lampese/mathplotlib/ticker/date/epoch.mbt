///|
priv struct EpochState {
  mut selected : @epoch_data.Stamp?
}

///|
let epoch_state : EpochState = { selected: None, }

///|
fn selected_epoch() -> @epoch_data.Stamp {
  match epoch_state.selected {
    Some(value) => value
    None => {
      // The config setter and default validate this invariant before storage.
      let value = match @epoch_data.parse(@config.date_epoch()) {
        Ok(value) => value
        Err(_) => abort("invalid configured date epoch")
      }
      epoch_state.selected = Some(value)
      value
    }
  }
}

///|
/// Select and return the date origin. Reading this value locks the selection.
pub fn get_epoch() -> String {
  selected_epoch().source
}

///|
/// Select a UTC ISO origin before any numeric date conversion/get_epoch call.
/// Supports signed Int32 astronomical years (including 0), partial dates and
/// times through microseconds. Invalid input leaves the selection unchanged;
/// timezone suffixes and finer-than-microsecond precision are not accepted.
pub fn set_epoch(value : String) -> Unit raise DateError {
  if epoch_state.selected is Some(_) {
    raise DateError::InvalidDate(
      message="set_epoch must be called before dates are converted or epoch is read",
    )
  }
  match @epoch_data.parse(value) {
    Ok(value) => epoch_state.selected = Some(value)
    Err(message) => raise DateError::InvalidDate(message~)
  }
}

///|
fn unix_seconds_to_ordinal(seconds : Int64) -> Double {
  (seconds - selected_epoch().seconds).to_double() / 86400.0
}

///|
fn unix_microseconds_to_ordinal(microseconds : Int64) -> Double {
  let (seconds, fraction) = delta_split(microseconds, 1_000_000L)
  (
    (seconds - selected_epoch().seconds).to_double() +
    fraction.to_double() / 1_000_000.0
  ) /
  86400.0
}

///|
// Decode a numeric day before timezone conversion or distant-date correction.
// Internal generated calendar coordinates use the forward (whole-second) origin.
fn ordinal_to_unix_microseconds(
  value : Double,
  generated~ : Bool = false,
) -> Int64 raise DateError {
  let epoch = selected_epoch()
  if value.is_nan() || value.is_inf() {
    raise DateError::InvalidDate(message="ordinal must be finite")
  }
  let scaled = value * 86_400_000_000.0
  if scaled <= -9.223372036854776e18 || scaled >= 9.223372036854776e18 {
    raise DateError::InvalidDate(
      message="relative ordinal microseconds exceed Int64 range",
    )
  }
  let (seconds, fraction) = delta_split(round_even_to_int64(scaled), 1_000_000L)
  let subsecond = fraction +
    (if generated { 0L } else { Int64::from_int(epoch.microsecond) })
  let absolute_seconds = epoch.seconds + seconds + subsecond / 1_000_000L
  if absolute_seconds < -62_135_596_800L || absolute_seconds >= 253_402_300_800L {
    raise DateError::InvalidDate(message="ordinal is outside years 1..9999")
  }
  absolute_seconds * 1_000_000L + subsecond % 1_000_000L
}

///|
fn supported_ordinal(value : Double) -> Bool {
  try {
    ignore(ordinal_to_unix_microseconds(value))
    true
  } catch {
    _ => false
  }
}

///|
fn forward_calendar_date(value : Double) -> DateTime raise DateError {
  decoded_ordinal(value, 0, true)
}

///|
fn DateTimeZone::footer_reached(self : DateTimeZone, value : Double) -> Bool {
  match self.footer_start_seconds {
    None => true
    Some(seconds) =>
      // TZif permits raw Int64 endpoints far beyond any Gregorian date.
      if seconds < -62_135_596_800L {
        true
      } else if seconds >= 253_402_300_800L {
        false
      } else {
        value >= unix_seconds_to_ordinal(seconds)
      }
  }
}
