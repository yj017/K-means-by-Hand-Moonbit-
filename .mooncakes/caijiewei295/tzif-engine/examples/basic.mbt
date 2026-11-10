// A self-contained, runnable API example.
// Run with: moon run examples

///|
fn main {
  let timezone = @types.TzifData::{
    version: b'2',
    time_types: [{ utoff: 8 * 3600, is_dst: false, abbr: "CST" }],
    transitions: [],
    leap_seconds: [],
    standard_indicators: None,
    utc_indicators: None,
    posix_rule: None,
  }
  match @tzif.utc_to_local(timezone, 0L) {
    Err(_) => println("unexpected conversion error")
    Ok(local_time) =>
      match @tzif.format_iso_zoned(local_time) {
        Err(_) => println("example result is outside the ISO-8601 output range")
        Ok(text) =>
          println("1970-01-01T00:00:00Z becomes \{text} \{local_time.abbr}")
      }
  }
  show_embedded_new_york()
}
