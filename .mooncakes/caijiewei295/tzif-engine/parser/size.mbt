// Checked TZif data-block sizing shared by the v1 skip and v2/v3 parser.

///|
/// Advance over `count` fixed-width records without overflowing `Int`.
///
/// `count` is only converted to `Int` after it is proven to fit in the bytes
/// remaining in the input.  The returned position is consequently also within
/// `data_length`.
fn advance_records(
  data_length : Int,
  offset : Int,
  count : UInt,
  record_size : Int,
) -> @types.TzifResult[Int] {
  if offset < 0 || offset > data_length || record_size <= 0 {
    return Err(InvalidTransitionTable("invalid TZif data-block bounds"))
  }
  let remaining = data_length - offset
  if count > (remaining / record_size).reinterpret_as_uint() {
    return Err(TruncatedData)
  }
  let byte_count = count.reinterpret_as_int() * record_size
  Ok(offset + byte_count)
}

///|
/// Return the exact first byte after a TZif data block.
///
/// The caller supplies `time_size=4` for the compatibility block and
/// `time_size=8` for the v2/v3 block. Leap-second records are one timestamp
/// plus a four-byte correction, so their widths are respectively 8 and 12.
pub fn data_block_end(
  data : Bytes,
  header : TzifHeader,
  offset : Int,
  time_size : Int,
) -> @types.TzifResult[Int] {
  match validate_input_size(data) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if time_size != 4 && time_size != 8 {
    return Err(
      InvalidTransitionTable("TZif timestamp width must be 4 or 8 bytes"),
    )
  }
  match validate_header_counts(header) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }

  let pos_after_times = match
    advance_records(data.length(), offset, header.timecnt, time_size) {
    Ok(pos) => pos
    Err(error) => return Err(error)
  }
  let pos_after_indices = match
    advance_records(data.length(), pos_after_times, header.timecnt, 1) {
    Ok(pos) => pos
    Err(error) => return Err(error)
  }
  let pos_after_types = match
    advance_records(data.length(), pos_after_indices, header.typecnt, 6) {
    Ok(pos) => pos
    Err(error) => return Err(error)
  }
  let pos_after_designations = match
    advance_records(data.length(), pos_after_types, header.charcnt, 1) {
    Ok(pos) => pos
    Err(error) => return Err(error)
  }
  let pos_after_leaps = match
    advance_records(
      data.length(),
      pos_after_designations,
      header.leapcnt,
      time_size + 4,
    ) {
    Ok(pos) => pos
    Err(error) => return Err(error)
  }
  let pos_after_std = match
    advance_records(data.length(), pos_after_leaps, header.isstdcnt, 1) {
    Ok(pos) => pos
    Err(error) => return Err(error)
  }
  advance_records(data.length(), pos_after_std, header.isutcnt, 1)
}
