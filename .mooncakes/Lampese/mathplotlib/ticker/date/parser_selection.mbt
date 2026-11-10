///|
// Parse the default dateutil grammar into optional fields. Default filling and
// runtime timezone construction are deliberately separate from token selection.
fn parser_select(
  text : String,
  reference_year : Int32,
) -> ParserFields raise DateError {
  let tokens = parser_lex(text)
  let fields = parser_fields()
  let ymd = parser_ymd()
  let count = tokens.length()
  let mut index = 0
  while index < count {
    let token = tokens[index]
    if parser_number(token) is Some(_) {
      index = parser_numeric_token(tokens, index, ymd, fields)
    } else if parser_weekday(token) is Some(day) {
      fields.weekday = Some(day)
    } else if parser_month(token) is Some(month) {
      ymd.append_number(month, label=M)
      if index + 1 < count {
        if ["-", "/"].contains(tokens[index + 1]) {
          let separator = tokens[index + 1]
          ymd.append_text(parser_token(tokens, index + 2))
          if index + 3 < count && tokens[index + 3] == separator {
            ymd.append_text(parser_token(tokens, index + 4))
            index += 2
          }
          index += 2
        } else if index + 4 < count &&
          tokens[index + 1] == " " &&
          tokens[index + 3] == " " &&
          tokens[index + 2].to_lower() == "of" {
          let raw = tokens[index + 4]
          if !raw.to_array().is_empty() &&
            raw.to_array().iter().all(parser_is_digit) {
            let year = parser_convert_year(
              parser_integer(raw),
              false,
              reference_year,
            )
            ymd.append_text(year.to_string(), label=Y)
          }
          index += 4
        }
      }
    } else if parser_ampm(token) is Some(ampm) {
      let hour = fields.hour.unwrap_or_else(() => {
        raise DateError::InvalidDate(message="AM/PM requires an hour")
      })
      if hour < 0 || hour > 12 {
        raise DateError::InvalidDate(message="invalid 12-hour clock hour")
      }
      fields.hour = Some(parser_adjust_ampm(hour, ampm))
      fields.ampm = Some(ampm)
    } else if fields.could_be_tzname(token) {
      fields.tzname = Some(token)
      fields.tzoffset = if ["utc", "gmt", "z"].contains(token) {
        Some(0)
      } else {
        None
      }
      if index + 1 < count && ["+", "-"].contains(tokens[index + 1]) {
        tokens[index + 1] = if tokens[index + 1] == "+" { "-" } else { "+" }
        fields.tzoffset = None
        if parser_utc(token) {
          fields.tzname = None
        }
      }
    } else if fields.hour is Some(_) && ["+", "-"].contains(token) {
      let sign = if token == "+" { 1 } else { -1 }
      let raw = parser_token(tokens, index + 1)
      let length = raw.to_array().length()
      let (hour, minute) = if length == 4 {
        (
          parser_integer(parser_slice(raw, 0, 2)),
          parser_integer(parser_slice(raw, 2, 4)),
        )
      } else if index + 2 < count && tokens[index + 2] == ":" {
        let minute = parser_integer(parser_token(tokens, index + 3))
        index += 2
        (parser_integer(raw), minute)
      } else if length <= 2 {
        (parser_integer(raw), 0)
      } else {
        raise DateError::InvalidDate(message="invalid numeric timezone")
      }
      let offset = Int64::from_int(hour) * 3600L + Int64::from_int(minute) * 60L
      if offset > 2147483647L {
        raise DateError::InvalidDate(message="timezone offset is out of range")
      }
      fields.tzoffset = Some(sign * offset.to_int())
      if index + 5 < count &&
        parser_jump(tokens[index + 2]) &&
        tokens[index + 3] == "(" &&
        tokens[index + 5] == ")" &&
        tokens[index + 4].to_array().length() >= 3 &&
        fields.could_be_tzname(tokens[index + 4], ignore_offset=true) {
        fields.tzname = Some(tokens[index + 4])
        index += 4
      }
      index += 1
    } else if !parser_jump(token) {
      raise DateError::InvalidDate(message="unknown date string token")
    }
    index += 1
  }
  let (year, month, day) = ymd.resolve()
  fields.century = ymd.century
  fields.year = year.map(year => {
    parser_convert_year(year, fields.century, reference_year)
  })
  fields.month = month
  fields.day = day
  if (
      fields.tzoffset == Some(0) &&
      (fields.tzname is None || fields.tzname == Some(""))
    ) ||
    fields.tzname == Some("Z") ||
    fields.tzname == Some("z") {
    fields.tzname = Some("UTC")
    fields.tzoffset = Some(0)
  } else if fields.tzoffset != Some(0) &&
    fields.tzname is Some(name) &&
    parser_utc(name) {
    fields.tzoffset = Some(0)
  }
  fields
}
