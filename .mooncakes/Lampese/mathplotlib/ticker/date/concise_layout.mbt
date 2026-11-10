///|
fn concise_field(value : DateTime, level : Int32) -> Int32 {
  match level {
    0 => value.year
    1 => value.month
    2 => value.day
    3 => value.hour
    4 => value.minute
    _ => value.second
  }
}

///|
// Fixed dates.py ConciseDateFormatter.format_ticks, independent of locator
// selection. Calendar fields select the finest unit that differs in the batch.
fn concise_layout(
  formatter : DateFormatter,
  settings : ConciseSettings,
  values : Array[Double],
  inverted : Bool,
) -> (Array[String], String) raise DateError {
  if values.is_empty() {
    return ([], "")
  }
  let dates : Array[DateTime] = []
  for value in values {
    dates.push(formatter.converted_date(value))
  }
  let mut level = 5
  let mut show_offset = settings.show_offset
  for step in 0..<6 {
    let index = 5 - step
    let first = concise_field(dates[0], index)
    if dates.any(value => concise_field(value, index) != first) {
      level = index
      if index < 2 && dates.any(value => concise_field(value, index) == 1) {
        show_offset = false
      }
      break
    }
  }
  let labels : Array[String] = []
  for date in dates {
    let zero = if level < 5 {
      concise_field(date, level) ==
      (if level == 1 || level == 2 { 1 } else { 0 })
    } else {
      date.second == 0 && date.microsecond == 0
    }
    labels.push(
      format_date(
        date,
        if zero {
          settings.zero_formats[level]
        } else {
          settings.formats[level]
        },
      ),
    )
  }
  if level >= 5 {
    let mut trailing_zeros : Int32? = None
    for label in labels {
      if label.contains(".") {
        let count = label.length() - label.trim_end(chars="0").length()
        trailing_zeros = Some(
          match trailing_zeros {
            Some(previous) => Int32::min(previous, count)
            None => count
          },
        )
      }
    }
    if trailing_zeros is Some(count) && count > 0 {
      for index in 0..<labels.length() {
        let label = labels[index]
        if label.contains(".") {
          labels[index] = label
            .view(end_offset=label.length() - count)
            .to_owned()
            .trim_end(chars=".")
            .to_owned()
        }
      }
    }
  }
  let offset = if show_offset {
    let date = if inverted { dates[0] } else { dates[dates.length() - 1] }
    let text = format_date(date, settings.offset_formats[level])
    if formatter.usetex {
      wrap_date_in_tex(text)
    } else {
      text
    }
  } else {
    ""
  }
  (if formatter.usetex { labels.map(wrap_date_in_tex) } else { labels }, offset)
}
