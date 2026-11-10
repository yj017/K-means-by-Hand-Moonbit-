///|
priv enum ParserLexState {
  Word
  Number
  WordDot
  NumberDot
} derive(Eq)

///|
// Literal port of the fixed dateutil lexer states: dots can join words or
// decimal numbers and require whole-token context before splitting. Nulls
// disappear without introducing a boundary; each whitespace emits one space.
fn parser_lex(input : String) -> Array[String] {
  let chars = input.to_array().filter(char => char != '\u0000')
  let output : Array[String] = []
  let mut index = 0
  while index < chars.length() {
    let token : Array[Char] = [chars[index]]
    index += 1
    let mut state = if parser_is_word(token[0]) {
      Word
    } else if parser_is_digit(token[0]) {
      Number
    } else {
      output.push(
        if parser_is_space(token[0]) {
          " "
        } else {
          token[0].to_string()
        },
      )
      continue
    }
    let mut seen_letters = false
    while index < chars.length() {
      let char = chars[index]
      match state {
        Word => {
          seen_letters = true
          if parser_is_word(char) {
            token.push(char)
          } else if char == '.' {
            token.push(char)
            state = WordDot
          } else {
            break
          }
        }
        Number =>
          if parser_is_digit(char) {
            token.push(char)
          } else if char == '.' || (char == ',' && token.length() >= 2) {
            token.push(char)
            state = NumberDot
          } else {
            break
          }
        WordDot => {
          seen_letters = true
          if char == '.' || parser_is_word(char) {
            token.push(char)
          } else if parser_is_digit(char) && token[token.length() - 1] == '.' {
            token.push(char)
            state = NumberDot
          } else {
            break
          }
        }
        NumberDot =>
          if char == '.' || parser_is_digit(char) {
            token.push(char)
          } else if parser_is_word(char) && token[token.length() - 1] == '.' {
            token.push(char)
            state = WordDot
          } else {
            break
          }
      }
      index += 1
    }
    let dot_count = token.filter(char => char == '.').length()
    let last = token[token.length() - 1]
    if (state == WordDot || state == NumberDot) &&
      (seen_letters || dot_count > 1 || last == '.' || last == ',') {
      let mut first = 0
      for position in 0..<token.length() {
        if token[position] == '.' || token[position] == ',' {
          if position > first {
            output.push(String::from_array(token[first:position]))
          }
          output.push(token[position].to_string())
          first = position + 1
        }
      }
      if first < token.length() {
        output.push(String::from_array(token[first:]))
      }
    } else {
      if state == NumberDot && dot_count == 0 {
        for position in 0..<token.length() {
          if token[position] == ',' {
            token[position] = '.'
          }
        }
      }
      output.push(String::from_array(token[:]))
    }
  }
  output
}

///|
fn parser_integer(text : String) -> Int32 raise DateError {
  let chars = text.to_array()
  let mut sign = 1
  let mut index = 0
  if !chars.is_empty() && (chars[0] == '+' || chars[0] == '-') {
    if chars[0] == '-' {
      sign = -1
    }
    index = 1
  }
  if index == chars.length() {
    raise DateError::InvalidDate(message="invalid numeric date token")
  }
  let mut value = 0L
  while index < chars.length() {
    let digit = parser_decimal_digit(chars[index]).unwrap_or(-1)
    if digit < 0 {
      raise DateError::InvalidDate(message="invalid numeric date token")
    }
    value = value * 10L + Int64::from_int(digit)
    if value > 2147483647L {
      raise DateError::InvalidDate(message="numeric date token is out of range")
    }
    index += 1
  }
  sign * value.to_int()
}
