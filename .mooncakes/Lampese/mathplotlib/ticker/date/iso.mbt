///|
fn decimal_digits(chars : Array[Char], start : Int32, length : Int32) -> Int32? {
  if start < 0 || length <= 0 || start + length > chars.length() {
    return None
  }
  let mut result = 0
  for index in start..<(start + length) {
    let digit = match chars[index] {
      '0' => 0
      '1' => 1
      '2' => 2
      '3' => 3
      '4' => 4
      '5' => 5
      '6' => 6
      '7' => 7
      '8' => 8
      '9' => 9
      _ => return None
    }
    result = result * 10 + digit
  }
  Some(result)
}

///|
fn timezone_start(chars : Array[Char]) -> Int32? {
  let mut index = 10
  while index < chars.length() {
    match chars[index] {
      'Z' | 'z' | '+' | '-' => return Some(index)
      _ => index += 1
    }
  }
  None
}

///|
fn parse_timezone_offset(
  chars : Array[Char],
  start : Int32,
) -> Int32 raise DateError {
  if start >= chars.length() {
    return 0
  }
  if (chars[start] == 'Z' || chars[start] == 'z') && start + 1 == chars.length() {
    return 0
  }
  let sign = match chars[start] {
    '+' => 1
    '-' => -1
    _ =>
      raise DateError::InvalidFormat(message="expected UTC offset or Z suffix")
  }
  let digits = chars.length() - start - 1
  let hour = decimal_digits(chars, start + 1, 2).unwrap_or(-1)
  let (minute, second) = match digits {
    2 => (0, 0)
    4 => (decimal_digits(chars, start + 3, 2).unwrap_or(-1), 0)
    5 if chars[start + 3] == ':' =>
      (decimal_digits(chars, start + 4, 2).unwrap_or(-1), 0)
    6 =>
      (
        decimal_digits(chars, start + 3, 2).unwrap_or(-1),
        decimal_digits(chars, start + 5, 2).unwrap_or(-1),
      )
    8 if chars[start + 3] == ':' && chars[start + 6] == ':' =>
      (
        decimal_digits(chars, start + 4, 2).unwrap_or(-1),
        decimal_digits(chars, start + 7, 2).unwrap_or(-1),
      )
    _ =>
      raise DateError::InvalidFormat(
        message="UTC offset must be +HH, +HHMM[SS], or +HH:MM[:SS]",
      )
  }
  if hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59 {
    raise DateError::InvalidFormat(message="UTC offset is outside its range")
  }
  sign * (hour * 3600 + minute * 60 + second)
}

///|
/// Parse `YYYY-MM-DD` with an optional `T`/space-separated
/// `HH:MM[:SS[.ffffff]]` and fixed UTC offset (`Z`, `+HH`, `+HHMM[SS]`, or
/// `+HH:MM[:SS]`). Fractional seconds contain one to six digits and are padded on
/// the right.
pub fn parse_iso(value : String) -> DateTime raise DateError {
  let chars = value.to_array()
  if chars.length() < 10 {
    raise DateError::InvalidFormat(message="expected YYYY-MM-DD")
  }
  if chars[4] != '-' || chars[7] != '-' {
    raise DateError::InvalidFormat(message="expected YYYY-MM-DD")
  }
  let year = match decimal_digits(chars, 0, 4) {
    Some(value) => value
    None => raise DateError::InvalidFormat(message="invalid year")
  }
  let month = match decimal_digits(chars, 5, 2) {
    Some(value) => value
    None => raise DateError::InvalidFormat(message="invalid month")
  }
  let day = match decimal_digits(chars, 8, 2) {
    Some(value) => value
    None => raise DateError::InvalidFormat(message="invalid day")
  }
  let timezone_index = timezone_start(chars)
  let base_end = match timezone_index {
    Some(index) => index
    None => chars.length()
  }
  let offset_seconds = match timezone_index {
    Some(index) => parse_timezone_offset(chars, index)
    None => 0
  }
  if base_end == 10 && chars.length() == 10 {
    return datetime(year, month, day)
  }
  if base_end == 10 {
    raise DateError::InvalidFormat(message="expected time before UTC offset")
  }
  if chars[10] != 'T' && chars[10] != ' ' {
    raise DateError::InvalidFormat(message="expected T or space before time")
  }
  if base_end < 16 || chars[13] != ':' {
    raise DateError::InvalidFormat(message="expected HH:MM")
  }
  let hour = match decimal_digits(chars, 11, 2) {
    Some(value) => value
    None => raise DateError::InvalidFormat(message="invalid hour")
  }
  let minute = match decimal_digits(chars, 14, 2) {
    Some(value) => value
    None => raise DateError::InvalidFormat(message="invalid minute")
  }
  let second = if base_end == 16 {
    0
  } else {
    if base_end < 19 || chars[16] != ':' {
      raise DateError::InvalidFormat(message="expected optional :SS")
    }
    match decimal_digits(chars, 17, 2) {
      Some(value) => value
      None => raise DateError::InvalidFormat(message="invalid second")
    }
  }
  let microsecond = if base_end == 16 || base_end == 19 {
    0
  } else {
    if base_end < 21 || chars[19] != '.' {
      raise DateError::InvalidFormat(
        message="expected optional fractional seconds",
      )
    }
    let length = base_end - 20
    if length < 1 || length > 6 {
      raise DateError::InvalidFormat(
        message="fractional seconds must contain 1..6 digits",
      )
    }
    let value = match decimal_digits(chars, 20, length) {
      Some(value) => value
      None =>
        raise DateError::InvalidFormat(message="invalid fractional seconds")
    }
    let mut scaled = value
    for _ in length..<6 {
      scaled *= 10
    }
    scaled
  }
  datetime(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    microsecond~,
    offset_seconds~,
  )
}
