///|
// PNG uses the reflected IEEE CRC-32 polynomial (ISO 3309).
let crc_table : FixedArray[UInt32] = FixedArray::makei(256, index => {
  let mut value = index.reinterpret_as_uint()
  for _ in 0..<8 {
    value = if (value & 1U) == 0U {
      value >> 1
    } else {
      (value >> 1) ^ 0xedb88320U
    }
  }
  value
})

///|
fn crc_update(crc : UInt32, data : BytesView) -> UInt32 {
  let mut result = crc
  for byte in data {
    result = (result >> 8) ^
      crc_table[((result ^ byte.to_uint()) & 255U).reinterpret_as_int()]
  }
  result
}

///|
fn adler32(data : BytesView) -> UInt32 {
  let mut first = 1U
  let mut second = 0U
  for byte in data {
    first = (first + byte.to_uint()) % 65521U
    second = (second + first) % 65521U
  }
  (second << 16) | first
}
