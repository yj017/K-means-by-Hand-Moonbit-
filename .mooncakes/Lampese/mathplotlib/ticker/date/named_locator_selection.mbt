///|
// Constructor defaults differ from an explicit None for Month's monthday and
// Weekday's weekday. Keep that concrete distinction before creating a wrapper.
priv enum NamedLocatorSelection {
  Every(Int32, Int32)
  At(Int32)
  AnyDate
}

///|
fn named_locator_null(
  names : Array[String],
  allowed : Array[String],
) -> Unit raise DateError {
  for name in names {
    if !allowed.contains(name) {
      raise DateError::InvalidDate(
        message="unsupported null locator keyword '\{name}'",
      )
    }
  }
}

///|
fn named_locator_selection(
  values : Array[Int32]?,
  scalar : Int32?,
  default_value : NamedLocatorSelection,
  reset : Bool,
) -> (Array[Int32]?, Int32?) raise DateError {
  if values is Some(_) && scalar is Some(_) {
    raise DateError::InvalidDate(
      message="use array or scalar locator keyword, not both",
    )
  }
  if !reset && (values is Some(_) || scalar is Some(_)) {
    return (values, scalar)
  }
  match default_value {
    Every(start, length) =>
      (Some(Array::makei(length, index => start + index)), None)
    At(value) => (None, Some(value))
    AnyDate => (None, None)
  }
}

///|
fn named_locator_array(
  values : Array[Int32]?,
  scalar : Int32?,
) -> Array[Int32]? {
  match scalar {
    Some(value) => Some([value])
    None => values
  }
}
