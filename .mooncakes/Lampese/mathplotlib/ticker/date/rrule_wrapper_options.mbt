///|
priv enum WrapperDateValue {
  Omitted
  NullDate
  DateValue(RRuleDateTime)
}

///|
// YearLocator passes raw month/day values to datetime.replace. Preserve the
// keyword's shape even though the recurrence core consumes a selector array.
priv enum WrapperCalendarForm {
  OmittedCalendar
  NullCalendar
  ScalarCalendar(Int32)
  ArrayCalendar
}

///|
fn WrapperCalendarForm::date_field(
  self : WrapperCalendarForm,
) -> Int32 raise DateError {
  match self {
    OmittedCalendar => 1
    ScalarCalendar(value) => value
    NullCalendar | ArrayCalendar =>
      raise DateError::InvalidDate(
        message="YearLocator calendar keyword must be a scalar integer",
      )
  }
}

///|
priv struct WrapperOptions {
  frequency : RRuleFrequency
  interval : Int32
  wkst : Int32
  dtstart : WrapperDateValue
  until : WrapperDateValue
  count : Int32?
  cache : Bool
  bymonth_form : WrapperCalendarForm
  bymonthday_form : WrapperCalendarForm
  bymonth : Array[Int32]?
  bymonthday : Array[Int32]?
  byyearday : Array[Int32]?
  byweekno : Array[Int32]?
  byeaster : Array[Int32]?
  byweekday : Array[Int32]?
  byhour : Array[Int32]?
  byminute : Array[Int32]?
  bysecond : Array[Int32]?
  bysetpos : Array[Int32]?
  byweekdays : Array[RelativeWeekday]?
}

///|
fn wrapper_date_option(value : RRuleDateTime?) -> WrapperDateValue {
  match value {
    Some(value) => DateValue(value)
    None => Omitted
  }
}

///|
// None-valued date keywords are distinct from omitted ones in the original
// wrapper: accessing their tzinfo fails before constructing the underlying rule.
fn WrapperOptions::with_null(
  self : WrapperOptions,
  names : Array[String],
) -> WrapperOptions raise DateError {
  let mut result = self
  for name in names {
    result = match name {
      "dtstart" => { ..result, dtstart: NullDate, }
      "until" => { ..result, until: NullDate, }
      "count" => { ..result, count: None, }
      "wkst" => { ..result, wkst: 0, }
      "cache" => { ..result, cache: false, }
      "bymonth" => { ..result, bymonth: None, bymonth_form: NullCalendar, }
      "bymonthday" =>
        { ..result, bymonthday: None, bymonthday_form: NullCalendar, }
      "byyearday" => { ..result, byyearday: None, }
      "byweekno" => { ..result, byweekno: None, }
      "byeaster" => { ..result, byeaster: None, }
      "byweekday" | "byweekdays" =>
        { ..result, byweekday: None, byweekdays: None, }
      "byhour" => { ..result, byhour: None, }
      "byminute" => { ..result, byminute: None, }
      "bysecond" => { ..result, bysecond: None, }
      "bysetpos" => { ..result, bysetpos: None, }
      _ =>
        raise DateError::InvalidDate(
          message="unsupported null rule keyword '\{name}'",
        )
    }
  }
  result
}

///|
fn WrapperOptions::snapshot(self : WrapperOptions) -> WrapperOptions {
  {
    ..self,
    bymonth: self.bymonth.map(values => values.copy()),
    bymonthday: self.bymonthday.map(values => values.copy()),
    byyearday: self.byyearday.map(values => values.copy()),
    byweekno: self.byweekno.map(values => values.copy()),
    byeaster: self.byeaster.map(values => values.copy()),
    byweekday: self.byweekday.map(values => values.copy()),
    byhour: self.byhour.map(values => values.copy()),
    byminute: self.byminute.map(values => values.copy()),
    bysecond: self.bysecond.map(values => values.copy()),
    bysetpos: self.bysetpos.map(values => values.copy()),
    byweekdays: self.byweekdays.map(values => values.copy()),
  }
}

///|
fn WrapperOptions::normalized(
  self : WrapperOptions,
  base : DateTimeZone?,
) -> (WrapperOptions, DateTimeZone?) raise DateError {
  let mut timezone = base
  let mut result = self
  match self.dtstart {
    NullDate =>
      raise DateError::InvalidDate(
        message="rrulewrapper dtstart cannot be None",
      )
    DateValue(start) if start.timezone is Some(zone) => {
      let wall = match timezone {
        Some(base) => start.wall_in(base)
        None => {
          timezone = Some(zone)
          rrule_wall_date(start.value)
        }
      }
      result = { ..result, dtstart: DateValue(RRuleDateTime::naive(wall)), }
    }
    _ => ()
  }
  match self.until {
    NullDate =>
      raise DateError::InvalidDate(message="rrulewrapper until cannot be None")
    DateValue(until) if until.timezone is Some(_) => {
      guard timezone is Some(zone) else {
        raise DateError::InvalidDate(
          message="until cannot be aware when dtstart is naive and no base timezone exists",
        )
      }
      result = {
        ..result,
        until: DateValue(RRuleDateTime::naive(until.wall_in(zone))),
      }
    }
    _ => ()
  }
  (result, timezone)
}

///|
fn WrapperOptions::build_rule(
  self : WrapperOptions,
  context : DateParserContext?,
) -> RRule raise DateError {
  let start = match self.dtstart {
    DateValue(start) => rrule_wall_date(start.value, truncate=true)
    _ => {
      let context = match context {
        Some(value) => value
        None => DateParserContext::system()
      }
      rrule_wall_date(context.local_now((context.clock)()), truncate=true)
    }
  }
  let until = match self.until {
    DateValue(value) => Some(rrule_wall_date(value.value))
    _ => None
  }
  if self.byweekday is Some(_) && self.byweekdays is Some(_) {
    raise DateError::InvalidDate(
      message="use byweekday integers or byweekdays objects",
    )
  }
  let mut plain = self.byweekday
  let mut ordinal : Array[RelativeWeekday]? = None
  if self.byweekdays is Some(values) {
    if values.is_empty() {
      raise DateError::InvalidDate(
        message="weekday selector array must not be empty",
      )
    }
    let weekdays : Array[Int32] = []
    let ordered : Array[RelativeWeekday] = []
    for value in values {
      ignore(weekday_selector(value.weekday))
      if (self.frequency is Yearly || self.frequency is Monthly) &&
        value.nth.unwrap_or(0) != 0 {
        if !ordered.contains(value) {
          ordered.push(value)
        }
      } else if !weekdays.contains(value.weekday) {
        weekdays.push(value.weekday)
      }
    }
    if !weekdays.is_empty() {
      plain = Some(weekdays)
    }
    if !ordered.is_empty() {
      ordinal = Some(ordered)
    }
  }
  let core = rrule(
    self.frequency,
    start,
    interval=self.interval,
    wkst=self.wkst,
    bymonth?=self.bymonth,
    bymonthday?=self.bymonthday,
    byyearday?=self.byyearday,
    byweekno?=self.byweekno,
    byeaster?=self.byeaster,
    byweekday?=plain,
    byhour?=self.byhour,
    byminute?=self.byminute,
    bysecond?=self.bysecond,
    bysetpos?=self.bysetpos,
    until?,
    cache=self.cache,
  )
  let rule = match self.frequency {
    Hourly =>
      {
        ..core.rule,
        byhour: wrapper_clock_selection(
          core.rule.byhour,
          start.hour,
          self.interval,
          24,
        ),
      }
    Minutely =>
      {
        ..core.rule,
        byminute: wrapper_clock_selection(
          core.rule.byminute,
          start.minute,
          self.interval,
          60,
        ),
      }
    Secondly =>
      {
        ..core.rule,
        bysecond: wrapper_clock_selection(
          core.rule.bysecond,
          start.second,
          self.interval,
          60,
        ),
      }
    _ => core.rule
  }
  {
    rule: { ..rule, count: self.count, bynweekday: ordinal, },
    cache: core.cache,
  }
}

///|
// dateutil's same-frequency BYHOUR/BYMINUTE/BYSECOND constructor keeps only
// residues reachable from DTSTART and raises before iteration if none remain.
// The raw construction arrays stay intact for the next wrapper.set call.
fn wrapper_clock_selection(
  values : Array[Int32]?,
  start : Int32,
  interval : Int32,
  base : Int32,
) -> Array[Int32]? raise DateError {
  match values {
    None => None
    Some(values) => {
      let divisor = locator_gcd(interval, base)
      let selected = values.filter(value => (value - start) % divisor == 0)
      if selected.is_empty() {
        raise DateError::InvalidDate(
          message="recurrence clock selector has no reachable value",
        )
      }
      Some(selected)
    }
  }
}
