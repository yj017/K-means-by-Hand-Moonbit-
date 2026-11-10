///|
/// Parsed UTC ISO origin; seconds remain absolute, with a separate microsecond.
pub struct Stamp {
  source : String
  seconds : Int64
  microsecond : Int32
}

///|
fn digits(chars : Array[Char], start : Int32, count : Int32) -> Int32? {
  if start < 0 || start + count > chars.length() {
    return None
  }
  let mut value = 0
  for index in start..<(start + count) {
    let digit = chars[index].to_int() - 48
    if digit < 0 || digit > 9 {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
/// Parse the project's deterministic UTC ISO epoch syntax, through microseconds.
pub fn parse(value : String) -> Result[Stamp, String] {
  let chars = value.to_array()
  let length = chars.length()
  if length == 0 {
    return Err("epoch must be a UTC ISO date")
  }
  let negative = chars[0] == '-'
  let start = if negative || chars[0] == '+' { 1 } else { 0 }
  let mut index = start
  let mut year = 0L
  while index < length && chars[index] >= '0' && chars[index] <= '9' {
    year = year * 10L + Int64::from_int(chars[index].to_int() - 48)
    if year > 2147483648L {
      return Err("epoch year exceeds signed Int32 range")
    }
    index += 1
  }
  if index - start < 4 {
    return Err("epoch year needs at least four digits")
  }
  if negative {
    year = -year
  }
  if year > 2147483647L {
    return Err("epoch year exceeds signed Int32 range")
  }
  let mut month = 1
  let mut day = 1
  let mut has_day = false
  if index < length && chars[index] == '-' {
    month = match digits(chars, index + 1, 2) {
      Some(value) => value
      None => return Err("invalid epoch month")
    }
    index += 3
    if index < length && chars[index] == '-' {
      day = match digits(chars, index + 1, 2) {
        Some(value) => value
        None => return Err("invalid epoch day")
      }
      index += 3
      has_day = true
    }
  }
  if !@posix.is_valid_date(year.to_int(), month, day) {
    return Err("invalid epoch calendar date")
  }
  let mut hour = 0
  let mut minute = 0
  let mut second = 0
  let mut microsecond = 0
  if index < length {
    if !has_day || (chars[index] != 'T' && chars[index] != ' ') {
      return Err("epoch must not contain a timezone or trailing text")
    }
    index += 1
    hour = match digits(chars, index, 2) {
      Some(value) => value
      None => return Err("invalid epoch hour")
    }
    index += 2
    if index < length && chars[index] == ':' {
      minute = match digits(chars, index + 1, 2) {
        Some(value) => value
        None => return Err("invalid epoch minute")
      }
      index += 3
      if index < length && chars[index] == ':' {
        second = match digits(chars, index + 1, 2) {
          Some(value) => value
          None => return Err("invalid epoch second")
        }
        index += 3
        if index < length && chars[index] == '.' {
          index += 1
          let mut count = 0
          while index < length && chars[index] >= '0' && chars[index] <= '9' {
            if count >= 6 {
              return Err("epoch precision must not be finer than microseconds")
            }
            microsecond = microsecond * 10 + chars[index].to_int() - 48
            count += 1
            index += 1
          }
          if count == 0 {
            return Err("empty epoch fraction")
          }
          for _ in count..<6 {
            microsecond *= 10
          }
        }
      }
    }
  }
  if index != length || !@posix.is_valid_civil_time(hour, minute, second) {
    return Err("invalid UTC epoch time")
  }
  Ok({
    source: value,
    seconds: @posix.days_from_civil(year.to_int(), month, day) * 86400L +
    Int64::from_int(hour * 3600 + minute * 60 + second),
    microsecond,
  })
}
