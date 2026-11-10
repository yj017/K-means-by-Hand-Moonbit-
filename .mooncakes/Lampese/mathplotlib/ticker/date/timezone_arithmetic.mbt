///|
// Materialize only the requested POSIX years, sharing the existing evaluator's
// date-rule helper and time-basis conventions with recurrence window bounds.
fn DateTimeZone::future_transitions(
  self : DateTimeZone,
  first_year : Int32,
  last_year : Int32,
) -> Array[TimeZoneTransition] {
  let result : Array[TimeZoneTransition] = []
  match self.footer {
    Some(rule) =>
      match (rule.start_rule, rule.end_rule, rule.dst_offset, rule.dst_abbr) {
        (Some(start), Some(end), Some(dst), Some(dst_name)) => {
          let end_offset = match end.time_basis {
            Standard => rule.std_offset
            _ => dst
          }
          for year in first_year..<=last_year {
            for
              (point, offset, name) in [
                (
                  if self.dateutil_footer {
                    Ok(
                      dateutil_transition_point(
                        start,
                        year,
                        rule.std_offset,
                        dst,
                        false,
                      ),
                    )
                  } else {
                    @tzposix.compute_transition_point(
                      start,
                      year,
                      rule.std_offset,
                    )
                  },
                  dst,
                  dst_name,
                ),
                (
                  if self.dateutil_footer {
                    Ok(
                      dateutil_transition_point(
                        end,
                        year,
                        rule.std_offset,
                        dst,
                        true,
                      ),
                    )
                  } else {
                    @tzposix.compute_transition_point(end, year, end_offset)
                  },
                  rule.std_offset,
                  rule.std_abbr,
                ),
              ] {
              match point {
                Ok(seconds) =>
                  if self.footer_start_seconds is None ||
                    seconds >= self.footer_start_seconds.unwrap() {
                    result.push({
                      at_microseconds: seconds * 1_000_000L,
                      offset_seconds: offset,
                      abbreviation: Some(name),
                    })
                  }
                Err(_) => ()
              }
            }
          }
        }
        _ => ()
      }
    None => ()
  }
  result
}

///|
fn arithmetic_zoned_date(
  value : DateTime,
  zone : DateTimeZone,
  offset : Int32,
  name : String?,
) -> DateTime {
  {
    ..value,
    offset_seconds: offset,
    offset_minutes: offset / 60,
    abbreviation: name,
    timezone: Some(zone),
  }
}

///|
fn DateTimeZone::resolve_arithmetic_local(
  self : DateTimeZone,
  value : DateTime,
  fold~ : Bool = false,
) -> DateTime raise DateError {
  if self.dateutil_footer && self.footer is Some(rule) {
    let (offset, name) = dateutil_posix_local_info(rule, value, fold)
    return arithmetic_zoned_date(value, self, offset, name)
  }
  let mut earliest : Int64? = None
  let mut selected : (Int32, String?)? = None
  for offset in self.offsets() {
    let encoded = locator_microseconds(value) -
      Int64::from_int(offset) * 1_000_000L
    let (active, name) = self.offset_info_at_microseconds(encoded) catch {
      _ => continue
    }
    if active == offset && (earliest is None || encoded < earliest.unwrap()) {
      earliest = Some(encoded)
      selected = Some((offset, name))
    }
  }
  match selected {
    Some((offset, name)) =>
      return arithmetic_zoned_date(value, self, offset, name)
    None => ()
  }
  let local_microseconds = locator_microseconds(value)
  let mut previous = self.initial_offset_seconds
  for transition in self.transitions {
    let at = transition.at_microseconds
    if transition.offset_seconds > previous &&
      local_microseconds >= at + Int64::from_int(previous) * 1_000_000L &&
      local_microseconds <
      at + Int64::from_int(transition.offset_seconds) * 1_000_000L {
      return arithmetic_zoned_date(
        value,
        self,
        transition.offset_seconds,
        transition.abbreviation,
      )
    }
    previous = transition.offset_seconds
  }
  for transition in self.future_transitions(value.year - 2, value.year + 2) {
    let (before, _) = self.offset_info_at_microseconds(
      transition.at_microseconds - 1L,
    ) catch {
      _ => continue
    }
    let (after, name) = self.offset_info_at_microseconds(
      transition.at_microseconds,
    ) catch {
      _ => continue
    }
    let at = transition.at_microseconds
    if after > before &&
      local_microseconds >= at + Int64::from_int(before) * 1_000_000L &&
      local_microseconds < at + Int64::from_int(after) * 1_000_000L {
      return arithmetic_zoned_date(value, self, after, name)
    }
  }
  raise DateError::InvalidDate(
    message="local arithmetic result is outside the timezone calendar",
  )
}

///|
// dateutil tzrangebase.fromutc first shifts by its UTC transition mask, then
// the returned datetime's utcoffset() reevaluates the standard-wall mask. The
// masks can disagree for negative DST. Preserve the resulting wall fields and
// attached offset, including source fold handling for positive DST.
fn DateTimeZone::from_utc_calendar(
  self : DateTimeZone,
  value : DateTime,
  offset : Int32,
  name : String?,
) -> DateTime {
  if self.dateutil_footer && self.footer is Some(rule) {
    let fold = match rule.dst_offset {
      Some(dst) => offset != dst
      None => false
    }
    let (offset, name) = dateutil_posix_local_info(rule, value, fold)
    arithmetic_zoned_date(value, self, offset, name)
  } else {
    arithmetic_zoned_date(value, self, offset, name)
  }
}
