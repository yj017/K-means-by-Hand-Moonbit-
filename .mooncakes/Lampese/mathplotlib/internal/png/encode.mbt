///|
pub(all) suberror EncodeError {
  InvalidDimensions
  InvalidPixelCount
}

///|
fn write_chunk(
  output : @buffer.Buffer,
  kind : BytesView,
  data : BytesView,
) -> Unit {
  output.write_int_be(data.length())
  output.write_bytes(kind)
  output.write_bytes(data)
  output.write_uint_be(
    crc_update(crc_update(0xffffffffU, kind), data) ^ 0xffffffffU,
  )
}

///|
/// Encode row-major RGBA bytes as an 8-bit, non-interlaced PNG. Pixels have
/// straight (not premultiplied) alpha. The first row is the top row; coordinate
/// orientation and color conversion are the caller's responsibility.
///
/// Rows use filter 0 and zlib stored blocks. Reject invalid dimensions and
/// mismatched pixel counts before allocating filtered image data.
pub fn encode_rgba(
  width : Int32,
  height : Int32,
  pixels : BytesView,
) -> Bytes raise EncodeError {
  if width <= 0 || height <= 0 || width > 536870911 {
    raise EncodeError::InvalidDimensions
  }
  let row_bytes = width * 4
  let filtered_size = (row_bytes.to_int64() + 1L) * height.to_int64()
  let blocks = (filtered_size + 65534L) / 65535L
  if filtered_size + blocks * 5L + 63L > 2147483647L {
    raise EncodeError::InvalidDimensions
  }
  if row_bytes.to_int64() * height.to_int64() != pixels.length().to_int64() {
    raise EncodeError::InvalidPixelCount
  }
  let header = @buffer.Buffer(size_hint=13)
  header.write_int_be(width)
  header.write_int_be(height)
  header.write_bytes(b"\x08\x06\x00\x00\x00")
  let filtered = @buffer.Buffer(size_hint=filtered_size.to_int())
  for row in 0..<height {
    filtered.write_byte(b'\x00')
    filtered.write_bytes(pixels[row * row_bytes:(row + 1) * row_bytes])
  }
  let output = @buffer.Buffer()
  output.write_bytes(b"\x89PNG\r\n\x1a\n")
  write_chunk(output, b"IHDR", header.to_bytes())
  write_chunk(output, b"IDAT", zlib_store(filtered.to_bytes()))
  write_chunk(output, b"IEND", b"")
  output.to_bytes()
}

///|
/// Encode a validated RGBA buffer for embedding directly in SVG.
pub fn rgba_data_uri(
  width : Int32,
  height : Int32,
  pixels : BytesView,
) -> String raise EncodeError {
  "data:image/png;base64," + @base64.encode(encode_rgba(width, height, pixels))
}
