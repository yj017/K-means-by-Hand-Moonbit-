// TZif header parser (RFC 9636 section 3.1).

///|
/// Conservative defaults for parsing untrusted files. They are deliberately
/// much larger than normal IANA TZif files while bounding allocation
/// amplification in `parse_body`.
let max_tzif_file_bytes : Int = 64 * 1024 * 1024

///|
let max_transition_count : UInt = 1_000_000U

///|
let max_time_type_count : UInt = 256U

///|
let max_designation_bytes : UInt = 1024U * 1024U

///|
let max_leap_second_count : UInt = 10_000U

///|
fn validate_input_size(data : Bytes) -> @types.TzifResult[Unit] {
  if data.length() > max_tzif_file_bytes {
    Err(
      ResourceLimitExceeded(
        "TZif input exceeds the default 64 MiB parser limit",
      ),
    )
  } else {
    Ok(())
  }
}

///|
pub(all) struct TzifHeader {
  version : Byte
  isutcnt : UInt
  isstdcnt : UInt
  leapcnt : UInt
  timecnt : UInt
  typecnt : UInt
  charcnt : UInt
}

///|
/// Read a big-endian unsigned 32-bit integer from a verified header.
fn read_u32_be(data : Bytes, offset : Int) -> UInt {
  (data[offset].to_uint() << 24) |
  (data[offset + 1].to_uint() << 16) |
  (data[offset + 2].to_uint() << 8) |
  data[offset + 3].to_uint()
}

///|
/// Parse a 44-byte TZif v2/v3 header at `offset`.
///
/// Returns the parsed header and the new byte offset (offset + 44).
pub fn parse_header(
  data : Bytes,
  offset : Int,
) -> @types.TzifResult[(TzifHeader, Int)] {
  let length = data.length()
  // Check the offset before subtracting, then verify that every indexed byte
  // below is present.
  if offset < 0 || offset > length || length - offset < 44 {
    return Err(TruncatedData)
  }
  match validate_input_size(data) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }

  // Verify the magic number "TZif".
  if data[offset] != b'T' ||
    data[offset + 1] != b'Z' ||
    data[offset + 2] != b'i' ||
    data[offset + 3] != b'f' {
    return Err(InvalidMagic("expected 'TZif' magic bytes"))
  }

  let version = data[offset + 4]
  // Only versions 2 and 3 are supported.
  if version != b'2' && version != b'3' {
    return Err(UnsupportedVersion(version))
  }

  // Bytes offset+5 through offset+19 are reserved and required to be zero.
  for i in 5..<20 {
    if data[offset + i] != b'\x00' {
      return Err(
        InvalidTransitionTable(
          "non-zero reserved TZif header byte at index \{i}",
        ),
      )
    }
  }

  // Read the six unsigned 32-bit big-endian counts.
  let isutcnt = read_u32_be(data, offset + 20)
  let isstdcnt = read_u32_be(data, offset + 24)
  let leapcnt = read_u32_be(data, offset + 28)
  let timecnt = read_u32_be(data, offset + 32)
  let typecnt = read_u32_be(data, offset + 36)
  let charcnt = read_u32_be(data, offset + 40)

  let header = TzifHeader::{
    version,
    isutcnt,
    isstdcnt,
    leapcnt,
    timecnt,
    typecnt,
    charcnt,
  }
  match validate_header_counts(header) {
    Ok(_) => Ok((header, offset + 44))
    Err(error) => Err(error)
  }
}

///|
/// Validate count relationships that do not depend on a particular data block.
pub fn validate_header_counts(header : TzifHeader) -> @types.TzifResult[Unit] {
  if header.typecnt == 0 {
    return Err(InvalidTransitionTable("TZif typecnt must be non-zero"))
  }
  if header.charcnt == 0 {
    return Err(InvalidTransitionTable("TZif charcnt must be non-zero"))
  }
  if header.isstdcnt != 0 && header.isstdcnt != header.typecnt {
    return Err(
      InvalidTransitionTable("TZif isstdcnt must be zero or equal typecnt"),
    )
  }
  if header.isutcnt != 0 && header.isutcnt != header.typecnt {
    return Err(
      InvalidTransitionTable("TZif isutcnt must be zero or equal typecnt"),
    )
  }
  if header.timecnt > max_transition_count {
    return Err(
      ResourceLimitExceeded(
        "TZif transition count exceeds the default limit of 1000000",
      ),
    )
  }
  if header.typecnt > max_time_type_count {
    return Err(
      ResourceLimitExceeded(
        "TZif time type count exceeds the default limit of 256",
      ),
    )
  }
  if header.charcnt > max_designation_bytes {
    return Err(
      ResourceLimitExceeded(
        "TZif designation table exceeds the default limit of 1048576 bytes",
      ),
    )
  }
  if header.leapcnt > max_leap_second_count {
    return Err(
      ResourceLimitExceeded(
        "TZif leap-second count exceeds the default limit of 10000",
      ),
    )
  }
  Ok(())
}
