///|
priv struct ParserNumber {
  whole : String
  fraction : String
}

///|
fn parser_number(text : String) -> ParserNumber? raise DateError {
  if ["nan", "inf", "infinity"].contains(text.to_lower()) {
    raise DateError::InvalidDate(message="nonfinite numeric date token")
  }
  let chars = text.to_array()
  if chars.is_empty() {
    return None
  }
  let mut seen_dot = false
  let whole = StringBuilder()
  let fraction = StringBuilder()
  let mut digits = 0
  for char in chars {
    if char == '.' && !seen_dot {
      seen_dot = true
      continue
    }
    let digit = match parser_decimal_digit(char) {
      Some(value) => value
      None => return None
    }
    digits += 1
    if seen_dot {
      fraction.write_string(digit.to_string())
    } else {
      whole.write_string(digit.to_string())
    }
  }
  if digits == 0 {
    return None
  }
  let integer = whole.to_string()
  Some({
    whole: if integer == "" {
      "0"
    } else {
      integer
    },
    fraction: fraction.to_string(),
  })
}

///|
fn ParserNumber::integer(self : ParserNumber) -> Int32 raise DateError {
  parser_integer(self.whole)
}

///|
fn ParserNumber::fractional(self : ParserNumber) -> Bool {
  self.fraction.to_array().iter().any(char => char != '0')
}

///|
// Decimal arithmetic here is limited to the default parser's positive
// fractional hours/minutes. Match Decimal's 28 significant digits and
// round-half-even at modulo and multiplication, without binary64 rounding.
fn parser_round_decimal(
  digits : Array[Int32],
  exponent : Int32,
) -> (Array[Int32], Int32) {
  let mut first = 0
  while first < digits.length() && digits[first] == 0 {
    first += 1
  }
  let value = digits[first:].to_owned()
  if value.length() <= 28 {
    return (value, exponent)
  }
  let removed = value.length() - 28
  let result = value[:28].to_owned()
  let next = value[28]
  let round_up = next > 5 ||
    (
      next == 5 &&
      (result[27] % 2 == 1 || value[29:].iter().any(digit => digit != 0))
    )
  if round_up {
    let mut index = result.length() - 1
    while index >= 0 && result[index] == 9 {
      result[index] = 0
      index -= 1
    }
    if index < 0 {
      result.insert(0, 1)
    } else {
      result[index] += 1
    }
  }
  (result, exponent + removed)
}

///|
fn parser_fraction_times60(fraction : String) -> Int32 {
  let digits = fraction.to_array().map(char => char.to_int() - 48)
  let (digits, exponent) = parser_round_decimal(digits, -digits.length())
  let product = digits.copy()
  let mut carry = 0
  for index = product.length() - 1; index >= 0; index = index - 1 {
    let value = product[index] * 60 + carry
    product[index] = value % 10
    carry = value / 10
  }
  while carry > 0 {
    product.insert(0, carry % 10)
    carry /= 10
  }
  let (product, exponent) = parser_round_decimal(product, exponent)
  let length = product.length() + exponent
  let mut result = 0
  for index in 0..<Int32::max(0, length) {
    result = result * 10 +
      (if index < product.length() { product[index] } else { 0 })
  }
  result
}

///|
fn parser_min_sec(number : ParserNumber) -> (Int32, Int32?) raise DateError {
  (
    number.integer(),
    if number.fractional() {
      Some(parser_fraction_times60(number.fraction))
    } else {
      None
    },
  )
}

///|
fn parser_seconds(text : String) -> (Int32, Int32) raise DateError {
  let number = parser_number(text).unwrap_or_else(() => {
    raise DateError::InvalidDate(message="invalid seconds token")
  })
  let digits = number.fraction.to_array()
  let mut micros = 0
  for index in 0..<6 {
    micros = micros * 10 +
      (if index < digits.length() { digits[index].to_int() - 48 } else { 0 })
  }
  (number.integer(), micros)
}

///|
fn ParserYmd::append_numeric(
  self : ParserYmd,
  number : ParserNumber,
) -> Unit raise DateError {
  if number.integer() == 100 && number.fractional() {
    self.century = true
    self.append_value(100, Some(Y))
  } else {
    self.append_number(number.integer())
  }
}

///|
fn ParserYmd::could_be_numeric_day(
  self : ParserYmd,
  number : ParserNumber,
) -> Bool raise DateError {
  self.could_be_day(number.integer()) &&
  (!number.fractional() || self.could_be_day(number.integer() + 1))
}
