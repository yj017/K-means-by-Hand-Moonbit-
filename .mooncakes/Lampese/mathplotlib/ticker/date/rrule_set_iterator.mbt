///|
fn RRuleSet::snapshot(self : RRuleSet) -> RRuleSet {
  {
    rules: self.rules.copy(),
    dates: self.dates.copy(),
    exrules: self.exrules.copy(),
    exdates: self.exdates.copy(),
    cache: None,
  }
}

///|
fn RRuleSet::invalidate_cache(self : RRuleSet) -> Unit {
  self.cache = recurrence_cache(self.cache_enabled())
}

///|
fn merge_recurrence_sources(sources : Array[Iter[DateTime]]) -> Iter[DateTime] {
  let heads : Array[DateTime?] = sources.map(_ => None)
  let advance = sources.map(_ => true)
  let mut finished = false
  Iter::new(fn() {
    if finished {
      return None
    }
    let mut first : DateTime? = None
    let mut instant : Int64? = None
    for index in 0..<sources.length() {
      if advance[index] {
        heads[index] = sources[index].next()
        advance[index] = false
      }
      match heads[index] {
        Some(value) => {
          let key = rruleset_instant(value)
          if instant is None || key < instant.unwrap() {
            first = Some(value)
            instant = Some(key)
          }
        }
        None => ()
      }
    }
    match instant {
      None => {
        finished = true
        None
      }
      Some(key) => {
        for index in 0..<heads.length() {
          if heads[index] is Some(value) && rruleset_instant(value) == key {
            advance[index] = true
          }
        }
        first
      }
    }
  })
}

///|
fn explicit_recurrence_dates(values : Array[DateTime]) -> Iter[DateTime] {
  rruleset_unique_sorted(
    values.map(value => { instant: rruleset_instant(value), value, }),
  )
  .iter()
  .map(candidate => candidate.value)
}

///|
fn RRuleSet::stream(
  self : RRuleSet,
  lower : DateTime?,
  inc : Bool,
) -> Iter[DateTime] {
  let sources = self.rules.map(rule => {
    match lower {
      Some(value) => rule.iter_after(value, inc~)
      None => rule.iter()
    }
  })
  sources.push(
    explicit_recurrence_dates(self.dates).filter(candidate => {
      match lower {
        Some(value) =>
          if inc {
            rruleset_instant(candidate) >= rruleset_instant(value)
          } else {
            rruleset_instant(candidate) > rruleset_instant(value)
          }
        None => true
      }
    }),
  )
  let inclusions = merge_recurrence_sources(sources)
  let mut exclusions : Iter[DateTime]? = None
  let mut excluded : DateTime? = None
  Iter::new(fn() {
    while true {
      match inclusions.next() {
        None => return None
        Some(value) => {
          if exclusions is None {
            let sources = self.exrules.map(rule => {
              rule.iter_after(value, inc=true)
            })
            sources.push(explicit_recurrence_dates(self.exdates))
            exclusions = Some(merge_recurrence_sources(sources))
            excluded = exclusions.unwrap().next()
          }
          let instant = rruleset_instant(value)
          while excluded is Some(previous) &&
                rruleset_instant(previous) < instant {
            excluded = exclusions.unwrap().next()
          }
          if excluded is Some(previous) && rruleset_instant(previous) == instant {
            continue
          }
          return Some(value)
        }
      }
    }
    None
  })
}

///|
/// Return whether this set caches a shared occurrence prefix.
pub fn RRuleSet::cache_enabled(self : RRuleSet) -> Bool {
  self.cache is Some(_)
}

///|
/// Lazily merge inclusion sources, deduplicate exact UTC instants, and apply
/// exclusions. Each reader snapshots the set's sources when created. Adding a
/// source invalidates future cached queries; existing readers keep their snapshot.
/// No eager array cap is imposed on this native Iter.
///
/// ```mbt check
/// test {
///   let set = @date.rruleset(cache=true)
///   set.rrule(@date.rrule(@date.Daily, @date.datetime(2024, 1, 1), count=3))
///   set.exdate(@date.datetime(2024, 1, 2))
///   assert_eq(set.iter().to_array().map(value => value.day()), [1, 3])
/// }
/// ```
pub fn RRuleSet::iter(self : RRuleSet) -> Iter[DateTime] {
  let snapshot = self.snapshot()
  match self.cache {
    Some(cache) => cache.iterator(() => snapshot.stream(None, false))
    None => snapshot.stream(None, false)
  }
}

///|
/// Lazily yield set occurrences after `value`. Nonpositive count gives an
/// empty iterator; omitting count consumes through the sources' natural end.
pub fn RRuleSet::iter_after(
  self : RRuleSet,
  value : DateTime,
  count? : Int32,
  inc~ : Bool = false,
) -> Iter[DateTime] {
  if count is Some(limit) && limit <= 0 {
    return Iter::empty()
  }
  let target = rruleset_instant(value)
  let values = match self.cache {
    Some(_) =>
      self
      .iter()
      .filter(candidate => {
        if inc {
          rruleset_instant(candidate) >= target
        } else {
          rruleset_instant(candidate) > target
        }
      })
    None => self.snapshot().stream(Some(value), inc)
  }
  match count {
    Some(limit) => values.take(limit)
    None => values
  }
}
