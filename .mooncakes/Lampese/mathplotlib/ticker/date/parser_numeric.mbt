///|
fn parser_slice(
  text : String,
  first : Int32,
  last : Int32,
) -> String raise DateError {
  let chars = text.to_array()
  if first < 0 || first > last || last > chars.length() {
    raise DateError::InvalidDate(message="incomplete numeric date token")
  }
  String::from_array(chars[first:last])
}

///|
fn parser_token(
  tokens : Array[String],
  index : Int32,
) -> String raise DateError {
  if index < 0 || index >= tokens.length() {
    raise DateError::InvalidDate(message="incomplete date string")
  }
  tokens[index]
}

///|
fn parser_hms_index(tokens : Array[String], index : Int32) -> Int32? {
  let count = tokens.length()
  if index + 1 < count && parser_hms(tokens[index + 1]) is Some(_) {
    Some(index + 1)
  } else if index + 2 < count &&
    tokens[index + 1] == " " &&
    parser_hms(tokens[index + 2]) is Some(_) {
    Some(index + 2)
  } else if index > 0 && parser_hms(tokens[index - 1]) is Some(_) {
    Some(index - 1)
  } else if index > 1 &&
    index == count - 1 &&
    tokens[index - 1] == " " &&
    parser_hms(tokens[index - 2]) is Some(_) {
    Some(index - 2)
  } else {
    None
  }
}

///|
fn ParserFields::assign_hms(
  self : ParserFields,
  text : String,
  hms : Int32,
) -> Unit raise DateError {
  let number = parser_number(text).unwrap_or_else(() => {
    raise DateError::InvalidDate(message="invalid time token")
  })
  match hms {
    0 => {
      self.hour = Some(number.integer())
      if number.fractional() {
        self.minute = Some(parser_fraction_times60(number.fraction))
      }
    }
    1 => {
      let (minute, second) = parser_min_sec(number)
      self.minute = Some(minute)
      self.second = second
    }
    2 => {
      let (second, microsecond) = parser_seconds(text)
      self.second = Some(second)
      self.microsecond = Some(microsecond)
    }
    _ => ()
  }
}

///|
fn parser_numeric_token(
  tokens : Array[String],
  position : Int32,
  ymd : ParserYmd,
  fields : ParserFields,
) -> Int32 raise DateError {
  let text = tokens[position]
  let number = parser_number(text).unwrap_or_else(() => {
    raise DateError::InvalidDate(message="invalid numeric date token")
  })
  let length = text.to_array().length()
  let count = tokens.length()
  let mut index = position
  if ymd.values.length() == 3 &&
    (length == 2 || length == 4) &&
    fields.hour is None &&
    (
      index + 1 >= count ||
      (tokens[index + 1] != ":" && parser_hms(tokens[index + 1]) is None)
    ) {
    fields.hour = Some(parser_integer(parser_slice(text, 0, 2)))
    if length == 4 {
      fields.minute = Some(parser_integer(parser_slice(text, 2, 4)))
    }
  } else if length == 6 ||
    (length > 6 && parser_slice(text, 0, 7).to_array()[6] == '.') {
    if ymd.values.is_empty() && !text.contains(".") {
      ymd.append_text(parser_slice(text, 0, 2))
      ymd.append_text(parser_slice(text, 2, 4))
      ymd.append_text(parser_slice(text, 4, length))
    } else {
      fields.hour = Some(parser_integer(parser_slice(text, 0, 2)))
      fields.minute = Some(parser_integer(parser_slice(text, 2, 4)))
      let (second, microsecond) = parser_seconds(parser_slice(text, 4, length))
      fields.second = Some(second)
      fields.microsecond = Some(microsecond)
    }
  } else if length == 8 || length == 12 || length == 14 {
    ymd.append_text(parser_slice(text, 0, 4), label=Y)
    ymd.append_text(parser_slice(text, 4, 6))
    ymd.append_text(parser_slice(text, 6, 8))
    if length > 8 {
      fields.hour = Some(parser_integer(parser_slice(text, 8, 10)))
      fields.minute = Some(parser_integer(parser_slice(text, 10, 12)))
      if length > 12 {
        fields.second = Some(parser_integer(parser_slice(text, 12, length)))
      }
    }
  } else if parser_hms_index(tokens, index) is Some(hms_index) {
    let hms = parser_hms(tokens[hms_index]).unwrap() +
      (if hms_index < index { 1 } else { 0 })
    if hms_index > index {
      index = hms_index
    }
    fields.assign_hms(text, hms)
  } else if index + 2 < count && tokens[index + 1] == ":" {
    fields.hour = Some(number.integer())
    let minute = parser_number(tokens[index + 2]).unwrap_or_else(() => {
      raise DateError::InvalidDate(message="invalid minute token")
    })
    let (minute, second) = parser_min_sec(minute)
    fields.minute = Some(minute)
    fields.second = second
    if index + 4 < count && tokens[index + 3] == ":" {
      let (second, microsecond) = parser_seconds(tokens[index + 4])
      fields.second = Some(second)
      fields.microsecond = Some(microsecond)
      index += 2
    }
    index += 2
  } else if index + 1 < count && ["-", "/", "."].contains(tokens[index + 1]) {
    let separator = tokens[index + 1]
    ymd.append_text(text)
    if index + 2 < count && !parser_jump(tokens[index + 2]) {
      let next = tokens[index + 2]
      if !next.to_array().is_empty() &&
        next.to_array().iter().all(parser_is_digit) {
        ymd.append_text(next)
      } else if parser_month(next) is Some(month) {
        ymd.append_number(month, label=M)
      } else {
        raise DateError::InvalidDate(message="invalid month token")
      }
      if index + 3 < count && tokens[index + 3] == separator {
        let last = parser_token(tokens, index + 4)
        if parser_month(last) is Some(month) {
          ymd.append_number(month, label=M)
        } else {
          ymd.append_text(last)
        }
        index += 2
      }
      index += 1
    }
    index += 1
  } else if index + 1 >= count || parser_jump(tokens[index + 1]) {
    if index + 2 < count && parser_ampm(tokens[index + 2]) is Some(ampm) {
      fields.hour = Some(parser_adjust_ampm(number.integer(), ampm))
      index += 1
    } else {
      ymd.append_numeric(number)
    }
    index += 1
  } else if parser_ampm(tokens[index + 1]) is Some(ampm) &&
    number.integer() < 24 {
    fields.hour = Some(parser_adjust_ampm(number.integer(), ampm))
    index += 1
  } else if ymd.could_be_numeric_day(number) {
    ymd.append_numeric(number)
  } else {
    raise DateError::InvalidDate(message="unrecognized numeric date token")
  }
  index
}
