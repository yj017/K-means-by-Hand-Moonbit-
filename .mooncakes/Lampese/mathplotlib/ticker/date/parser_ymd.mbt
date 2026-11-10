///|
// D is part of the original general YMD bookkeeping. The default grammar
// currently labels only Y/M; the independent original-class tests cover D.
#warnings("-unused_constructor")
priv enum ParserDateLabel {
  Y
  M
  D
}

///|
priv struct ParserYmd {
  values : Array[Int32]
  mut century : Bool
  mut year : Int32?
  mut month : Int32?
  mut day : Int32?
}

///|
fn parser_ymd() -> ParserYmd {
  { values: [], century: false, year: None, month: None, day: None, }
}

///|
fn ParserYmd::append_value(
  self : ParserYmd,
  value : Int32,
  label : ParserDateLabel?,
) -> Unit raise DateError {
  self.values.push(value)
  let index = self.values.length() - 1
  match label {
    Some(Y) => {
      if self.year is Some(_) {
        raise DateError::InvalidDate(message="year is already set")
      }
      self.year = Some(index)
    }
    Some(M) => {
      if self.month is Some(_) {
        raise DateError::InvalidDate(message="month is already set")
      }
      self.month = Some(index)
    }
    Some(D) => {
      if self.day is Some(_) {
        raise DateError::InvalidDate(message="day is already set")
      }
      self.day = Some(index)
    }
    None => ()
  }
}

///|
fn ParserYmd::append_text(
  self : ParserYmd,
  text : String,
  label? : ParserDateLabel,
) -> Unit raise DateError {
  let chars = text.to_array()
  let explicit_year = chars.length() > 2 && chars.iter().all(parser_is_digit)
  let label = if explicit_year {
    if label is Some(M) || label is Some(D) {
      raise DateError::InvalidDate(message="invalid explicit year label")
    }
    self.century = true
    Some(Y)
  } else {
    label
  }
  self.append_value(parser_integer(text), label)
}

///|
fn ParserYmd::append_number(
  self : ParserYmd,
  value : Int32,
  label? : ParserDateLabel,
) -> Unit raise DateError {
  let label = if value > 100 {
    if label is Some(M) || label is Some(D) {
      raise DateError::InvalidDate(message="invalid explicit year label")
    }
    self.century = true
    Some(Y)
  } else {
    label
  }
  self.append_value(value, label)
}

///|
fn ParserYmd::could_be_day(self : ParserYmd, value : Int32) -> Bool {
  if self.day is Some(_) {
    return false
  }
  match self.month {
    None => value >= 1 && value <= 31
    Some(month_index) => {
      let year = self.year.map(index => self.values[index]).unwrap_or(2000)
      value >= 1 && value <= days_in_month(year, self.values[month_index])
    }
  }
}

///|
fn ParserYmd::resolve(
  self : ParserYmd,
  yearfirst~ : Bool = false,
  dayfirst~ : Bool = false,
) -> (Int32?, Int32?, Int32?) raise DateError {
  let count = self.values.length()
  let known = (if self.year is Some(_) { 1 } else { 0 }) +
    (if self.month is Some(_) { 1 } else { 0 }) +
    (if self.day is Some(_) { 1 } else { 0 })
  if (count == known && count > 0) || (count == 3 && known == 2) {
    let mut yi = self.year
    let mut mi = self.month
    let mut di = self.day
    if count == 3 && known == 2 {
      for index in 0..<3 {
        if yi != Some(index) && mi != Some(index) && di != Some(index) {
          if yi is None {
            yi = Some(index)
          } else if mi is None {
            mi = Some(index)
          } else {
            di = Some(index)
          }
          break
        }
      }
    }
    return (
      yi.map(index => self.values[index]),
      mi.map(index => self.values[index]),
      di.map(index => self.values[index]),
    )
  }
  if count > 3 {
    raise DateError::InvalidDate(message="more than three date fields")
  }
  let mut year : Int32? = None
  let mut month : Int32? = None
  let mut day : Int32? = None
  if count == 1 || (self.month is Some(_) && count == 2) {
    let other = match self.month {
      Some(index) => {
        month = Some(self.values[index])
        self.values[if index == 0 { count - 1 } else { index - 1 }]
      }
      None => self.values[0]
    }
    if count > 1 || self.month is None {
      if other > 31 {
        year = Some(other)
      } else {
        day = Some(other)
      }
    }
  } else if count == 2 {
    if self.values[0] > 31 {
      year = Some(self.values[0])
      month = Some(self.values[1])
    } else if self.values[1] > 31 {
      month = Some(self.values[0])
      year = Some(self.values[1])
    } else if dayfirst && self.values[1] <= 12 {
      day = Some(self.values[0])
      month = Some(self.values[1])
    } else {
      month = Some(self.values[0])
      day = Some(self.values[1])
    }
  } else if count == 3 {
    let a = self.values[0]
    let b = self.values[1]
    let c = self.values[2]
    if self.month == Some(0) {
      month = Some(a)
      if b > 31 {
        year = Some(b)
        day = Some(c)
      } else {
        day = Some(b)
        year = Some(c)
      }
    } else if self.month == Some(1) {
      month = Some(b)
      if a > 31 || (yearfirst && c <= 31) {
        year = Some(a)
        day = Some(c)
      } else {
        day = Some(a)
        year = Some(c)
      }
    } else if self.month == Some(2) {
      month = Some(c)
      if b > 31 {
        day = Some(a)
        year = Some(b)
      } else {
        year = Some(a)
        day = Some(b)
      }
    } else if a > 31 ||
      self.year == Some(0) ||
      (yearfirst && b <= 12 && c <= 31) {
      year = Some(a)
      if dayfirst && c <= 12 {
        day = Some(b)
        month = Some(c)
      } else {
        month = Some(b)
        day = Some(c)
      }
    } else if a > 12 || (dayfirst && b <= 12) {
      day = Some(a)
      month = Some(b)
      year = Some(c)
    } else {
      month = Some(a)
      day = Some(b)
      year = Some(c)
    }
  }
  (year, month, day)
}
