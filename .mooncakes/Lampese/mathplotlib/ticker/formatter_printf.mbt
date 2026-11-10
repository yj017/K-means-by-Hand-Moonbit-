///|
/// Bounded printf subset for numeric labels. Unsupported or excessive fields
/// are preserved literally, including incomplete conversions.
fn format_printf(format : String, value : Double) -> String {
  let chars = format.to_array()
  let result = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '%' {
      result.write_char(chars[index])
      index += 1
      continue
    }
    let start = index
    index += 1
    if index < chars.length() && chars[index] == '%' {
      result.write_char('%')
      index += 1
      continue
    }
    let mut left = false
    let mut zero = false
    let mut plus = false
    let mut leading_space = false
    let mut alternate = false
    let mut flags = true
    while flags && index < chars.length() {
      match chars[index] {
        '-' => left = true
        '0' => zero = true
        '+' => plus = true
        ' ' => leading_space = true
        '#' => alternate = true
        _ => {
          flags = false
          continue
        }
      }
      index += 1
    }
    let mut width = 0
    while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
      width = Int32::min(
        1001,
        width * 10 + chars[index].to_int() - '0'.to_int(),
      )
      index += 1
    }
    let mut precision : Int32? = None
    if index < chars.length() && chars[index] == '.' {
      index += 1
      let mut digits = 0
      while index < chars.length() && chars[index] >= '0' && chars[index] <= '9' {
        digits = Int32::min(
          101,
          digits * 10 + chars[index].to_int() - '0'.to_int(),
        )
        index += 1
      }
      precision = Some(digits)
    }
    if index >= chars.length() {
      result.write_string(String::from_array(chars[start:]))
      break
    }
    let conversion = chars[index]
    index += 1
    if width > 1000 || precision.unwrap_or(0) > 100 {
      result.write_string(String::from_array(chars[start:index]))
      continue
    }
    let mut rendered = match conversion {
      'g' | 'G' => format_general(value, precision, alternate)
      'f' | 'F' => format_fixed(value, precision.unwrap_or(6))
      'e' | 'E' => format_scientific(value, precision.unwrap_or(6))
      'd' | 'i' => {
        if value.is_nan() || value.is_inf() {
          result.write_string(String::from_array(chars[start:index]))
          continue
        }
        let text = format_integer(value)
        let negative = text.has_prefix("-")
        let digits = if negative { text[1:].to_owned() } else { text }
        (if negative { "-" } else { "" }) +
        digits.pad_start(precision.unwrap_or(1), '0')
      }
      _ => {
        result.write_string(String::from_array(chars[start:index]))
        continue
      }
    }
    if alternate &&
      (
        conversion == 'f' ||
        conversion == 'F' ||
        conversion == 'e' ||
        conversion == 'E'
      ) &&
      !value.is_nan() &&
      !value.is_inf() &&
      !rendered.contains(".") {
      match rendered.find("e") {
        Some(at) =>
          rendered = rendered[:at].to_owned() + "." + rendered[at:].to_owned()
        None => rendered += "."
      }
    }
    if conversion == 'G' || conversion == 'E' || conversion == 'F' {
      rendered = rendered.to_upper()
    }
    if !rendered.has_prefix("-") {
      if plus {
        rendered = "+" + rendered
      } else if leading_space {
        rendered = " " + rendered
      }
    }
    result.write_string(pad_printf(rendered, width, left, zero))
  }
  result.to_string()
}

///|
fn pad_printf(
  value : String,
  width : Int32,
  left : Bool,
  zero : Bool,
) -> String {
  let chars = value.to_array()
  let padding = width - chars.length()
  if padding <= 0 {
    return value
  }
  let fill = String::make(padding, if zero && !left { '0' } else { ' ' })
  if left {
    value + fill
  } else if zero &&
    chars.length() > 0 &&
    (chars[0] == '-' || chars[0] == '+' || chars[0] == ' ') {
    String::from_array(chars[:1]) + fill + String::from_array(chars[1:])
  } else {
    fill + value
  }
}
