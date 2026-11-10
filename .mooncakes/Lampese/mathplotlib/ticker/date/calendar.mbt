///|
fn is_leap_year(year : Int32) -> Bool {
  year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
}

///|
fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    2 => if is_leap_year(year) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
/// Return Monday=0 through Sunday=6 for any supported Gregorian date.
fn weekday_from_civil(year : Int32, month : Int32, day : Int32) -> Int32 {
  let weekday = (days_from_civil(year, month, day) + 3) % 7
  if weekday < 0 {
    weekday + 7
  } else {
    weekday
  }
}

///|
/// Return the number of whole Gregorian days since 1970-01-01.
fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int32 {
  let adjusted_year = year - (if month <= 2 { 1 } else { 0 })
  let era = if adjusted_year >= 0 {
    adjusted_year / 400
  } else {
    (adjusted_year - 399) / 400
  }
  let year_of_era = adjusted_year - era * 400
  let month_prime = month + (if month > 2 { -3 } else { 9 })
  let day_of_year = (153 * month_prime + 2) / 5 + day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  era * 146097 + day_of_era - 719468
}

///|
/// Convert a day count since 1970-01-01 back to Gregorian components.
fn civil_from_days(days : Int32) -> (Int32, Int32, Int32) {
  let shifted = days + 719468
  let era = if shifted >= 0 {
    shifted / 146097
  } else {
    (shifted - 146096) / 146097
  }
  let day_of_era = shifted - era * 146097
  let year_of_era = (
      day_of_era - day_of_era / 1460 + day_of_era / 36524 - day_of_era / 146096
    ) /
    365
  let year = year_of_era + era * 400
  let day_of_year = day_of_era -
    (365 * year_of_era + year_of_era / 4 - year_of_era / 100)
  let month_prime = (5 * day_of_year + 2) / 153
  let day = day_of_year - (153 * month_prime + 2) / 5 + 1
  let month = month_prime + (if month_prime < 10 { 3 } else { -9 })
  let result_year = year + (if month <= 2 { 1 } else { 0 })
  (result_year, month, day)
}
