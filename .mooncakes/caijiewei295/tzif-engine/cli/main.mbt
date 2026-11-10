// Portable TZif command-line inspector.
//
// The library deliberately has no filesystem dependency so it can also run
// on wasm targets.  The executable therefore accepts TZif bytes as hex; a
// native host adapter can read a zoneinfo file and pass its contents here.

///|
fn print_usage() -> Unit {
  println("tzif — portable TZif v2/v3 inspector")
  println("")
  println("USAGE:")
  println("  tzif info <tzif-hex>")
  println("  tzif utc-to-local <tzif-hex> <unix-seconds>")
  println(
    "  tzif local-to-utc <tzif-hex> <YYYY-MM-DDTHH:MM:SS> [earlier|later]",
  )
  println("  tzif resolve-local <tzif-hex> <YYYY-MM-DDTHH:MM:SS>")
  println("  tzif transition <tzif-hex> <index>")
  println("  tzif transitions <tzif-hex> <start-unix> <end-unix>")
  println("")
  println("The hexadecimal input is the raw content of a TZif file.")
}

///|
fn print_version() -> Unit {
  println("tzif-engine 0.1.0")
}

///|
fn print_error(message : String) -> Unit {
  println("error: " + message)
}

///|
fn hex_value(code : Int) -> Int? {
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn decode_hex(input : String) -> Bytes? {
  let length = input.length()
  if length == 0 || length % 2 != 0 {
    return None
  }
  let output : Array[Byte] = []
  for index = 0; index < length; index = index + 2 {
    let high = match hex_value(input[index].to_int()) {
      Some(value) => value
      None => return None
    }
    let low = match hex_value(input[index + 1].to_int()) {
      Some(value) => value
      None => return None
    }
    output.push((high * 16 + low).to_byte())
  }
  Some(Bytes::from_array(output))
}

///|
fn parse_timestamp(input : String) -> Int64? {
  Some(@string.parse_int64(input, base=10)) catch {
    _ => None
  }
}

///|
fn parse_index(input : String) -> Int? {
  Some(@string.parse_int(input, base=10)) catch {
    _ => None
  }
}

///|
fn parse_strategy(input : String) -> @types.AmbiguityStrategy? {
  match input {
    "earlier" => Some(PreferEarlier)
    "later" => Some(PreferLater)
    _ => None
  }
}

///|
fn print_local(local_time : @types.LocalDateTime) -> Bool {
  match @tzif.format_iso_zoned(local_time) {
    Ok(value) => {
      println("\{value} \{local_time.abbr}")
      true
    }
    Err(_) => {
      print_error("local time is outside the supported ISO-8601 output range")
      false
    }
  }
}

///|
fn format_offset_for_diagnostic(offset : Int) -> String {
  match @tzif.format_numeric_offset(offset) {
    Ok(value) => value
    Err(_) =>
      if offset >= 0 {
        "+" + offset.to_string() + "s"
      } else {
        offset.to_string() + "s"
      }
  }
}

///|
fn print_transition_detail(detail : @types.TransitionDetail) -> Bool {
  let change = match detail.clock_change {
    ClockForward => "forward"
    ClockBackward => "backward"
    NoClockChange => "no wall-clock change"
  }
  let utc_text = match @tzif.format_iso_utc(detail.utc_time) {
    Ok(value) => value
    Err(_) => {
      print_error("transition timestamp is outside the ISO-8601 output range")
      return false
    }
  }
  let before_offset = format_offset_for_diagnostic(detail.before.utoff)
  let after_offset = format_offset_for_diagnostic(detail.after.utoff)
  println("transition #\{detail.index} at \{utc_text}")
  println("  before: \{detail.before.abbr} (UTC\{before_offset})")
  println("  after:  \{detail.after.abbr} (UTC\{after_offset})")
  println("  clock: \{change}, offset delta \{detail.offset_change} seconds")
  println("  local boundary: \{detail.local_before} -> \{detail.local_after}")
  true
}

///|
fn parse_local_argument(input : String) -> @types.LocalDateTime? {
  match @tzif.parse_iso_local(input) {
    Ok(value) => Some(value)
    Err(_) => {
      print_error("local time must use YYYY-MM-DDTHH:MM:SS")
      None
    }
  }
}

///|
fn load_hex(input : String) -> @types.TzifData? {
  let bytes = match decode_hex(input) {
    Some(value) => value
    None => {
      print_error(
        "TZif input must be a non-empty even-length hexadecimal string",
      )
      return None
    }
  }
  match @tzif.load(bytes) {
    Ok(timezone) => Some(timezone)
    Err(_) => {
      print_error("invalid or unsupported TZif v2/v3 data")
      None
    }
  }
}

///|
fn run_cli(args : Array[String]) -> Int {
  if args.length() == 0 {
    print_usage()
    return 2
  }
  match args[0] {
    "--help" | "-h" | "help" =>
      if args.length() == 1 {
        print_usage()
        0
      } else {
        print_usage()
        2
      }
    "--version" | "version" =>
      if args.length() == 1 {
        print_version()
        0
      } else {
        print_usage()
        2
      }
    "info" =>
      if args.length() != 2 {
        print_usage()
        2
      } else {
        match load_hex(args[1]) {
          Some(timezone) => {
            println(@tzif.info(timezone))
            0
          }
          None => 2
        }
      }
    "utc-to-local" =>
      if args.length() != 3 {
        print_usage()
        2
      } else {
        let timezone = match load_hex(args[1]) {
          Some(value) => value
          None => return 2
        }
        let timestamp = match parse_timestamp(args[2]) {
          Some(value) => value
          None => {
            print_error("unix-seconds must be a signed Int64 decimal value")
            return 2
          }
        }
        match @tzif.utc_to_local(timezone, timestamp) {
          Ok(local_time) => if print_local(local_time) { 0 } else { 1 }
          Err(_) => {
            print_error("timezone conversion failed")
            1
          }
        }
      }
    "local-to-utc" =>
      if args.length() != 3 && args.length() != 4 {
        print_usage()
        2
      } else {
        let timezone = match load_hex(args[1]) {
          Some(value) => value
          None => return 2
        }
        let local_time = match parse_local_argument(args[2]) {
          Some(value) => value
          None => return 2
        }
        let strategy = if args.length() == 4 {
          match parse_strategy(args[3]) {
            Some(value) => value
            None => {
              print_error("ambiguity strategy must be earlier or later")
              return 2
            }
          }
        } else {
          PreferEarlier
        }
        match @tzif.local_to_utc(timezone, local_time, strategy) {
          Ok(utc_time) =>
            match @tzif.format_iso_utc(utc_time) {
              Ok(value) => {
                println("\{value} (unix \{utc_time})")
                0
              }
              Err(_) => {
                print_error("UTC result is outside the ISO-8601 output range")
                1
              }
            }
          Err(InvalidLocalTime(_)) => {
            print_error("local time falls in a DST gap")
            1
          }
          Err(_) => {
            print_error("local time could not be resolved")
            1
          }
        }
      }
    "resolve-local" =>
      if args.length() != 3 {
        print_usage()
        2
      } else {
        let timezone = match load_hex(args[1]) {
          Some(value) => value
          None => return 2
        }
        let local_time = match parse_local_argument(args[2]) {
          Some(value) => value
          None => return 2
        }
        match @tzif.resolve_local(timezone, local_time) {
          Ok(Unique(utc_time)) =>
            match @tzif.format_iso_utc(utc_time) {
              Ok(value) => {
                println("unique: \{value} (unix \{utc_time})")
                0
              }
              Err(_) => {
                print_error("UTC result is outside the ISO-8601 output range")
                1
              }
            }
          Ok(Gap) => {
            println("gap: local time does not occur in this timezone")
            0
          }
          Ok(Ambiguous(candidates)) => {
            println("ambiguous: \{candidates.length()} UTC candidates")
            for utc_time in candidates {
              let value = match @tzif.format_iso_utc(utc_time) {
                Ok(text) => text
                Err(_) => {
                  print_error("UTC result is outside the ISO-8601 output range")
                  return 1
                }
              }
              println("  \{value} (unix \{utc_time})")
            }
            0
          }
          Err(_) => {
            print_error("local time could not be resolved")
            1
          }
        }
      }
    "transition" =>
      if args.length() != 3 {
        print_usage()
        2
      } else {
        let timezone = match load_hex(args[1]) {
          Some(value) => value
          None => return 2
        }
        let index = match parse_index(args[2]) {
          Some(value) => value
          None => {
            print_error("transition index must be a signed decimal Int")
            return 2
          }
        }
        match @tzif.transition_detail(timezone, index) {
          Ok(detail) => if print_transition_detail(detail) { 0 } else { 1 }
          Err(_) => {
            print_error("transition index is out of range or data is invalid")
            1
          }
        }
      }
    "transitions" =>
      if args.length() != 4 {
        print_usage()
        2
      } else {
        let timezone = match load_hex(args[1]) {
          Some(value) => value
          None => return 2
        }
        let start_utc = match parse_timestamp(args[2]) {
          Some(value) => value
          None => {
            print_error("start-unix must be a signed Int64 decimal value")
            return 2
          }
        }
        let end_utc = match parse_timestamp(args[3]) {
          Some(value) => value
          None => {
            print_error("end-unix must be a signed Int64 decimal value")
            return 2
          }
        }
        match @tzif.transition_details_between(timezone, start_utc, end_utc) {
          Ok(details) => {
            if details.length() == 0 {
              println("no explicit transitions in range")
            } else {
              for detail in details {
                if !print_transition_detail(detail) {
                  return 1
                }
              }
            }
            0
          }
          Err(_) => {
            print_error("invalid transition range or timezone data")
            1
          }
        }
      }
    _ => {
      print_usage()
      2
    }
  }
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let arguments = if argv.length() > 0 { argv[1:].to_owned() } else { [] }
  @sys.exit(run_cli(arguments))
}
