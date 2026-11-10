// A complete compile-time embedding example.  No filesystem is consulted at
// runtime: the generated `Bytes` literal lives in the `golden` package.

///|
fn show_embedded_new_york() -> Unit {
  match @tzif.load(@golden.america_new_york_2026b) {
    Err(_) => println("embedded America/New_York fixture failed to load")
    Ok(timezone) =>
      match @tzif.utc_to_local(timezone, 1_772_953_200L) {
        Err(_) => println("embedded America/New_York conversion failed")
        Ok(local_time) =>
          match @tzif.format_iso_zoned(local_time) {
            Err(_) =>
              println("embedded result is outside the ISO-8601 output range")
            Ok(text) =>
              println("embedded America/New_York: \{text} \{local_time.abbr}")
          }
      }
  }
}
