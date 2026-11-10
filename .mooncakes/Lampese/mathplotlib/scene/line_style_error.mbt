///|
// Specialized CPython difflib SequenceMatcher ratio for the eleven original
// Line choices. Inputs reaching this helper have at most 21 codepoints, so
// autojunk never applies; the default matcher also has no junk predicate.
fn line_style_match_ratio(
  candidate : Array[Char],
  value : Array[Char],
) -> Double {
  let size = candidate.length() + value.length()
  if size == 0 {
    return 1.0
  }
  let pending = [(0, candidate.length(), 0, value.length())]
  let mut matched = 0
  while !pending.is_empty() {
    let (alo, ahi, blo, bhi) = pending[pending.length() - 1]
    pending.remove(pending.length() - 1) |> ignore
    let mut best_a = alo
    let mut best_b = blo
    let mut best_size = 0
    let mut previous = Array::make(value.length() + 1, 0)
    for ai in alo..<ahi {
      let next = Array::make(value.length() + 1, 0)
      for bi in blo..<bhi {
        if candidate[ai] == value[bi] {
          let length = previous[bi] + 1
          next[bi + 1] = length
          // Strictly greater preserves earliest a, then earliest b ties.
          if length > best_size {
            best_a = ai - length + 1
            best_b = bi - length + 1
            best_size = length
          }
        }
      }
      previous = next
    }
    matched += best_size
    if best_size > 0 {
      if alo < best_a && blo < best_b {
        pending.push((alo, best_a, blo, best_b))
      }
      let end_a = best_a + best_size
      let end_b = best_b + best_size
      if end_a < ahi && end_b < bhi {
        pending.push((end_a, ahi, end_b, bhi))
      }
    }
  }
  2.0 * matched.to_double() / size.to_double()
}

///|
fn line_style_invalid_message(value : String) -> String {
  let message = "ValueError: " +
    @ticker.python_string_repr(value) +
    " is not a valid value for ls."
  let chars = value.to_array()
  // The longest choice has seven codepoints: even a perfect seven-character
  // match cannot reach cutoff .5 when the other sequence exceeds 21.
  if chars.length() > 21 {
    return message
  }
  let matches : Array[(Double, String)] = []
  for
    choice in [
      "-", "--", "-.", ":", "None", " ", "", "solid", "dashed", "dashdot", "dotted",
    ] {
    let candidate = choice.to_array()
    let size = candidate.length() + chars.length()
    let shorter = if candidate.length() < chars.length() {
      candidate.length()
    } else {
      chars.length()
    }
    let limit = if size == 0 {
      1.0
    } else {
      2.0 * shorter.to_double() / size.to_double()
    }
    if limit >= 0.5 {
      let ratio = line_style_match_ratio(candidate, chars)
      if ratio >= 0.5 {
        matches.push((ratio, choice))
      }
    }
  }
  matches.sort_by((left, right) => {
    let order = right.0.compare(left.0)
    if order == 0 {
      right.1.compare(left.1)
    } else {
      order
    }
  })
  if matches.is_empty() {
    message
  } else if matches.length() == 1 {
    message + " Did you mean: " + @ticker.python_string_repr(matches[0].1) + "?"
  } else {
    let count = if matches.length() < 3 { matches.length() } else { 3 }
    let choices = Array::makei(count, index => {
      @ticker.python_string_repr(matches[index].1)
    })
    message + " Did you mean one of: " + choices.join(", ") + "?"
  }
}
