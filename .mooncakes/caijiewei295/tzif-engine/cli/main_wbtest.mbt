///|
test "help and version are successful CLI requests" {
  assert_eq(run_cli(["--help"]), 0)
  assert_eq(run_cli(["-h"]), 0)
  assert_eq(run_cli(["--version"]), 0)
  assert_eq(run_cli(["version"]), 0)
}

///|
test "unknown commands malformed input and invalid arity are nonzero" {
  assert_true(run_cli([]) != 0)
  assert_true(run_cli(["unknown"]) != 0)
  assert_true(run_cli(["info"]) != 0)
  assert_true(run_cli(["info", "zz"]) != 0)
  assert_true(run_cli(["utc-to-local", "00", "not-an-int"]) != 0)
  assert_true(run_cli(["--help", "unexpected"]) != 0)
}

///|
fn fixture_hex(bytes : Bytes) -> String {
  let digits = "0123456789abcdef"
  let mut output = ""
  for byte in bytes {
    let value = byte.to_int()
    let high = value / 16
    let low = value % 16
    output = output +
      digits[high:high + 1].to_owned() +
      digits[low:low + 1].to_owned()
  }
  output
}

///|
test "every CLI operation returns a meaningful status" {
  let input = fixture_hex(@fixtures.fixed_offset_v2(0, "UTC").bytes)
  let historical_input = fixture_hex(
    @fixtures.fixed_offset_v2(-17_762, "LMT").bytes,
  )
  assert_eq(run_cli(["info", input]), 0)
  assert_eq(run_cli(["info", historical_input]), 0)
  assert_eq(run_cli(["utc-to-local", historical_input, "0"]), 0)
  assert_eq(run_cli(["utc-to-local", input, "0"]), 0)
  assert_eq(run_cli(["local-to-utc", input, "1970-01-01T00:00:00"]), 0)
  assert_eq(run_cli(["resolve-local", input, "1970-01-01T00:00:00"]), 0)
  assert_eq(run_cli(["transitions", input, "0", "1"]), 0)
  assert_eq(run_cli(["transition", input, "0"]), 1)
  assert_eq(run_cli(["transitions", input, "2", "1"]), 1)
  assert_eq(run_cli(["utc-to-local", input, "not-an-int"]), 2)
  assert_eq(run_cli(["utc-to-local", input, "9223372036854775807"]), 1)
  assert_eq(run_cli(["transition", input, "not-an-index"]), 2)
  assert_eq(run_cli(["local-to-utc", input, "2026-02-30T00:00:00"]), 2)
}
