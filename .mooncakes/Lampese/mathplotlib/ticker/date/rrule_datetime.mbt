///|
/// Explicit awareness at rrulewrapper's boundary. DateTime continues to store
/// ordinary aware instants; a naive rule date stores only its local fields.
pub struct RRuleDateTime {
  priv value : DateTime
  priv timezone : DateTimeZone?
  priv fold : Bool
}

///|
fn rrule_wall_date(value : DateTime, truncate~ : Bool = false) -> DateTime {
  {
    ..value,
    microsecond: if truncate {
      0
    } else {
      value.microsecond
    },
    offset_minutes: 0,
    offset_seconds: 0,
    abbreviation: None,
    timezone: None,
  }
}

///|
/// Drop the timezone without changing local fields.
pub fn RRuleDateTime::naive(value : DateTime) -> RRuleDateTime {
  { value: rrule_wall_date(value), timezone: None, fold: false, }
}

///|
/// Retain the instant and its rule-zone identity, or capture a fixed-offset
/// snapshot when the DateTime has no retained rule zone.
pub fn RRuleDateTime::aware(value : DateTime) -> RRuleDateTime {
  let zone = match value.timezone {
    Some(zone) => zone
    None =>
      {
        ..(try! fixed_timezone_seconds(value.offset_seconds)),
        initial_abbreviation: value.abbreviation,
      }
  }
  {
    value: arithmetic_zoned_date(
      value,
      zone,
      value.offset_seconds,
      value.abbreviation,
    ),
    timezone: Some(zone),
    fold: zone.infer_rule_fold(value),
  }
}

///|
/// Attach a zone to local fields. Imaginary gaps use the post-transition offset;
/// fold selects dateutil wall-time behavior (earlier/later for ordinary folds).
/// This does not convert through numeric date coordinates or read the epoch.
pub fn RRuleDateTime::from_local(
  value : DateTime,
  timezone : DateTimeZone,
  fold~ : Bool = false,
) -> RRuleDateTime raise DateError {
  let wall = rrule_wall_date(value)
  let mut selected = timezone.resolve_arithmetic_local(wall, fold~)
  if fold && !timezone.dateutil_footer {
    let wall_microseconds = locator_microseconds(wall)
    let mut latest : Int64? = None
    for offset in timezone.offsets() {
      let instant = wall_microseconds - Int64::from_int(offset) * 1000000L
      let (active, name) = timezone.offset_info_at_microseconds(instant)
      if active == offset && (latest is None || instant > latest.unwrap()) {
        latest = Some(instant)
        selected = arithmetic_zoned_date(wall, timezone, offset, name)
      }
    }
  }
  { value: selected, timezone: Some(timezone), fold, }
}

///|
pub fn RRuleDateTime::is_naive(self : RRuleDateTime) -> Bool {
  self.timezone is None
}

///|
/// Local fields plus an exact offset for aware values. Naive values use offset
/// zero as a field carrier; retain RRuleDateTime when awareness matters.
pub fn RRuleDateTime::date(self : RRuleDateTime) -> DateTime {
  self.value
}

///|
pub fn RRuleDateTime::timezone(self : RRuleDateTime) -> DateTimeZone? {
  self.timezone
}

///|
fn RRuleDateTime::validate_ordinal(
  self : RRuleDateTime,
) -> Unit raise DateError {
  if !self.is_naive() {
    let instant = rruleset_instant(self.value)
    if instant < -62_135_596_800_000_000L || instant >= 253_402_300_800_000_000L {
      raise DateError::InvalidDate(
        message="rule date UTC instant is outside years 1..9999",
      )
    }
  }
}

///|
/// Convert to numeric dates, checking aware UTC overflow before reading epoch.
pub fn RRuleDateTime::to_ordinal(
  self : RRuleDateTime,
) -> Double raise DateError {
  self.validate_ordinal()
  self.value.to_ordinal()
}

///|
fn RRuleDateTime::wall_in(
  self : RRuleDateTime,
  zone : DateTimeZone,
) -> DateTime raise DateError {
  match self.timezone {
    None => rrule_wall_date(self.value)
    Some(current) if physical_equal(current, zone) =>
      rrule_wall_date(self.value)
    Some(_) => rrule_wall_date(self.value.with_timezone(zone))
  }
}

///|
fn attach_rule_timezone(
  value : DateTime,
  timezone : DateTimeZone?,
) -> RRuleDateTime raise DateError {
  match timezone {
    Some(zone) => RRuleDateTime::from_local(value, zone)
    None => RRuleDateTime::naive(value)
  }
}

///|
fn DateTimeZone::infer_rule_fold(self : DateTimeZone, value : DateTime) -> Bool {
  if self.dateutil_footer &&
    self.footer is Some(rule) &&
    rule.dst_offset is Some(dst) &&
    dst < rule.std_offset {
    return false
  }
  let instant = rruleset_instant(value)
  for offset in self.offsets() {
    let candidate = locator_microseconds(value) -
      Int64::from_int(offset) * 1000000L
    let (active, _) = self.offset_info_at_microseconds(candidate) catch {
      _ => continue
    }
    if active == offset && candidate < instant {
      return true
    }
  }
  false
}
