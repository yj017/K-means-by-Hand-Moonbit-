///|
fn logit_named_prepare(
  base : BaseFormatter,
  state : LogitFormatterState,
  input : LogitInput,
) -> Unit raise @core.DataError {
  base.locations = input.snapshot()
  state.labelled.clear()
  if !log_value_truth(state.minor) {
    return
  }
  let mut ideal = true
  let mut index = 0
  while index < input.length() {
    let value = input.key_at(index).value()
    if !logit_is_decade(value) &&
      !logit_is_decade(
        scalar_numeric_op(
          ScalarNumber::Integer(@bigint.BigInt::from_int(1)),
          value,
          1,
        ),
      ) &&
      !logit_is_half(value, numpy_round=true) {
      ideal = false
      break
    }
    index += 1
  }
  if ideal {
    return
  }
  if !logit_count_less(input.length(), state.minor_threshold) {
    return
  }
  if logit_count_less(input.length(), state.minor_number) {
    let mut index = 0
    while index < input.length() {
      state.labelled.add(input.key_at(index))
      index += 1
    }
    return
  }
  let logits = logit_array_logits(base.locations)
  let differences : Array[Double] = []
  for index in 1..<logits.length() {
    differences.push(logits[index] - logits[index - 1])
  }
  let pessimistic : Array[Double] = []
  let sums : Array[Double] = []
  for index in 0..<logits.length() {
    let left = if index == 0 { 1.0 / 0.0 } else { differences[index - 1] }
    let right = if index == logits.length() - 1 {
      1.0 / 0.0
    } else {
      differences[index]
    }
    pessimistic.push(
      if left.is_nan() {
        left
      } else if right.is_nan() {
        right
      } else if left < right {
        left
      } else {
        right
      },
    )
    sums.push(
      (if index == 0 { 0.0 } else { differences[index - 1] }) +
      (if index == logits.length() - 1 { 0.0 } else { differences[index] }),
    )
  }
  let ordered = logit_sort_indices(pessimistic, sums)
  let first = logit_slice_start(state.minor_number, ordered.length())
  for index in first..<ordered.length() {
    state.labelled.add(input.key_at(ordered[index]))
  }
}
