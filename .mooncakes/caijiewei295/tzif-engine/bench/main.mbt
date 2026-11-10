// Repeatable performance harness for the two primary library hot paths.
// Run with: moon run bench --target native --release

///|
fn benchmark_fixture() -> @fixtures.FixtureFile {
  @fixtures.build(
    version=b'3',
    [
      { utoff: -5 * 3600, is_dst: false, abbr_index: 0 },
      { utoff: -4 * 3600, is_dst: true, abbr_index: 4 },
    ],
    [
      { utc_time: 1_772_953_200L, type_index: b'\x01' },
      { utc_time: 1_793_512_800L, type_index: b'\x00' },
    ],
    "EST\u{0000}EDT\u{0000}",
    footer="EST5EDT,M3.2.0,M11.1.0",
  )
}

///|
fn main {
  let source = benchmark_fixture().bytes
  let timezone = match @tzif.load(source) {
    Ok(value) => value
    Err(_) => panic()
  }
  let mut checksum = 0L
  let harness = @corebench.Bench()
  harness.bench(
    name="parse_minimal_v3_us",
    () => {
      match @tzif.load(source) {
        Ok(value) => checksum = checksum + value.transitions.length().to_int64()
        Err(_) => panic()
      }
    },
    count=10,
  )
  harness.bench(
    name="utc_to_local_us",
    () => {
      match @tzif.utc_to_local(timezone, 1_772_953_200L) {
        Ok(value) => checksum = checksum + value.hour.to_int64()
        Err(_) => panic()
      }
    },
    count=10,
  )
  harness.bench(
    name="local_to_utc_us",
    () => {
      match @tzif.parse_iso_local("2026-11-01T01:30:00") {
        Err(_) => panic()
        Ok(local_time) =>
          match @tzif.local_to_utc(timezone, local_time, PreferLater) {
            Ok(value) => checksum = checksum + value
            Err(_) => panic()
          }
      }
    },
    count=10,
  )
  let real_source = @golden.america_new_york_2026b
  let real_timezone = match @tzif.load(real_source) {
    Ok(value) => value
    Err(_) => panic()
  }
  harness.bench(
    name="parse_real_america_new_york_2026b",
    () => {
      match @tzif.load(real_source) {
        Ok(value) => checksum = checksum + value.transitions.length().to_int64()
        Err(_) => panic()
      }
    },
    count=10,
  )
  harness.bench(
    name="utc_to_local_real_america_new_york_2026b",
    () => {
      match @tzif.utc_to_local(real_timezone, 1_772_953_200L) {
        Ok(value) => checksum = checksum + value.hour.to_int64()
        Err(_) => panic()
      }
    },
    count=10,
  )
  harness.bench(
    name="local_to_utc_real_america_new_york_2026b",
    () => {
      match @tzif.parse_iso_local("2026-11-01T01:30:00") {
        Err(_) => panic()
        Ok(local_time) =>
          match @tzif.local_to_utc(real_timezone, local_time, PreferLater) {
            Ok(value) => checksum = checksum + value
            Err(_) => panic()
          }
      }
    },
    count=10,
  )
  println(harness.dump_summaries())
  println("checksum=\{checksum}")
}
