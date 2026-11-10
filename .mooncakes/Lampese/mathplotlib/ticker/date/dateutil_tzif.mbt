///|
// Reuse the checked TZif engine for dateutil's legacy first block: widen its
// signed 32-bit transitions before passing it to the existing 64-bit parser.
fn dateutil_tzif_timezone(data : Bytes) -> DateTimeZone raise DateError {
  let fail = fn() {
    DateError::InvalidDate(message="invalid dateutil TZif compatibility block")
  }
  if data.length() < 44 {
    raise fail()
  }
  let header_bytes = data.to_array()
  header_bytes[4] = b'2'
  let normalized = Bytes::from_array(header_bytes)
  let (header, offset) = match @tzparser.parse_header(normalized, 0) {
    Ok(value) => value
    Err(_) => raise fail()
  }
  if header.leapcnt != 0U {
    raise DateError::InvalidDate(
      message="leap-second TZif zones are unsupported",
    )
  }
  let end_offset = match @tzparser.data_block_end(data, header, offset, 4) {
    Ok(value) => value
    Err(_) => raise fail()
  }
  let count = header.timecnt.reinterpret_as_int()
  let widened : Array[Byte] = []
  for i in 0..<count {
    let position = offset + 4 * i
    let sign = if data[position].to_int() >= 128 { b'\xff' } else { b'\x00' }
    for _ in 0..<4 {
      widened.push(sign)
    }
    for j in 0..<4 {
      widened.push(data[position + j])
    }
  }
  for i in (offset + 4 * count)..<end_offset {
    widened.push(data[i])
  }
  let body = match @tzparser.parse_body(Bytes::from_array(widened), header, 0) {
    Ok(value) => value
    Err(_) => raise fail()
  }
  let first = body.time_types[0]
  let mut initial = first
  let mut standard = first
  if !body.transitions.is_empty() {
    for time_type in body.time_types {
      if !time_type.is_dst {
        initial = time_type
        break
      }
    }
    let mut found_standard = false
    for i = body.transitions.length() - 1; i >= 0; i = i - 1 {
      let time_type = body.time_types[body.transitions[i].type_index]
      if !time_type.is_dst {
        standard = time_type
        found_standard = true
        break
      }
    }
    if !found_standard {
      standard = body.time_types[body.transitions[body.transitions.length() - 1].type_index]
    }
  }
  validate_offset_seconds(initial.utoff)
  let transitions : Array[TimeZoneTransition] = []
  for i in 0..<body.transitions.length() {
    let transition = body.transitions[i]
    let time_type = if i == body.transitions.length() - 1 {
      standard
    } else {
      body.time_types[transition.type_index]
    }
    validate_offset_seconds(time_type.utoff)
    transitions.push({
      at_microseconds: transition.utc_time * 1_000_000L,
      offset_seconds: time_type.utoff,
      abbreviation: Some(time_type.abbr),
    })
  }
  {
    initial_offset_seconds: initial.utoff,
    initial_abbreviation: Some(initial.abbr),
    transitions,
    footer: None,
    dateutil_footer: false,
    footer_start_seconds: None,
  }
}
