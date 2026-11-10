///|
// date2num checks only the first element's awareness. First-aware mixed arrays
// interpret later naive dates using host rules; first-naive arrays pass through
// NumPy's datetime64 conversion without Python's aware UTC-overflow guard.
fn date_values_to_numbers(
  values : Array[RRuleDateTime],
  context : DateParserContext?,
) -> Array[Double] raise DateError {
  if values.is_empty() {
    return []
  }
  let mut selected_context = context
  let dates = if values[0].is_naive() {
    // NumPy's Python datetime -> datetime64 path truncates utcoffset to whole
    // minutes, toward zero. The first-aware path below normalizes exactly.
    values.map(value => {
      let date = value.date()
      { ..date, offset_seconds: date.offset_seconds / 60 * 60, }
    })
  } else {
    values.map(value => {
      let date = if value.is_naive() {
        let host = match selected_context {
          Some(context) => context
          None => {
            let host = DateParserContext::system()
            selected_context = Some(host)
            host
          }
        }
        host.interpret_naive(value.date(), value.fold)
      } else {
        value.date()
      }
      parser_check_utc(date)
      date
    })
  }
  ignore(selected_epoch())
  dates.map(value => value.to_ordinal())
}
