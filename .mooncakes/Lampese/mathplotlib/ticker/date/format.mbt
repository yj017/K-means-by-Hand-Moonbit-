///|
fn two_digits(value : Int32) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn four_digits(value : Int32) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn six_digits(value : Int32) -> String {
  if value < 10 {
    "00000" + value.to_string()
  } else if value < 100 {
    "0000" + value.to_string()
  } else if value < 1000 {
    "000" + value.to_string()
  } else if value < 10000 {
    "00" + value.to_string()
  } else if value < 100000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
let month_short : Array[String] = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
]

///|
let month_long : Array[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
let weekday_short : Array[String] = [
  "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun",
]

///|
let weekday_long : Array[String] = [
  "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
]

///|
/// Format standard strftime date/time directives in the deterministic C locale.
/// Week and day fields refer to this value's local calendar. Unknown directives
/// are retained literally; platform flags and arbitrary locales are unsupported.
///
/// ```mbt check
/// test {
///   let date = @date.datetime(2021, 1, 1, hour=13)
///   assert_eq(
///     @date.format_date(date, "%G-W%V-%u %j %I %p"),
///     "2020-W53-5 001 01 PM",
///   )
/// }
/// ```
pub fn format_date(value : DateTime, format : String) -> String {
  let result = StringBuilder()
  let chars = format.to_array()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '%' || index + 1 >= chars.length() {
      result.write_char(chars[index])
      index += 1
      continue
    }
    index += 1
    match chars[index] {
      'Y' => result.write_string(four_digits(value.year))
      'y' => result.write_string(two_digits(value.year % 100))
      'm' => result.write_string(two_digits(value.month))
      'd' => result.write_string(two_digits(value.day))
      'H' => result.write_string(two_digits(value.hour))
      'I' =>
        result.write_string(
          two_digits(if value.hour % 12 == 0 { 12 } else { value.hour % 12 }),
        )
      'p' => result.write_string(if value.hour < 12 { "AM" } else { "PM" })
      'M' => result.write_string(two_digits(value.minute))
      'S' => result.write_string(two_digits(value.second))
      'f' => result.write_string(six_digits(value.microsecond))
      'z' => result.write_string(format_timezone_offset(value.offset_seconds))
      'Z' =>
        if value.abbreviation is Some(name) {
          result.write_string(name)
        } else if value.offset_seconds == 0 {
          result.write_string("UTC")
        } else {
          result.write_string("UTC")
          result.write_string(format_timezone_name_offset(value.offset_seconds))
        }
      'b' => result.write_string(month_short[value.month - 1])
      'B' => result.write_string(month_long[value.month - 1])
      'a' => result.write_string(weekday_short[value.weekday()])
      'A' => result.write_string(weekday_long[value.weekday()])
      'w' => result.write_string(((value.weekday() + 1) % 7).to_string())
      'j' => result.write_string(three_digits(value.day_of_year()))
      'U' => result.write_string(two_digits(value.calendar_week(false)))
      'W' => result.write_string(two_digits(value.calendar_week(true)))
      'u' => result.write_string((value.weekday() + 1).to_string())
      'G' => result.write_string(four_digits(value.iso_week().0))
      'V' => result.write_string(two_digits(value.iso_week().1))
      'c' => {
        result.write_string(weekday_short[value.weekday()])
        result.write_char(' ')
        result.write_string(month_short[value.month - 1])
        result.write_char(' ')
        if value.day < 10 {
          result.write_char(' ')
        }
        result.write_string(value.day.to_string())
        result.write_char(' ')
        result.write_string(
          two_digits(value.hour) +
          ":" +
          two_digits(value.minute) +
          ":" +
          two_digits(value.second),
        )
        result.write_char(' ')
        result.write_string(four_digits(value.year))
      }
      'x' =>
        result.write_string(
          two_digits(value.month) +
          "/" +
          two_digits(value.day) +
          "/" +
          two_digits(value.year % 100),
        )
      'X' =>
        result.write_string(
          two_digits(value.hour) +
          ":" +
          two_digits(value.minute) +
          ":" +
          two_digits(value.second),
        )
      '%' => result.write_char('%')
      _ => {
        result.write_char('%')
        result.write_char(chars[index])
      }
    }
    index += 1
  }
  result.to_string()
}

///|
fn format_timezone_offset(offset_seconds : Int32) -> String {
  let sign = if offset_seconds < 0 { "-" } else { "+" }
  let absolute = Int32::abs(offset_seconds)
  sign +
  two_digits(absolute / 3600) +
  two_digits(absolute / 60 % 60) +
  (if absolute % 60 == 0 { "" } else { two_digits(absolute % 60) })
}

///|
fn format_timezone_name_offset(offset_seconds : Int32) -> String {
  let sign = if offset_seconds < 0 { "-" } else { "+" }
  let absolute = Int32::abs(offset_seconds)
  sign +
  two_digits(absolute / 3600) +
  ":" +
  two_digits(absolute / 60 % 60) +
  (if absolute % 60 == 0 { "" } else { ":" + two_digits(absolute % 60) })
}
