// Integration test over a real, checked-in IANA TZif file.  Unlike the
// compact synthetic fixtures, this validates the parser against the complete
// transition/type/indicator layout emitted by zic for America/New_York.

///|
fn golden_fnv1a64(data : Bytes) -> UInt64 {
  let mut fingerprint = 0xcbf29ce484222325UL
  for byte in data {
    fingerprint = (fingerprint ^ byte.to_uint64()) * 0x100000001b3UL
  }
  fingerprint
}

///|
fn golden_crc32(data : Bytes) -> UInt {
  let mut checksum = 0xffffffffU
  for byte in data {
    checksum = checksum ^ byte.to_uint()
    for _ in 0..<8 {
      checksum = if (checksum & 1U) == 1U {
        (checksum >> 1) ^ 0xedb88320U
      } else {
        checksum >> 1
      }
    }
  }
  checksum ^ 0xffffffffU
}

///|
fn assert_real_vector(
  timezone : @types.TzifData,
  utc_time : Int64,
  year~ : Int,
  month~ : Int,
  day~ : Int,
  hour~ : Int,
  minute~ : Int,
  second~ : Int,
  utoff~ : Int,
  is_dst~ : Bool,
  abbr~ : String,
) -> Unit raise {
  match @tzif.utc_to_local(timezone, utc_time) {
    Err(_) => fail("expected real New York conversion to succeed")
    Ok(local_time) => {
      assert_eq(local_time.year, year)
      assert_eq(local_time.month, month)
      assert_eq(local_time.day, day)
      assert_eq(local_time.hour, hour)
      assert_eq(local_time.minute, minute)
      assert_eq(local_time.second, second)
      assert_eq(local_time.utoff, utoff)
      assert_eq(local_time.is_dst, is_dst)
      assert_eq(local_time.abbr, abbr)
    }
  }
}

///|
fn real_active_offset(
  timezone : @types.TzifData,
  utc_time : Int64,
) -> @types.OffsetInfo raise {
  match @tzif.active_offset(timezone, utc_time) {
    Ok(value) => value
    Err(_) => fail("expected real New York offset lookup to succeed")
  }
}

///|
test "real IANA America New York TZif 2026b parses with complete metadata" {
  let bytes = @golden.america_new_york_2026b
  assert_eq(bytes.length(), 3552)
  assert_eq(bytes[0], b'T')
  assert_eq(bytes[1], b'Z')
  assert_eq(@golden.america_new_york_tzdb_release, "2026b")
  assert_eq(
    @golden.america_new_york_sha256, "e9ed07d7bee0c76a9d442d091ef1f01668fee7c4f26014c0a868b19fe6c18a95",
  )
  assert_eq(@golden.america_new_york_byte_length, bytes.length())
  // The dependency set has no SHA-256 package. These independent full-content
  // fingerprints catch byte drift on every MoonBit target; release CI must
  // additionally compare the reconstructed bytes with the SHA-256 above.
  assert_eq(golden_fnv1a64(bytes), 0x90a0aefaed6eecf8UL)
  assert_eq(golden_crc32(bytes), 0xbd8efaf3U)
  let timezone = vector_load_ok(bytes)
  let summary = @tzif.diagnostics(timezone)
  assert_eq(summary.version, b'2')
  assert_eq(summary.transition_count, 236)
  assert_eq(summary.time_type_count, 6)
  assert_eq(summary.first_transition, Some(-2_717_650_800L))
  assert_eq(summary.last_transition, Some(2_140_668_000L))
  assert_true(summary.has_posix_footer)
  match timezone.standard_indicators {
    Some(values) => assert_eq(values.length(), 6)
    None => fail("real TZif must retain ttisstd indicators")
  }
  match timezone.utc_indicators {
    Some(values) => assert_eq(values.length(), 6)
    None => fail("real TZif must retain ttisut indicators")
  }
}

///|
test "real IANA golden rejects truncated and corrupt source bytes" {
  let bytes = @golden.america_new_york_2026b
  let truncated = Bytes::from_array(bytes.to_array()[:bytes.length() - 1])
  match @tzif.load(truncated) {
    Err(_) => ()
    Ok(_) => fail("truncated real TZif must be rejected")
  }
  let corrupt_magic = bytes.to_array()
  corrupt_magic[0] = b'X'
  match @tzif.load(Bytes::from_array(corrupt_magic)) {
    Err(_) => ()
    Ok(_) => fail("real TZif with corrupt magic must be rejected")
  }
}

///|
test "real New York historical 1900 1945 and 1970 oracle points" {
  let timezone = vector_load_ok(@golden.america_new_york_2026b)
  // Generated with Python 3.10.12 zoneinfo and glibc zdump 2.35 against the
  // audited system tzdb 2026b recorded by the golden package.
  assert_real_vector(
    timezone,
    -2_208_945_600L,
    year=1900,
    month=1,
    day=1,
    hour=7,
    minute=0,
    second=0,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
  assert_real_vector(
    timezone,
    -769_395_601L,
    year=1945,
    month=8,
    day=14,
    hour=18,
    minute=59,
    second=59,
    utoff=-14_400,
    is_dst=true,
    abbr="EWT",
  )
  assert_real_vector(
    timezone,
    -769_395_600L,
    year=1945,
    month=8,
    day=14,
    hour=19,
    minute=0,
    second=0,
    utoff=-14_400,
    is_dst=true,
    abbr="EPT",
  )
  match @tzif.transition_detail(timezone, 50) {
    Ok(detail) => {
      assert_eq(detail.utc_time, -769_395_600L)
      assert_eq(detail.before.abbr, "EWT")
      assert_eq(detail.after.abbr, "EPT")
      assert_eq(detail.before.utoff, -14_400)
      assert_eq(detail.after.utoff, -14_400)
      assert_eq(detail.offset_change, 0)
      match detail.clock_change {
        NoClockChange => ()
        _ => fail("1945 EWT-to-EPT transition must not move the wall clock")
      }
    }
    Err(_) => fail("expected the real 1945 abbreviation transition")
  }
  assert_real_vector(
    timezone,
    0L,
    year=1969,
    month=12,
    day=31,
    hour=19,
    minute=0,
    second=0,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
}

///|
test "real New York 2026 transition boundaries and overlap oracle" {
  let timezone = vector_load_ok(@golden.america_new_york_2026b)
  assert_real_vector(
    timezone,
    1_772_953_199L,
    year=2026,
    month=3,
    day=8,
    hour=1,
    minute=59,
    second=59,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
  assert_real_vector(
    timezone,
    1_772_953_200L,
    year=2026,
    month=3,
    day=8,
    hour=3,
    minute=0,
    second=0,
    utoff=-14_400,
    is_dst=true,
    abbr="EDT",
  )
  assert_real_vector(
    timezone,
    1_793_512_800L,
    year=2026,
    month=11,
    day=1,
    hour=1,
    minute=0,
    second=0,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
  let wall_time = match @tzif.parse_iso_local("2026-11-01T01:30:00") {
    Ok(value) => value
    Err(_) => fail("expected ISO wall time to parse")
  }
  match @tzif.resolve_local(timezone, wall_time) {
    Ok(Ambiguous(candidates)) => {
      assert_eq(candidates.length(), 2)
      assert_eq(candidates[0], 1_793_511_000L)
      assert_eq(candidates[1], 1_793_514_600L)
    }
    _ => fail("expected real New York fall-back overlap")
  }
}

///|
test "real New York final 2037 explicit transition is boundary safe" {
  let timezone = vector_load_ok(@golden.america_new_york_2026b)
  assert_real_vector(
    timezone,
    2_140_667_999L,
    year=2037,
    month=11,
    day=1,
    hour=1,
    minute=59,
    second=59,
    utoff=-14_400,
    is_dst=true,
    abbr="EDT",
  )
  assert_real_vector(
    timezone,
    2_140_668_000L,
    year=2037,
    month=11,
    day=1,
    hour=1,
    minute=0,
    second=0,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
  match @tzif.transition_detail(timezone, 235) {
    Ok(detail) => {
      assert_eq(detail.utc_time, 2_140_668_000L)
      assert_eq(detail.before.abbr, "EDT")
      assert_eq(detail.after.abbr, "EST")
      assert_eq(detail.offset_change, -3600)
      match detail.clock_change {
        ClockBackward => ()
        _ => fail("last explicit New York transition must move the clock back")
      }
    }
    Err(_) => fail("expected the final real New York transition")
  }
  match real_active_offset(timezone, 2_140_667_999L).source {
    ExplicitTransition(234) => ()
    _ => fail("instant before the last transition must remain explicit")
  }
  match real_active_offset(timezone, 2_140_668_000L).source {
    PosixFooter => ()
    _ => fail("the consistent footer must own post-table conversion")
  }
}

///|
test "real New York footer extrapolates 2040 and 2100 boundaries" {
  let timezone = vector_load_ok(@golden.america_new_york_2026b)
  assert_real_vector(
    timezone,
    2_215_061_999L,
    year=2040,
    month=3,
    day=11,
    hour=1,
    minute=59,
    second=59,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
  assert_real_vector(
    timezone,
    2_215_062_000L,
    year=2040,
    month=3,
    day=11,
    hour=3,
    minute=0,
    second=0,
    utoff=-14_400,
    is_dst=true,
    abbr="EDT",
  )
  assert_real_vector(
    timezone,
    4_129_250_399L,
    year=2100,
    month=11,
    day=7,
    hour=1,
    minute=59,
    second=59,
    utoff=-14_400,
    is_dst=true,
    abbr="EDT",
  )
  assert_real_vector(
    timezone,
    4_129_250_400L,
    year=2100,
    month=11,
    day=7,
    hour=1,
    minute=0,
    second=0,
    utoff=-18_000,
    is_dst=false,
    abbr="EST",
  )
  for
    utc_time in [2_215_061_999L, 2_215_062_000L, 4_129_250_399L, 4_129_250_400L] {
    match real_active_offset(timezone, utc_time).source {
      PosixFooter => ()
      _ => fail("future real New York oracle must use the audited footer")
    }
  }
}
