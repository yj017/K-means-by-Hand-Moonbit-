///|
fn DateTime::day_of_year(self : DateTime) -> Int32 {
  days_from_civil(self.year, self.month, self.day) -
  days_from_civil(self.year, 1, 1) +
  1
}

///|
// ISO weeks belong to the year containing their Thursday; week 1 contains
// January 4. All arithmetic stays in Gregorian integer days, independent of
// the floating epoch and the instant's UTC date.
fn DateTime::iso_week(self : DateTime) -> (Int32, Int32) {
  let day = days_from_civil(self.year, self.month, self.day)
  let (year, _, _) = civil_from_days(day + 3 - self.weekday())
  let january_four = days_from_civil(year, 1, 4)
  let first_monday = january_four - weekday_from_civil(year, 1, 4)
  (year, (day - first_monday) / 7 + 1)
}

///|
// %U and %W count a first complete Sunday/Monday week; earlier days are week 0.
fn DateTime::calendar_week(self : DateTime, monday : Bool) -> Int32 {
  let weekday = if monday { self.weekday() } else { (self.weekday() + 1) % 7 }
  (self.day_of_year() - 1 + 7 - weekday) / 7
}

///|
fn three_digits(value : Int32) -> String {
  if value < 10 {
    "00" + value.to_string()
  } else if value < 100 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}
