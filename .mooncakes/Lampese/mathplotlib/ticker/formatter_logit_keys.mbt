///|
/// An immutable numeric value with explicit object identity for NaN membership.
pub struct LogitKey {
  priv number : ScalarNumber
  priv numeric_hash : Int64
}

///|
pub fn LogitKey::new(value : ScalarNumber) -> LogitKey {
  { number: value, numeric_hash: eng_prefix_hash(value), }
}

///|
pub fn LogitKey::value(self : LogitKey) -> ScalarNumber {
  self.number
}

///|
pub impl Eq for LogitKey with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub extend LogitKey with Eq::{equal, not_equal}

///|
pub impl @debug.Debug for LogitKey with fn to_repr(self) {
  @debug.Repr::Repr(("LogitKey", self.number))
}

///|
pub extend LogitKey with @debug.Debug::{to_repr}

///|
// LogitFormatter only clears and adds to this set. There are no deleted slots.
// Its lookup, clean rehash, growth trigger and physical reinsertion order follow
// CPython 3.12.14 setobject.c, not the engineering dictionary's probing.
priv struct LogitLabelled {
  mut table : Array[LogitKey?]
  mut used : Int32
}

///|
fn LogitLabelled::new() -> LogitLabelled {
  { table: Array::make(8, None), used: 0, }
}

///|
fn LogitLabelled::clear(self : LogitLabelled) -> Unit {
  self.table = Array::make(8, None)
  self.used = 0
}

///|
fn LogitLabelled::find(
  self : LogitLabelled,
  key : LogitKey,
) -> (Int32, Bool) raise @core.DataError {
  let mask = (self.table.length() - 1).to_uint64()
  let mut perturb = key.numeric_hash.reinterpret_as_uint64()
  let mut slot = perturb & mask
  while true {
    let probes = if slot + 9UL <= mask { 9 } else { 0 }
    for offset in 0..<(probes + 1) {
      let index = slot.to_int() + offset
      match self.table[index] {
        None => return (index, false)
        Some(stored) =>
          if stored.numeric_hash == key.numeric_hash &&
            (
              physical_equal(stored, key) ||
              eng_prefix_compare(stored.number, key.number) == Some(0)
            ) {
            return (index, true)
          }
      }
    }
    perturb = perturb >> 5
    slot = (slot * 5UL + 1UL + perturb) & mask
  } nobreak {
    (-1, false)
  }
}

///|
fn LogitLabelled::insert_clean(self : LogitLabelled, key : LogitKey) -> Unit {
  let mask = (self.table.length() - 1).to_uint64()
  let mut perturb = key.numeric_hash.reinterpret_as_uint64()
  let mut slot = perturb & mask
  while true {
    let probes = if slot + 9UL <= mask { 9 } else { 0 }
    for offset in 0..<(probes + 1) {
      let index = slot.to_int() + offset
      if self.table[index] is None {
        self.table[index] = Some(key)
        return
      }
    }
    perturb = perturb >> 5
    slot = (slot * 5UL + 1UL + perturb) & mask
  }
}

///|
fn LogitLabelled::resize(
  self : LogitLabelled,
  minimum : Int64,
) -> Unit raise @core.DataError {
  let mut size = 8
  while Int64::from_int(size) <= minimum {
    if size == 1073741824 {
      raise @core.DataError::InvalidTicks(
        message="ResourceError: logit label set table exceeds Array addressability",
      )
    }
    size *= 2
  }
  let old = self.table
  self.table = Array::make(size, None)
  for entry in old {
    if entry is Some(key) {
      self.insert_clean(key)
    }
  }
}

///|
fn LogitLabelled::add(
  self : LogitLabelled,
  key : LogitKey,
) -> Unit raise @core.DataError {
  let (slot, found) = self.find(key)
  if found {
    return
  }
  self.table[slot] = Some(key)
  self.used += 1
  if Int64::from_int(self.used) * 5L >=
    Int64::from_int(self.table.length() - 1) * 3L {
    self.resize(
      Int64::from_int(self.used) * (if self.used > 50000 { 2L } else { 4L }),
    )
  }
}

///|
fn LogitLabelled::contains(
  self : LogitLabelled,
  key : LogitKey,
) -> Bool raise @core.DataError {
  self.find(key).1
}

///|
fn LogitLabelled::keys(self : LogitLabelled) -> Array[LogitKey] {
  let result = Array(capacity=self.used)
  for entry in self.table {
    if entry is Some(key) {
      result.push(key)
    }
  }
  result
}

///|
fn logit_format_ticks_keys(
  base : BaseFormatter,
  keys : Array[LogitKey],
) -> Array[String] raise @core.DataError {
  let state = match base.kind {
    Logit(state) => state
    _ => abort("invalid LogitFormatter kind")
  }
  let input = LogitInput::from_keys(keys)
  logit_named_prepare(base, state, input)
  let labels : Array[String] = []
  let mut index = 0
  while index < input.length() {
    labels.push(logit_named_call(base, state, input.key_at(index), Some(index)))
    index += 1
  }
  labels
}
