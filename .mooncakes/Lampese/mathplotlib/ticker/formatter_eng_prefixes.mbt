///|
/// A numeric dictionary key with its original scalar origin and object identity.
pub struct EngPrefixKey {
  priv number : ScalarNumber
  priv numeric_hash : Int64
}

///|
pub impl @debug.Debug for EngPrefixKey with fn to_repr(self) {
  @debug.Repr::Repr(("EngPrefixKey", self.number))
}

///|
pub extend EngPrefixKey with @debug.Debug::{to_repr}

///|
pub impl Eq for EngPrefixKey with fn equal(self, other) {
  physical_equal(self, other)
}

///|
pub extend EngPrefixKey with Eq::{equal, not_equal}

///|
fn eng_prefix_hash(number : ScalarNumber) -> Int64 {
  let modulus = @bigint.BigInt::from_int64(2305843009213693951L)
  let (magnitude, negative) = match number {
    Integer(value) =>
      (
        if value < @bigint.BigInt::from_int(0) {
          value.neg()
        } else {
          value
        },
        value < @bigint.BigInt::from_int(0),
      )
    Boolean(value) | NumpyBool(value) =>
      (@bigint.BigInt::from_int(if value { 1 } else { 0 }), false)
    NumpyInt64(value) => {
      let value = @bigint.BigInt::from_int64(value)
      (
        if value < @bigint.BigInt::from_int(0) {
          value.neg()
        } else {
          value
        },
        value < @bigint.BigInt::from_int(0),
      )
    }
    Number(value) | NumpyFloat64(value) => {
      if value.is_nan() {
        return 0L
      }
      if value.is_inf() {
        return if value < 0.0 { -314159L } else { 314159L }
      }
      let bits = value.reinterpret_as_uint64() & 0x7fffffffffffffffUL
      let biased = ((bits >> 52) & 0x7ffUL).to_int()
      let fraction = bits & 0xfffffffffffffUL
      let significand = if biased == 0 {
        fraction
      } else {
        fraction | 0x10000000000000UL
      }
      let exponent = if biased == 0 { -1074 } else { biased - 1075 }
      // 2**61 == 1 modulo P, including negative binary exponents.
      let rotation = (exponent % 61 + 61) % 61
      (
        @bigint.BigInt::from_uint64(significand) *
        (@bigint.BigInt::from_int(1) << rotation),
        value < 0.0,
      )
    }
  }
  let magnitude = (magnitude % modulus).to_int64()
  let signed = if negative { -magnitude } else { magnitude }
  if signed == -1L {
    -2L
  } else {
    signed
  }
}

///|
pub fn EngPrefixKey::new(value : ScalarNumber) -> EngPrefixKey {
  { number: value, numeric_hash: eng_prefix_hash(value), }
}

///|
pub fn EngPrefixKey::value(self : EngPrefixKey) -> ScalarNumber {
  self.number
}

///|
fn eng_prefix_compare(
  left : ScalarNumber,
  right : ScalarNumber,
) -> Int32? raise @core.DataError {
  // NumPy's bool scalar consumes a Python integer through C long, even for
  // comparisons. NumPy int64 instead keeps arbitrary Python integers exact.
  match (left, right) {
    (NumpyBool(_), Integer(_)) => ignore(scalar_numeric_int64(right))
    (Integer(_), NumpyBool(_)) => ignore(scalar_numeric_int64(left))
    _ => ()
  }
  scalar_numeric_compare(left, right)
}

///|
fn eng_prefix_less(
  left : ScalarNumber,
  right : ScalarNumber,
) -> Bool raise @core.DataError {
  eng_prefix_compare(left, right) == Some(-1)
}

///|
priv struct EngPrefixEntry {
  key : EngPrefixKey
  mut value : String
}

///|
/// An ordered numeric dictionary with CPython's combined-table probing.
pub struct EngPrefixes {
  priv mut entries : Array[EngPrefixEntry?]
  priv mut indices : Array[Int32]
  priv mut used : Int32
  priv mut usable : Int32
}

///|
pub fn EngPrefixes::new() -> EngPrefixes {
  { entries: [], indices: [], used: 0, usable: 0, }
}

///|
fn eng_prefix_table_size(minimum : Int32) -> Int32 {
  let mut size = 8
  while size < minimum {
    size *= 2
  }
  size
}

///|
fn eng_prefix_empty_slot(store : EngPrefixes, hash : Int64) -> Int32 {
  let mask = (store.indices.length() - 1).to_uint64()
  let mut perturb = hash.reinterpret_as_uint64()
  let mut slot = perturb & mask
  while store.indices[slot.to_int()] >= 0 {
    perturb = perturb >> 5
    slot = (slot * 5UL + perturb + 1UL) & mask
  }
  slot.to_int()
}

///|
fn eng_prefix_resize(store : EngPrefixes, size : Int32) -> Unit {
  let entries : Array[EngPrefixEntry?] = []
  for entry in store.entries {
    if entry is Some(_) {
      entries.push(entry)
    }
  }
  store.entries = entries
  store.indices = Array::make(size, -1)
  store.usable = size * 2 / 3 - store.used
  for index, item in entries {
    if item is Some(entry) {
      store.indices[eng_prefix_empty_slot(store, entry.key.numeric_hash)] = index
    }
  }
}

///|
fn eng_prefix_insert_absent(
  store : EngPrefixes,
  key : EngPrefixKey,
  value : String,
) -> Unit {
  if store.indices.is_empty() {
    eng_prefix_resize(store, 8)
  } else if store.usable == 0 {
    eng_prefix_resize(store, eng_prefix_table_size(store.used * 3))
  }
  let slot = eng_prefix_empty_slot(store, key.numeric_hash)
  store.indices[slot] = store.entries.length()
  store.entries.push(Some({ key, value, }))
  store.used += 1
  store.usable -= 1
}

///|
pub fn EngPrefixes::si() -> EngPrefixes {
  let store = EngPrefixes::new()
  for
    pair in [
      (-30, "q"),
      (-27, "r"),
      (-24, "y"),
      (-21, "z"),
      (-18, "a"),
      (-15, "f"),
      (-12, "p"),
      (-9, "n"),
      (-6, "µ"),
      (-3, "m"),
      (0, ""),
      (3, "k"),
      (6, "M"),
      (9, "G"),
      (12, "T"),
      (15, "P"),
      (18, "E"),
      (21, "Z"),
      (24, "Y"),
      (27, "R"),
      (30, "Q"),
    ] {
    eng_prefix_insert_absent(
      store,
      EngPrefixKey::new(ScalarNumber::Integer(@bigint.BigInt::from_int(pair.0))),
      pair.1,
    )
  }
  store
}

///|
pub fn EngPrefixes::length(self : EngPrefixes) -> Int32 {
  self.used
}

///|
pub fn EngPrefixes::keys(self : EngPrefixes) -> Array[EngPrefixKey] {
  let keys : Array[EngPrefixKey] = []
  for entry in self.entries {
    if entry is Some(entry) {
      keys.push(entry.key)
    }
  }
  keys
}

///|
pub fn EngPrefixes::copy(self : EngPrefixes) -> EngPrefixes {
  if self.used == 0 {
    return EngPrefixes::new()
  }
  // PyDict_Copy retains its physical indices while no more than one third of
  // the ordered entries have become tombstones; otherwise it compacts.
  if self.used >= self.entries.length() * 2 / 3 {
    return {
      entries: self.entries.map(item => {
        item.map(entry => { key: entry.key, value: entry.value, })
      }),
      indices: self.indices.copy(),
      used: self.used,
      usable: self.usable,
    }
  }
  let store = EngPrefixes::new()
  eng_prefix_resize(store, eng_prefix_table_size((self.used * 3 + 1) / 2))
  for item in self.entries {
    if item is Some(entry) {
      eng_prefix_insert_absent(store, entry.key, entry.value)
    }
  }
  store
}

///|
fn eng_prefix_find(
  store : EngPrefixes,
  key : EngPrefixKey,
) -> (Int32, Int32)? raise @core.DataError {
  if store.indices.is_empty() {
    return None
  }
  let mask = (store.indices.length() - 1).to_uint64()
  let mut perturb = key.numeric_hash.reinterpret_as_uint64()
  let mut slot = perturb & mask
  while true {
    let index = store.indices[slot.to_int()]
    if index == -1 {
      return None
    }
    if index >= 0 {
      let entry = store.entries[index].unwrap()
      if physical_equal(entry.key, key) ||
        (
          entry.key.numeric_hash == key.numeric_hash &&
          eng_prefix_compare(entry.key.number, key.number) == Some(0)
        ) {
        return Some((index, slot.to_int()))
      }
    }
    perturb = perturb >> 5
    slot = (slot * 5UL + perturb + 1UL) & mask
  } nobreak {
    None
  }
}

///|
pub fn EngPrefixes::set_key(
  self : EngPrefixes,
  key : EngPrefixKey,
  value : String,
) -> Unit raise @core.DataError {
  match eng_prefix_find(self, key) {
    Some((index, _)) => self.entries[index].unwrap().value = value
    None => eng_prefix_insert_absent(self, key, value)
  }
}

///|
pub fn EngPrefixes::get_key(
  self : EngPrefixes,
  key : EngPrefixKey,
) -> String? raise @core.DataError {
  eng_prefix_find(self, key).map(found => self.entries[found.0].unwrap().value)
}

///|
pub fn EngPrefixes::remove_key(
  self : EngPrefixes,
  key : EngPrefixKey,
) -> Bool raise @core.DataError {
  match eng_prefix_find(self, key) {
    Some((index, slot)) => {
      self.indices[slot] = -2
      self.entries[index] = None
      self.used -= 1
      true
    }
    None => false
  }
}

///|
pub fn EngPrefixes::set(
  self : EngPrefixes,
  key : ScalarNumber,
  value : String,
) -> Unit raise @core.DataError {
  self.set_key(EngPrefixKey::new(key), value)
}

///|
pub fn EngPrefixes::get(
  self : EngPrefixes,
  key : ScalarNumber,
) -> String? raise @core.DataError {
  self.get_key(EngPrefixKey::new(key))
}

///|
pub fn EngPrefixes::remove(
  self : EngPrefixes,
  key : ScalarNumber,
) -> Bool raise @core.DataError {
  self.remove_key(EngPrefixKey::new(key))
}

///|
fn eng_places_format(places : ScalarNumber?) -> String raise @core.DataError {
  let places = match places {
    None => return "g"
    Some(Integer(value)) => scalar_percent_integer_str(value)
    Some(NumpyInt64(value)) => value.to_string()
    Some(Boolean(value) | NumpyBool(value)) => if value { "1" } else { "0" }
    Some(Number(_) | NumpyFloat64(_)) =>
      raise @core.DataError::InvalidTicks(
        message="ValueError: Unknown format code 'd' for object of type 'float'",
      )
  }
  "." + places + "f"
}
