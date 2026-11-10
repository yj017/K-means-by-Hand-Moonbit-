///|
// NumPy 2.3.5 generic npy_quicksort/npy_heapsort and OBJECT_compare, specialized
// to the frozen ScalarNumber domain. This is not the tuple/powersort protocol.
// Numeric object comparisons have no dynamic-operator side effects. A NaN
// compares equal for sorting (both LT and GT are false), without moving last.
fn logit_object_compare(
  left : ScalarNumber,
  right : ScalarNumber,
) -> Int32 raise @core.DataError {
  match eng_prefix_compare(left, right) {
    Some(order) => order
    None => 0
  }
}

///|
fn logit_object_swap(
  values : Array[ScalarNumber],
  left : Int32,
  right : Int32,
) -> Unit {
  let saved = values[left]
  values[left] = values[right]
  values[right] = saved
}

///|
fn logit_object_heapsort(
  values : Array[ScalarNumber],
  first : Int32,
  length : Int32,
) -> Unit raise @core.DataError {
  let base = first - 1
  let mut root = length / 2
  while root > 0 {
    let temporary = values[base + root]
    let mut parent = root
    let mut child = 2L * Int64::from_int(root)
    while child <= Int64::from_int(length) {
      if child < Int64::from_int(length) &&
        logit_object_compare(
          values[base + child.to_int()],
          values[base + child.to_int() + 1],
        ) <
        0 {
        child += 1L
      }
      if logit_object_compare(temporary, values[base + child.to_int()]) < 0 {
        values[base + parent] = values[base + child.to_int()]
        parent = child.to_int()
        child *= 2L
      } else {
        break
      }
    }
    values[base + parent] = temporary
    root -= 1
  }
  let mut remaining = length
  while remaining > 1 {
    let temporary = values[base + remaining]
    values[base + remaining] = values[base + 1]
    remaining -= 1
    let mut parent = 1
    let mut child = 2L
    while child <= Int64::from_int(remaining) {
      if child < Int64::from_int(remaining) &&
        logit_object_compare(
          values[base + child.to_int()],
          values[base + child.to_int() + 1],
        ) <
        0 {
        child += 1L
      }
      if logit_object_compare(temporary, values[base + child.to_int()]) < 0 {
        values[base + parent] = values[base + child.to_int()]
        parent = child.to_int()
        child *= 2L
      } else {
        break
      }
    }
    values[base + parent] = temporary
  }
}

///|
fn logit_object_sort(
  values : Array[ScalarNumber],
) -> Array[ScalarNumber] raise @core.DataError {
  let count = values.length()
  if count < 2 {
    return values
  }
  let mut bits = count
  let mut depth = 0
  while bits > 1 {
    bits = bits >> 1
    depth += 2
  }
  let pending : Array[(Int32, Int32, Int32)] = []
  let mut first = 0
  let mut last = count - 1
  while true {
    if depth < 0 {
      logit_object_heapsort(values, first, last - first + 1)
    } else {
      // The depth test is at the outer loop, matching generic NumPy. Do not
      // move it into this inner partition loop or change NaN comparison order.
      while last - first > 15 {
        let middle = first + (last - first) / 2
        if logit_object_compare(values[middle], values[first]) < 0 {
          logit_object_swap(values, middle, first)
        }
        if logit_object_compare(values[last], values[middle]) < 0 {
          logit_object_swap(values, last, middle)
        }
        if logit_object_compare(values[middle], values[first]) < 0 {
          logit_object_swap(values, middle, first)
        }
        let pivot = values[middle]
        let mut left = first
        let mut right = last - 1
        logit_object_swap(values, middle, right)
        while true {
          // C's do-while compares before its pointer-bound short circuit.
          left += 1
          while logit_object_compare(values[left], pivot) < 0 && left < right {
            left += 1
          }
          right -= 1
          while logit_object_compare(pivot, values[right]) < 0 && left < right {
            right -= 1
          }
          if left >= right {
            break
          }
          logit_object_swap(values, left, right)
        }
        logit_object_swap(values, left, last - 1)
        depth -= 1
        if left - first < last - left {
          pending.push((left + 1, last, depth))
          last = left - 1
        } else {
          pending.push((first, left - 1, depth))
          first = left + 1
        }
      }
      let mut cursor = first + 1
      while cursor <= last {
        let pivot = values[cursor]
        let mut target = cursor
        while target > first &&
              logit_object_compare(pivot, values[target - 1]) < 0 {
          values[target] = values[target - 1]
          target -= 1
        }
        values[target] = pivot
        cursor += 1
      }
    }
    match pending.pop() {
      Some((lower, upper, remaining)) => {
        first = lower
        last = upper
        depth = remaining
      }
      None => break
    }
  }
  values
}
