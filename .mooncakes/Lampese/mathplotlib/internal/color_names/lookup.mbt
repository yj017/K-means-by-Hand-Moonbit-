///|
// These are generated, trusted table constants, not user input. The generator
// validates the ASCII names, delimiters, channel count and opaque alpha.
fn channel_bits(value : StringView, start : Int32) -> UInt64 {
  let mut bits = 0UL
  for index in start..<(start + 16) {
    let digit = match value[index] {
      '0'..<='9' as c => c.to_int() - 48
      'a'..<='f' as c => c.to_int() - 87
      _ => abort("invalid generated color component")
    }
    bits = (bits << 4) | digit.to_uint64()
  }
  bits
}

///|
fn load_names() -> Map[String, @colors.Rgba] {
  let names : Map[String, @colors.Rgba] = Map([])
  for table in [xkcd_data, xkcd_aliases_data, standard_data] {
    for row in table.split("\n") {
      guard row.split_once("|") is Some((name, bits)) else {
        abort("invalid generated color row")
      }
      guard bits.length() == 48 else {
        abort("invalid generated color bit count")
      }
      names[name.to_owned()] = try! @colors.rgba(
        channel_bits(bits, 0).reinterpret_as_double(),
        channel_bits(bits, 16).reinterpret_as_double(),
        channel_bits(bits, 32).reinterpret_as_double(),
      )
    }
  }
  names
}

///|
let names : Map[String, @colors.Rgba] = load_names()

///|
/// Exact lookup in the immutable pinned named-color table. String spelling,
/// none/hex/grayscale/cycle syntax and lazy conversion belong to the caller.
pub fn lookup(name : String) -> @colors.Rgba? {
  names.get(name)
}
