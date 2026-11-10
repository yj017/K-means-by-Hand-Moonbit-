///|
fn ParserFields::has_value(self : ParserFields) -> Bool {
  self.year is Some(_) ||
  self.month is Some(_) ||
  self.day is Some(_) ||
  self.weekday is Some(_) ||
  self.hour is Some(_) ||
  self.minute is Some(_) ||
  self.second is Some(_) ||
  self.microsecond is Some(_) ||
  self.tzname is Some(_) ||
  self.tzoffset is Some(_) ||
  self.ampm is Some(_)
}

///|
// datetime.replace preserves a default's fold. Recover that distinction from
// its exact rule-zone instant, and select the later target candidate only
// when the default really represented the later side of a repeated wall time.
fn parser_replace_zone(
  value : DateTime,
  fallback : DateTime,
  zone : DateTimeZone,
) -> DateTime raise DateError {
  let earliest = zone.resolve_arithmetic_local(value)
  if zone.resolve_arithmetic_local(fallback).offset_seconds ==
    fallback.offset_seconds {
    return earliest
  }
  let mut latest : Int64? = None
  let mut selected = earliest
  for offset in zone.offsets() {
    let instant = locator_microseconds(value) -
      Int64::from_int(offset) * 1_000_000L
    let (active, name) = zone.offset_info_at_microseconds(instant) catch {
      _ => continue
    }
    if active == offset && (latest is None || instant > latest.unwrap()) {
      latest = Some(instant)
      selected = arithmetic_zoned_date(value, zone, offset, name)
    }
  }
  selected
}

///|
// Field replacement keeps omitted time components and the default's zone.
// Only an omitted day is clamped to month end; an explicit invalid day fails.
fn parser_build_naive(
  fields : ParserFields,
  fallback : DateTime,
) -> DateTime raise DateError {
  if !fields.has_value() {
    raise DateError::InvalidDate(message="string does not contain a date")
  }
  let year = fields.year.unwrap_or(fallback.year)
  let month = fields.month.unwrap_or(fallback.month)
  let day = fields.day.unwrap_or(
    Int32::min(fallback.day, days_in_month(year, month)),
  )
  let value = datetime(
    year,
    month,
    day,
    hour=fields.hour.unwrap_or(fallback.hour),
    minute=fields.minute.unwrap_or(fallback.minute),
    second=fields.second.unwrap_or(fallback.second),
    microsecond=fields.microsecond.unwrap_or(fallback.microsecond),
    offset_seconds=fallback.offset_seconds,
  )
  let value = match fallback.timezone {
    Some(zone) => parser_replace_zone(value, fallback, zone)
    None => value
  }
  if fields.day is None && fields.weekday is Some(weekday) {
    value.add_timedelta(timedelta(days=(weekday - value.weekday() + 7) % 7))
  } else {
    value
  }
}
