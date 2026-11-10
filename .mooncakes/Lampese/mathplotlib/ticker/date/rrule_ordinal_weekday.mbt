///|
fn DateRule::matches_ordinal_weekday(
  self : DateRule,
  value : DateTime,
  period_year : Int32,
) -> Bool {
  guard self.bynweekday is Some(weekdays) else { return true }
  let (first, last) = if self.frequency is Yearly && self.bymonth is None {
    (days_from_civil(period_year, 1, 1), days_from_civil(period_year + 1, 1, 1))
  } else {
    let first = days_from_civil(value.year, value.month, 1)
    (first, first + days_in_month(value.year, value.month))
  }
  let day = Int64::from_int(days_from_civil(value.year, value.month, value.day))
  for weekday in weekdays {
    let nth = Int64::from_int(weekday.nth.unwrap_or(1))
    let target = Int64::from_int(weekday.weekday)
    let selected = if nth > 0L {
      let start = Int64::from_int(first)
      let current = ((start + 3L) % 7L + 7L) % 7L
      start + (target - current + 7L) % 7L + (nth - 1L) * 7L
    } else {
      let stop = Int64::from_int(last - 1)
      let current = ((stop + 3L) % 7L + 7L) % 7L
      stop - (current - target + 7L) % 7L - (-nth - 1L) * 7L
    }
    if selected == day &&
      selected >= Int64::from_int(first) &&
      selected < Int64::from_int(last) {
      return true
    }
  }
  false
}
