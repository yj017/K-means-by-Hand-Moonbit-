///|
fn framed_footer(text : String) -> Bytes {
  let bytes : Array[Byte] = [b'\n']
  for byte in @utf8.encode(text) {
    bytes.push(byte)
  }
  bytes.push(b'\n')
  Bytes::from_array(bytes)
}

///|
fn footer_rule(text : String, version : Byte) -> @types.PosixTzRule {
  match parse_footer(framed_footer(text), offset=0, version~) {
    Ok(Some(rule)) => rule
    _ => panic()
  }
}

///|
test "footer parser consumes exact TZif framing and accepts an empty TZ string" {
  match parse_footer(framed_footer(""), offset=0, version=b'2') {
    Ok(None) => ()
    _ => panic()
  }

  let bytes = Bytes::from_array([b'x', b'\n', b'E', b'S', b'T', b'5', b'\n'])
  match parse_footer(bytes, offset=1, version=b'2') {
    Ok(Some(rule)) => {
      assert_eq(rule.std_abbr, "EST")
      assert_eq(rule.std_offset, -18000)
    }
    _ => panic()
  }
  match parse_footer(bytes, offset=0, version=b'2') {
    Err(_) => ()
    _ => panic()
  }
}

///|
test "footer parser preserves Jn and zero-based day rules in the AST" {
  let rule = footer_rule("EST5EDT,0/0,J365/24", b'2')
  match rule.start_rule {
    Some(start) => {
      match start.date_rule {
        DayOfYear(day) => assert_eq(day, 0)
        _ => panic()
      }
      assert_eq(start.time_of_day, 0)
      match start.time_basis {
        Wall => ()
        _ => panic()
      }
    }
    None => panic()
  }
  match rule.end_rule {
    Some(end) => {
      match end.date_rule {
        JulianNoLeap(day) => assert_eq(day, 365)
        _ => panic()
      }
      assert_eq(end.time_of_day, 86400)
    }
    None => panic()
  }
}

///|
test "tzcode reader compatibility preserves clock-basis suffixes in v3" {
  let rule = footer_rule("<-03>3<-02>,M3.5.0/-2u,M10.5.0/-1s", b'3')
  assert_eq(rule.std_abbr, "-03")
  assert_eq(rule.std_offset, -10800)
  assert_eq(rule.dst_abbr, Some("-02"))
  assert_eq(rule.dst_offset, Some(-7200))
  match rule.start_rule {
    Some(start) => {
      assert_eq(start.time_of_day, -7200)
      match start.time_basis {
        Utc => ()
        _ => panic()
      }
    }
    None => panic()
  }
  match rule.end_rule {
    Some(end) => {
      assert_eq(end.time_of_day, -3600)
      match end.time_basis {
        Standard => ()
        _ => panic()
      }
    }
    None => panic()
  }
}

///|
test "tzcode v2 reader compatibility accepts non-POSIX transition hours" {
  let rule = footer_rule("<+00>0<+01>,0/0,J365/25", b'2')
  match rule.start_rule {
    Some(start) => assert_eq(start.time_of_day, 0)
    None => panic()
  }
  match rule.end_rule {
    Some(end) => assert_eq(end.time_of_day, 25 * 3600)
    None => panic()
  }
  let signed = footer_rule("EST5EDT,M3.2.0/-2,M11.1.0/2", b'2')
  match signed.start_rule {
    Some(start) => assert_eq(start.time_of_day, -2 * 3600)
    None => panic()
  }
}

///|
test "RFC 9636 POSIX clocks accept 24:59:59 and v3 accepts signed 167:59:59" {
  let offset = footer_rule("<STD>24:59:59", b'2')
  assert_eq(offset.std_offset, -89999)
  let v2 = footer_rule("EST5EDT,M3.2.0/24:59:59,M11.1.0/0", b'2')
  match v2.start_rule {
    Some(start) => assert_eq(start.time_of_day, 89999)
    None => panic()
  }
  let v3 = footer_rule("<-03>3<-02>,M3.5.0/+167:59:59,M10.5.0/-167:59:59", b'3')
  match v3.start_rule {
    Some(start) => assert_eq(start.time_of_day, 604799)
    None => panic()
  }
  match v3.end_rule {
    Some(end) => assert_eq(end.time_of_day, -604799)
    None => panic()
  }
}

///|
test "POSIX quoted abbreviations enforce characters and portable length" {
  let valid = footer_rule("<A+1>0", b'2')
  assert_eq(valid.std_abbr, "A+1")
  for text in ["<A>0", "<A_1>0", "<A/B>0", "<>0"] {
    match parse_footer(framed_footer(text), offset=0, version=b'2') {
      Err(PosixParseError(_)) => ()
      _ => panic()
    }
  }
  let too_long = "<" + [ for _ in 0..<256 => "A" ].join("") + ">0"
  match parse_footer(framed_footer(too_long), offset=0, version=b'2') {
    Err(PosixParseError(_)) => ()
    _ => panic()
  }
}

///|
test "footer parser rejects malformed frames, bad grammar, and trailing data" {
  let unterminated = Bytes::from_array([b'\n', b'E', b'S', b'T', b'5'])
  match parse_footer(unterminated, offset=0, version=b'2') {
    Err(_) => ()
    _ => panic()
  }
  match
    parse_footer(
      framed_footer("EST5EDT,M3.2.0,M11.1.0junk"),
      offset=0,
      version=b'2',
    ) {
    Err(_) => ()
    _ => panic()
  }
  match
    parse_footer(
      framed_footer("EST5EDT,M3.2.0/168,M11.1.0/2"),
      offset=0,
      version=b'2',
    ) {
    Err(_) => ()
    _ => panic()
  }
  match
    parse_footer(
      framed_footer("EST5EDT,M3.9.0,M11.1.0"),
      offset=0,
      version=b'2',
    ) {
    Err(_) => ()
    _ => panic()
  }
}
