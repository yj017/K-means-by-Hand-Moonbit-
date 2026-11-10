///|
// The source rotates its last effective dash to the front, then adds that dash
// to the effective offset. The Boolean records the last scaling operation's
// container provenance; current rc cannot reconstruct the empty-index message.
fn line_gapcolor_inverse(
  offset : Double,
  dashes : Array[Double],
  scaled_as_list~ : Bool = true,
) -> (Double, Array[Double]) raise @core.DataError {
  if dashes.is_empty() {
    raise @core.DataError::InvalidTicks(
      message=if scaled_as_list {
        "IndexError: list index out of range"
      } else {
        "IndexError: tuple index out of range"
      },
    )
  }
  let last = dashes[dashes.length() - 1]
  let inverse = Array(capacity=dashes.length())
  inverse.push(last)
  for index in 0..<(dashes.length() - 1) {
    inverse.push(dashes[index])
  }
  (offset + last, inverse)
}
