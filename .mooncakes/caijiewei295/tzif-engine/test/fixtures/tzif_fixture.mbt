// Minimal TZif v2/v3 fixture builder.  It deliberately emits both data blocks
// so parser tests exercise the v1 compatibility skip as well as the v2+ body.

///|
pub(all) struct FixtureType {
  utoff : Int
  is_dst : Bool
  abbr_index : Int
}

///|
pub(all) struct FixtureTransition {
  utc_time : Int64
  type_index : Byte
}

///|
/// A leap correction record for fixture data blocks.
pub(all) struct FixtureLeapSecond {
  transition_time : Int64
  correction : Int
}

///|
pub(all) struct FixtureFile {
  bytes : Bytes
  second_header_offset : Int
  second_body_offset : Int
  second_index_offset : Int
  second_ttinfo_offset : Int
  second_leap_offset : Int
  second_standard_indicator_offset : Int
  second_utc_indicator_offset : Int
  footer_offset : Int
}

///|
fn append_u32_be(out : Array[Byte], value : UInt) -> Unit {
  let value = value.reinterpret_as_int()
  out.push(((value >> 24) & 0xff).to_byte())
  out.push(((value >> 16) & 0xff).to_byte())
  out.push(((value >> 8) & 0xff).to_byte())
  out.push((value & 0xff).to_byte())
}

///|
fn append_i32_be(out : Array[Byte], value : Int) -> Unit {
  append_u32_be(out, value.reinterpret_as_uint())
}

///|
fn append_i64_be(out : Array[Byte], value : Int64) -> Unit {
  let value = value.reinterpret_as_uint64()
  for shift in [56, 48, 40, 32, 24, 16, 8, 0] {
    out.push(((value >> shift) & 0xffUL).to_byte())
  }
}

///|
fn append_header(
  out : Array[Byte],
  version : Byte,
  standard_indicator_count : Int,
  utc_indicator_count : Int,
  leap_count : Int,
  transition_count : Int,
  type_count : Int,
  designation_count : Int,
) -> Unit {
  out.append([b'T', b'Z', b'i', b'f', version])
  for _ in 0..<15 {
    out.push(b'\x00')
  }
  append_u32_be(out, utc_indicator_count.reinterpret_as_uint())
  append_u32_be(out, standard_indicator_count.reinterpret_as_uint())
  append_u32_be(out, leap_count.reinterpret_as_uint())
  append_u32_be(out, transition_count.reinterpret_as_uint())
  append_u32_be(out, type_count.reinterpret_as_uint())
  append_u32_be(out, designation_count.reinterpret_as_uint())
}

///|
fn append_types(out : Array[Byte], types : Array[FixtureType]) -> Unit {
  for time_type in types {
    append_i32_be(out, time_type.utoff)
    out.push(if time_type.is_dst { b'\x01' } else { b'\x00' })
    out.push(time_type.abbr_index.to_byte())
  }
}

///|
fn append_designations(out : Array[Byte], designations : Bytes) -> Unit {
  for byte in designations {
    out.push(byte)
  }
}

///|
fn append_v1_leaps(
  out : Array[Byte],
  leap_seconds : Array[FixtureLeapSecond],
) -> Unit {
  for leap in leap_seconds {
    append_i32_be(out, leap.transition_time.to_int())
    append_i32_be(out, leap.correction)
  }
}

///|
fn append_v2_leaps(
  out : Array[Byte],
  leap_seconds : Array[FixtureLeapSecond],
) -> Unit {
  for leap in leap_seconds {
    append_i64_be(out, leap.transition_time)
    append_i32_be(out, leap.correction)
  }
}

///|
fn append_indicators(out : Array[Byte], indicators : Array[Bool]?) -> Unit {
  match indicators {
    None => ()
    Some(values) =>
      for value in values {
        out.push(if value { b'\x01' } else { b'\x00' })
      }
  }
}

///|
fn fits_signed_32(value : Int64) -> Bool {
  value >= -2_147_483_648L && value <= 2_147_483_647L
}

///|
fn v1_compatible_transitions(
  transitions : Array[FixtureTransition],
) -> Array[FixtureTransition] {
  let compatible : Array[FixtureTransition] = []
  for transition in transitions {
    if fits_signed_32(transition.utc_time) {
      compatible.push(transition)
    }
  }
  compatible
}

///|
fn v1_compatible_leaps(
  leap_seconds : Array[FixtureLeapSecond],
) -> Array[FixtureLeapSecond] {
  let compatible : Array[FixtureLeapSecond] = []
  for leap in leap_seconds {
    if fits_signed_32(leap.transition_time) {
      compatible.push(leap)
    }
  }
  compatible
}

///|
fn is_gregorian_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
/// Generate format-valid synthetic positive leap records at UTC year ends.
/// They are parser fixtures, not a claim about the historical IERS table.
fn generated_leap_seconds(count : Int) -> Array[FixtureLeapSecond] {
  let values : Array[FixtureLeapSecond] = []
  let mut posix_boundary = 94_694_400L // 1973-01-01T00:00:00Z
  let mut following_year = 1973
  for index in 0..<count {
    values.push({
      transition_time: posix_boundary + index.to_int64(),
      correction: index + 1,
    })
    let days = if is_gregorian_leap_year(following_year) { 366L } else { 365L }
    posix_boundary = posix_boundary + days * 86_400L
    following_year = following_year + 1
  }
  values
}

///|
fn append_v1_body(
  out : Array[Byte],
  transitions : Array[FixtureTransition],
  types : Array[FixtureType],
  designations : Bytes,
  leap_seconds : Array[FixtureLeapSecond],
  standard_indicators : Array[Bool]?,
  utc_indicators : Array[Bool]?,
) -> Unit {
  for transition in transitions {
    append_i32_be(out, transition.utc_time.to_int())
  }
  for transition in transitions {
    out.push(transition.type_index)
  }
  append_types(out, types)
  append_designations(out, designations)
  append_v1_leaps(out, leap_seconds)
  append_indicators(out, standard_indicators)
  append_indicators(out, utc_indicators)
}

///|
fn append_v2_body(
  out : Array[Byte],
  transitions : Array[FixtureTransition],
  types : Array[FixtureType],
  designations : Bytes,
  leap_seconds : Array[FixtureLeapSecond],
  standard_indicators : Array[Bool]?,
  utc_indicators : Array[Bool]?,
) -> Unit {
  for transition in transitions {
    append_i64_be(out, transition.utc_time)
  }
  for transition in transitions {
    out.push(transition.type_index)
  }
  append_types(out, types)
  append_designations(out, designations)
  append_v2_leaps(out, leap_seconds)
  append_indicators(out, standard_indicators)
  append_indicators(out, utc_indicators)
}

///|
/// Construct a complete TZif v2 or v3 byte sequence.
///
/// `designations` must include every required NUL terminator.  The builder
/// leaves malformed semantic combinations available to negative tests, while
/// always producing a structurally complete pair of data blocks.
pub fn build(
  version~ : Byte,
  types : Array[FixtureType],
  transitions : Array[FixtureTransition],
  designations : String,
  v1_leap_records? : Int = 0,
  leap_seconds? : Array[FixtureLeapSecond]? = None,
  standard_indicators? : Array[Bool]? = None,
  utc_indicators? : Array[Bool]? = None,
  footer? : String = "",
) -> FixtureFile {
  let out : Array[Byte] = Array::new()
  let designation_bytes = @utf8.encode(designations)
  let leap_seconds = match leap_seconds {
    Some(values) => values
    None => generated_leap_seconds(v1_leap_records)
  }
  // The compatibility block may contain a contiguous representable subset,
  // but it must never silently wrap 64-bit v2+ values into unrelated i32
  // timestamps.
  let v1_transitions = v1_compatible_transitions(transitions)
  let v1_leap_seconds = v1_compatible_leaps(leap_seconds)
  let standard_indicator_count = match standard_indicators {
    None => 0
    Some(values) => values.length()
  }
  let utc_indicator_count = match utc_indicators {
    None => 0
    Some(values) => values.length()
  }
  append_header(
    out,
    version,
    standard_indicator_count,
    utc_indicator_count,
    v1_leap_seconds.length(),
    v1_transitions.length(),
    types.length(),
    designation_bytes.length(),
  )
  append_v1_body(
    out, v1_transitions, types, designation_bytes, v1_leap_seconds, standard_indicators,
    utc_indicators,
  )

  let second_header_offset = out.length()
  append_header(
    out,
    version,
    standard_indicator_count,
    utc_indicator_count,
    leap_seconds.length(),
    transitions.length(),
    types.length(),
    designation_bytes.length(),
  )
  let second_body_offset = out.length()
  let second_index_offset = second_body_offset + transitions.length() * 8
  let second_ttinfo_offset = second_index_offset + transitions.length()
  let second_leap_offset = second_ttinfo_offset +
    types.length() * 6 +
    designation_bytes.length()
  let second_standard_indicator_offset = second_leap_offset +
    leap_seconds.length() * 12
  let second_utc_indicator_offset = second_standard_indicator_offset +
    standard_indicator_count
  append_v2_body(
    out, transitions, types, designation_bytes, leap_seconds, standard_indicators,
    utc_indicators,
  )

  let footer_offset = out.length()
  out.push(b'\n')
  append_designations(out, @utf8.encode(footer))
  out.push(b'\n')
  {
    bytes: Bytes::from_array(out),
    second_header_offset,
    second_body_offset,
    second_index_offset,
    second_ttinfo_offset,
    second_leap_offset,
    second_standard_indicator_offset,
    second_utc_indicator_offset,
    footer_offset,
  }
}

///|
pub fn fixed_offset_v2(utoff : Int, abbr : String) -> FixtureFile {
  build(
    version=b'2',
    [{ utoff, is_dst: false, abbr_index: 0 }],
    [],
    abbr + "\u{0000}",
  )
}

///|
pub fn fixed_offset_v3(
  utoff : Int,
  abbr : String,
  footer? : String = "",
) -> FixtureFile {
  build(
    version=b'3',
    [{ utoff, is_dst: false, abbr_index: 0 }],
    [],
    abbr + "\u{0000}",
    footer~,
  )
}

///|
pub fn bytes_with_byte_at(
  file : FixtureFile,
  offset : Int,
  value : Byte,
) -> Bytes {
  if offset < 0 || offset >= file.bytes.length() {
    return file.bytes
  }
  let bytes = file.bytes.to_array()
  bytes[offset] = value
  Bytes::from_array(bytes)
}

///|
pub fn truncated(file : FixtureFile, length : Int) -> Bytes {
  if length <= 0 {
    return b""
  }
  if length >= file.bytes.length() {
    return file.bytes
  }
  let bytes = file.bytes.to_array()
  Bytes::from_array(bytes[:length])
}
