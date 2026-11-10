///|
priv struct ParserFields {
  mut year : Int32?
  mut month : Int32?
  mut day : Int32?
  mut weekday : Int32?
  mut hour : Int32?
  mut minute : Int32?
  mut second : Int32?
  mut microsecond : Int32?
  mut tzname : String?
  mut tzoffset : Int32?
  mut ampm : Int32?
  mut century : Bool
}

///|
fn parser_fields() -> ParserFields {
  {
    year: None,
    month: None,
    day: None,
    weekday: None,
    hour: None,
    minute: None,
    second: None,
    microsecond: None,
    tzname: None,
    tzoffset: None,
    ampm: None,
    century: false,
  }
}

///|
fn parser_jump(text : String) -> Bool {
  [
    " ", ".", ",", ";", "-", "/", "'", "at", "on", "and", "ad", "m", "t", "of", "st",
    "nd", "rd", "th",
  ].contains(text.to_lower())
}

///|
fn parser_month(text : String) -> Int32? {
  let text = text.to_lower()
  if text == "sept" {
    return Some(9)
  }
  for index in 0..<12 {
    if text == month_short[index].to_lower() ||
      text == month_long[index].to_lower() {
      return Some(index + 1)
    }
  }
  None
}

///|
fn parser_weekday(text : String) -> Int32? {
  let text = text.to_lower()
  for index in 0..<7 {
    if text == weekday_short[index].to_lower() ||
      text == weekday_long[index].to_lower() {
      return Some(index)
    }
  }
  None
}

///|
fn parser_hms(text : String) -> Int32? {
  match text.to_lower() {
    "h" | "hour" | "hours" => Some(0)
    "m" | "minute" | "minutes" => Some(1)
    "s" | "second" | "seconds" => Some(2)
    _ => None
  }
}

///|
fn parser_ampm(text : String) -> Int32? {
  match text.to_lower() {
    "am" | "a" => Some(0)
    "pm" | "p" => Some(1)
    _ => None
  }
}

///|
fn parser_utc(text : String) -> Bool {
  ["utc", "gmt", "z"].contains(text.to_lower())
}

///|
fn parser_convert_year(
  year : Int32,
  century : Bool,
  reference : Int32,
) -> Int32 {
  if year >= 100 || century {
    return year
  }
  let candidate = year + reference / 100 * 100
  if candidate >= reference + 50 {
    candidate - 100
  } else if candidate < reference - 50 {
    candidate + 100
  } else {
    candidate
  }
}

///|
fn parser_adjust_ampm(hour : Int32, ampm : Int32) -> Int32 {
  if hour < 12 && ampm == 1 {
    hour + 12
  } else if hour == 12 && ampm == 0 {
    0
  } else {
    hour
  }
}

///|
fn ParserFields::could_be_tzname(
  self : ParserFields,
  token : String,
  ignore_offset~ : Bool = false,
) -> Bool {
  self.hour is Some(_) &&
  self.tzname is None &&
  (ignore_offset || self.tzoffset is None) &&
  token.to_array().length() <= 5 &&
  (
    token.to_array().iter().all(char => char >= 'A' && char <= 'Z') ||
    ["UTC", "GMT", "Z", "z"].contains(token)
  )
}
