///|
// RFC 1950 stream containing RFC 1951 stored blocks. No native dependency or
// target-specific compressor is needed. Compression can be added independently
// of the image renderer; the initial encoder intentionally favors simplicity.
fn zlib_store(data : BytesView) -> Bytes {
  let result = @buffer.Buffer()
  result.write_bytes(b"\x78\x01")
  let mut offset = 0
  for ;; {
    let count = Int32::min(65535, data.length() - offset)
    let final_block = offset + count == data.length()
    result.write_byte(if final_block { b'\x01' } else { b'\x00' })
    result.write_byte(count.to_byte())
    result.write_byte((count >> 8).to_byte())
    let complement = count ^ 65535
    result.write_byte(complement.to_byte())
    result.write_byte((complement >> 8).to_byte())
    result.write_bytes(data[offset:offset + count])
    offset += count
    if final_block {
      break
    }
  }
  result.write_uint_be(adler32(data))
  result.to_bytes()
}
