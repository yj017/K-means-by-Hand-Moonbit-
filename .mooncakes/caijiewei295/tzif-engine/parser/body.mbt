// TZif v2/v3 data-block parser (RFC 9636 section 3.2).

///|
/// The parsed contents of one TZif data block and the exact footer boundary.
pub(all) struct ParsedBody {
  time_types : Array[@types.TimeType]
  transitions : Array[@types.Transition]
  leap_seconds : Array[@types.LeapSecond]
  standard_indicators : Array[Bool]?
  utc_indicators : Array[Bool]?
  end_offset : Int
}

///|
// Internal representation of a `ttinfo` record while its abbreviation is
// still stored in the designation byte array.
priv struct RawTimeType {
  utoff : Int
  is_dst : Bool
  designation_index : Int
}

///|
/// Read a big-endian signed 64-bit integer from a verified data block.
fn read_i64_be(data : Bytes, offset : Int) -> Int64 {
  let unsigned = (data[offset].to_uint64() << 56) |
    (data[offset + 1].to_uint64() << 48) |
    (data[offset + 2].to_uint64() << 40) |
    (data[offset + 3].to_uint64() << 32) |
    (data[offset + 4].to_uint64() << 24) |
    (data[offset + 5].to_uint64() << 16) |
    (data[offset + 6].to_uint64() << 8) |
    data[offset + 7].to_uint64()
  unsigned.reinterpret_as_int64()
}

///|
/// Read a big-endian signed 32-bit integer without relying on target `Int`
/// width.  TZif offsets are subsequently range-checked before conversion.
fn read_i32_be(data : Bytes, offset : Int) -> Int {
  let unsigned = (data[offset].to_int64() << 24) |
    (data[offset + 1].to_int64() << 16) |
    (data[offset + 2].to_int64() << 8) |
    data[offset + 3].to_int64()
  let signed = if unsigned >= 0x80000000L {
    unsigned - 0x100000000L
  } else {
    unsigned
  }
  signed.to_int()
}

///|
/// Return the NUL-terminated designation for a verified `ttinfo` index.
///
/// RFC 9636 writers use three to six ASCII alphanumeric, '+' or '-' bytes.
/// For compatibility with older TZif files, this reader also retains other
/// printable ASCII designations losslessly, including the explicitly
/// permitted empty designation. Non-ASCII and control-byte designations are
/// rejected because the public String model cannot preserve them losslessly.
fn parse_designation(
  data : Bytes,
  designations_start : Int,
  designations_end : Int,
  designation_index : Int,
) -> @types.TzifResult[String] {
  let designations_length = designations_end - designations_start
  if designation_index < 0 || designation_index >= designations_length {
    return Err(
      InvalidTransitionTable(
        "time type designation index \{designation_index} is out of range",
      ),
    )
  }

  let start = designations_start + designation_index
  let mut end = start
  while end < designations_end && data[end] != b'\x00' {
    let byte = data[end]
    if byte < b' ' || byte > b'~' {
      return Err(
        InvalidTransitionTable(
          "time type designation is outside the lossless ASCII compatibility boundary",
        ),
      )
    }
    end = end + 1
  }
  if end == designations_end {
    return Err(
      InvalidTransitionTable("time type designation is not NUL-terminated"),
    )
  }
  Ok(@utf8.decode_lossy(data[start:end]))
}

///|
/// Parse a TZif indicator array.
///
/// TZif permits an omitted array (count zero), which is distinct from an
/// explicitly present all-false array. Preserve that distinction for callers.
fn parse_indicator_bytes(
  data : Bytes,
  offset : Int,
  count : Int,
  kind : String,
) -> @types.TzifResult[Array[Bool]?] {
  if count == 0 {
    return Ok(None)
  }
  let indicators = Array::makei(count, fn(_) { false })
  for i in 0..<count {
    let flag = data[offset + i]
    if flag != b'\x00' && flag != b'\x01' {
      return Err(
        InvalidTransitionTable(
          "TZif \{kind} indicator at index \{i} must be 0 or 1",
        ),
      )
    }
    indicators[i] = flag == b'\x01'
  }
  Ok(Some(indicators))
}

///|
/// Verify the reader's lossless compatibility boundary for the entire
/// designation array. Even an unreferenced unsupported suffix must not be
/// retained as apparently valid text.
fn validate_designation_bytes(
  data : Bytes,
  start : Int,
  end : Int,
) -> @types.TzifResult[Unit] {
  for i in start..<end {
    let byte = data[i]
    if byte != b'\x00' && (byte < b' ' || byte > b'~') {
      return Err(
        InvalidTransitionTable(
          "TZif designation character array is outside the lossless ASCII compatibility boundary",
        ),
      )
    }
  }
  Ok(())
}

///|
/// Convert a TZif leap occurrence to the corresponding POSIX midnight at the
/// start of the following UTC month. The occurrence is UNIX leap time, so the
/// correction in effect before this record must be removed first.
fn leap_posix_boundary(occurrence : Int64, previous_correction : Int) -> Int64? {
  let correction = previous_correction.to_int64()
  if correction < 0L && occurrence > 9_223_372_036_854_775_807L + correction {
    return None
  }
  let boundary = occurrence - correction
  if boundary < 0L {
    None
  } else {
    Some(boundary)
  }
}

///|
/// Return whether a nonnegative POSIX timestamp is midnight on the first day
/// of a Gregorian month. This is the instant immediately after a leap second
/// inserted or deleted at the end of the preceding UTC month.
fn is_utc_month_boundary(timestamp : Int64) -> Bool {
  if timestamp % 86_400L != 0L {
    return false
  }
  let days = timestamp / 86_400L
  // Howard Hinnant's civil-from-days decomposition, shifted from the POSIX
  // epoch to the proleptic Gregorian civil epoch. Only the day is needed.
  let shifted = days + 719_468L
  let era = shifted / 146_097L
  let day_of_era = shifted - era * 146_097L
  let year_of_era = (
      day_of_era -
      day_of_era / 1_460L +
      day_of_era / 36_524L -
      day_of_era / 146_096L
    ) /
    365L
  let day_of_year = day_of_era -
    (365L * year_of_era + year_of_era / 4L - year_of_era / 100L)
  let month_prime = (5L * day_of_year + 2L) / 153L
  let day = day_of_year - (153L * month_prime + 2L) / 5L + 1L
  day == 1L
}

///|
/// Parse a v2/v3 data block starting at `offset`.
///
/// The result retains the complete `ttinfo` table (including type zero), keeps
/// transition type indices rather than copying their fields, and records the
/// exact byte at which the mandatory TZif footer begins.
pub fn parse_body(
  data : Bytes,
  header : TzifHeader,
  offset : Int,
) -> @types.TzifResult[ParsedBody] {
  let end_offset = match data_block_end(data, header, offset, 8) {
    Ok(value) => value
    Err(error) => return Err(error)
  }

  // Every count below is safe to narrow after data_block_end established that
  // its corresponding bytes exist in an Int-indexed Bytes object.
  let transition_count = header.timecnt.reinterpret_as_int()
  let type_count = header.typecnt.reinterpret_as_int()
  let designation_count = header.charcnt.reinterpret_as_int()
  let leap_count = header.leapcnt.reinterpret_as_int()
  let std_count = header.isstdcnt.reinterpret_as_int()
  let ut_count = header.isutcnt.reinterpret_as_int()
  if std_count != 0 && std_count != type_count {
    return Err(
      InvalidTransitionTable(
        "TZif ttisstd indicator count must be zero or equal time type count",
      ),
    )
  }
  if ut_count != 0 && ut_count != type_count {
    return Err(
      InvalidTransitionTable(
        "TZif ttisut indicator count must be zero or equal time type count",
      ),
    )
  }
  let mut pos = offset

  let transition_times = Array::makei(transition_count, fn(_) { 0L })
  let mut previous_transition = 0L
  for i in 0..<transition_count {
    let utc_time = read_i64_be(data, pos)
    if i > 0 && utc_time <= previous_transition {
      return Err(
        InvalidTransitionTable("transition times must be strictly increasing"),
      )
    }
    transition_times[i] = utc_time
    previous_transition = utc_time
    pos = pos + 8
  }

  let transition_indices = Array::makei(transition_count, fn(_) { b'\x00' })
  for i in 0..<transition_count {
    let type_index = data[pos].to_int()
    if type_index >= type_count {
      return Err(
        InvalidTransitionTable(
          "transition type index \{type_index} is out of range",
        ),
      )
    }
    transition_indices[i] = data[pos]
    pos = pos + 1
  }

  let raw_time_types = Array::makei(type_count, fn(_) {
    RawTimeType::{ utoff: 0, is_dst: false, designation_index: 0 }
  })
  for i in 0..<type_count {
    let utoff = read_i32_be(data, pos)
    pos = pos + 4
    // RFC 9636 makes only INT32_MIN invalid. The conventional
    // [-89999, 93599] interoperability range is a SHOULD, so values outside
    // it remain available to callers instead of being promoted to a parser
    // MUST.
    if utoff == -2_147_483_647 - 1 {
      return Err(
        InvalidTransitionTable("TZif UTC offset must not be -2147483648"),
      )
    }
    let dst_flag = data[pos]
    pos = pos + 1
    if dst_flag != b'\x00' && dst_flag != b'\x01' {
      return Err(
        InvalidTransitionTable(
          "time type DST flag at index \{i} must be 0 or 1",
        ),
      )
    }
    let designation_index = data[pos].to_int()
    pos = pos + 1
    raw_time_types[i] = {
      utoff,
      is_dst: dst_flag == b'\x01',
      designation_index,
    }
  }

  let designations_start = pos
  let designations_end = designations_start + designation_count
  // RFC 8536 requires the designation character array to end in NUL. This
  // also guarantees each valid designation search remains bounded.
  if data[designations_end - 1] != b'\x00' {
    return Err(
      InvalidTransitionTable("TZif designation character array must end in NUL"),
    )
  }
  match validate_designation_bytes(data, designations_start, designations_end) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let time_types = Array::makei(type_count, fn(_) {
    @types.TimeType::{ utoff: 0, is_dst: false, abbr: "" }
  })
  for i in 0..<type_count {
    let raw = raw_time_types[i]
    let abbr = match
      parse_designation(
        data,
        designations_start,
        designations_end,
        raw.designation_index,
      ) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    time_types[i] = { utoff: raw.utoff, is_dst: raw.is_dst, abbr }
  }
  pos = designations_end

  let leap_seconds = Array::makei(leap_count, fn(_) {
    @types.LeapSecond::{ transition_time: 0L, correction: 0 }
  })
  let mut previous_leap = 0L
  let mut previous_correction = 0
  for i in 0..<leap_count {
    let leap_time = read_i64_be(data, pos)
    if i == 0 && leap_time < 0L {
      return Err(
        InvalidTransitionTable(
          "first leap-second occurrence must be nonnegative",
        ),
      )
    }
    if i > 0 &&
      (leap_time <= previous_leap || leap_time - previous_leap < 2_419_199L) {
      return Err(
        InvalidTransitionTable(
          "adjacent leap-second occurrences must be at least 2419199 seconds apart",
        ),
      )
    }
    match leap_posix_boundary(leap_time, previous_correction) {
      Some(boundary) =>
        if !is_utc_month_boundary(boundary) {
          return Err(
            InvalidTransitionTable(
              "leap-second occurrence must be at the end of a UTC month",
            ),
          )
        }
      None =>
        return Err(
          InvalidTransitionTable(
            "leap-second occurrence cannot be represented as a POSIX UTC boundary",
          ),
        )
    }
    pos = pos + 8
    let correction = read_i32_be(data, pos)
    pos = pos + 4
    if i == 0 && correction != 1 && correction != -1 {
      return Err(
        InvalidTransitionTable(
          "first leap-second correction must be either 1 or -1",
        ),
      )
    }
    if i > 0 {
      let correction_delta = correction.to_int64() -
        previous_correction.to_int64()
      if correction_delta != 1L && correction_delta != -1L {
        return Err(
          InvalidTransitionTable(
            "adjacent leap-second corrections must differ by exactly 1",
          ),
        )
      }
    }
    leap_seconds[i] = { transition_time: leap_time, correction }
    previous_leap = leap_time
    previous_correction = correction
  }

  let standard_indicators = match
    parse_indicator_bytes(data, pos, std_count, "standard/wall") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  pos = pos + std_count
  let utc_indicators = match
    parse_indicator_bytes(data, pos, ut_count, "UT/local") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  pos = pos + ut_count
  match utc_indicators {
    None => ()
    Some(utc_values) =>
      for i in 0..<utc_values.length() {
        if utc_values[i] {
          match standard_indicators {
            Some(standard_values) =>
              if !standard_values[i] {
                return Err(
                  InvalidTransitionTable(
                    "ttisut=1 requires the corresponding ttisstd indicator to be 1",
                  ),
                )
              }
            None =>
              return Err(
                InvalidTransitionTable(
                  "ttisut=1 requires an explicit corresponding ttisstd=1 indicator",
                ),
              )
          }
        }
      }
  }

  if pos != end_offset {
    return Err(InvalidTransitionTable("internal TZif data-block size mismatch"))
  }

  let transitions = Array::makei(transition_count, fn(_) {
    @types.Transition::{ utc_time: 0L, type_index: 0 }
  })
  for i in 0..<transition_count {
    transitions[i] = {
      utc_time: transition_times[i],
      type_index: transition_indices[i].to_int(),
    }
  }

  Ok({
    time_types,
    transitions,
    leap_seconds,
    standard_indicators,
    utc_indicators,
    end_offset,
  })
}
