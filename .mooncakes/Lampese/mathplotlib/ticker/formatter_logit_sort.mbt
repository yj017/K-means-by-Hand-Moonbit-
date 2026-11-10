///|
// CPython 3.12.14 Objects/listobject.c powersort protocol, specialized to two
// distinct NumPy float64 scalar keys. NaNs deliberately have no total order.
// The fixed source SHA and original builtin-sorted evidence are in the guide.
priv struct LogitSortRun {
  start : Int32
  mut length : Int32
  mut power : Int32
}

///|
priv struct LogitSortState {
  pessimistic : Array[Double]
  sums : Array[Double]
  order : Array[Int32]
  pending : Array[LogitSortRun]
  mut min_gallop : Int32
}

///|
fn LogitSortState::less(
  self : LogitSortState,
  left : Int32,
  right : Int32,
) -> Bool {
  let a = self.pessimistic[left]
  let b = self.pessimistic[right]
  if a == b {
    self.sums[left] < self.sums[right]
  } else {
    a < b
  }
}

///|
fn logit_sort_move(
  values : Array[Int32],
  target : Int32,
  source : Int32,
  count : Int32,
) -> Unit {
  if target < source {
    for index in 0..<count {
      values[target + index] = values[source + index]
    }
  } else if target > source {
    let mut index = count
    while index > 0 {
      index -= 1
      values[target + index] = values[source + index]
    }
  }
}

///|
fn logit_sort_copy(
  target : Array[Int32],
  start : Int32,
  source : Array[Int32],
  offset : Int32,
  count : Int32,
) -> Unit {
  for index in 0..<count {
    target[start + index] = source[offset + index]
  }
}

///|
fn LogitSortState::binary_sort(
  self : LogitSortState,
  lower : Int32,
  upper : Int32,
  sorted : Int32,
) -> Unit {
  let mut start = if sorted == lower { sorted + 1 } else { sorted }
  while start < upper {
    let pivot = self.order[start]
    let mut left = lower
    let mut right = start
    while left < right {
      let middle = left + (right - left) / 2
      if self.less(pivot, self.order[middle]) {
        right = middle
      } else {
        left = middle + 1
      }
    }
    logit_sort_move(self.order, left + 1, left, start - left)
    self.order[left] = pivot
    start += 1
  }
}

///|
fn LogitSortState::count_run(
  self : LogitSortState,
  start : Int32,
  upper : Int32,
) -> (Int32, Bool) {
  if start + 1 == upper {
    return (1, false)
  }
  let descending = self.less(self.order[start + 1], self.order[start])
  let mut length = 2
  while start + length < upper {
    let falls = self.less(
      self.order[start + length],
      self.order[start + length - 1],
    )
    if falls != descending {
      break
    }
    length += 1
  }
  (length, descending)
}

///|
fn logit_sort_next_offset(offset : Int32, maximum : Int32) -> Int32 {
  // C expands in Py_ssize_t then clamps. Clamp before Int32 overflow instead;
  // both versions make exactly the same subsequent comparisons.
  if offset > (maximum - 1) / 2 {
    maximum
  } else {
    offset * 2 + 1
  }
}

///|
fn LogitSortState::gallop_left(
  self : LogitSortState,
  key : Int32,
  values : Array[Int32],
  base : Int32,
  length : Int32,
  hint : Int32,
) -> Int32 {
  let mut last = 0
  let mut offset = 1
  if self.less(values[base + hint], key) {
    let maximum = length - hint
    while offset < maximum {
      if self.less(values[base + hint + offset], key) {
        last = offset
        offset = logit_sort_next_offset(offset, maximum)
      } else {
        break
      }
    }
    offset = Int32::min(offset, maximum)
    last += hint
    offset += hint
  } else {
    let maximum = hint + 1
    while offset < maximum {
      if self.less(values[base + hint - offset], key) {
        break
      }
      last = offset
      offset = logit_sort_next_offset(offset, maximum)
    }
    offset = Int32::min(offset, maximum)
    let previous = last
    last = hint - offset
    offset = hint - previous
  }
  last += 1
  while last < offset {
    let middle = last + (offset - last) / 2
    if self.less(values[base + middle], key) {
      last = middle + 1
    } else {
      offset = middle
    }
  }
  offset
}

///|
fn LogitSortState::gallop_right(
  self : LogitSortState,
  key : Int32,
  values : Array[Int32],
  base : Int32,
  length : Int32,
  hint : Int32,
) -> Int32 {
  let mut last = 0
  let mut offset = 1
  if self.less(key, values[base + hint]) {
    let maximum = hint + 1
    while offset < maximum {
      if self.less(key, values[base + hint - offset]) {
        last = offset
        offset = logit_sort_next_offset(offset, maximum)
      } else {
        break
      }
    }
    offset = Int32::min(offset, maximum)
    let previous = last
    last = hint - offset
    offset = hint - previous
  } else {
    let maximum = length - hint
    while offset < maximum {
      if self.less(key, values[base + hint + offset]) {
        break
      }
      last = offset
      offset = logit_sort_next_offset(offset, maximum)
    }
    offset = Int32::min(offset, maximum)
    last += hint
    offset += hint
  }
  last += 1
  while last < offset {
    let middle = last + (offset - last) / 2
    if self.less(key, values[base + middle]) {
      offset = middle
    } else {
      last = middle + 1
    }
  }
  offset
}

///|
fn LogitSortState::merge_lo(
  self : LogitSortState,
  first : Int32,
  left_length : Int32,
  second : Int32,
  right_length : Int32,
) -> Unit {
  let temporary = Array::makei(left_length, index => self.order[first + index])
  let mut a = 0
  let mut b = second
  let mut target = first
  let mut na = left_length
  let mut nb = right_length
  self.order[target] = self.order[b]
  target += 1
  b += 1
  nb -= 1
  if nb == 0 {
    logit_sort_copy(self.order, target, temporary, a, na)
    return
  }
  if na == 1 {
    logit_sort_move(self.order, target, b, nb)
    self.order[target + nb] = temporary[a]
    return
  }
  let mut minimum = self.min_gallop
  while true {
    let mut acount = 0
    let mut bcount = 0
    while true {
      if self.less(self.order[b], temporary[a]) {
        self.order[target] = self.order[b]
        target += 1
        b += 1
        bcount += 1
        acount = 0
        nb -= 1
        if nb == 0 {
          logit_sort_copy(self.order, target, temporary, a, na)
          return
        }
        if bcount >= minimum {
          break
        }
      } else {
        self.order[target] = temporary[a]
        target += 1
        a += 1
        acount += 1
        bcount = 0
        na -= 1
        if na == 1 {
          logit_sort_move(self.order, target, b, nb)
          self.order[target + nb] = temporary[a]
          return
        }
        if acount >= minimum {
          break
        }
      }
    }
    minimum += 1
    while true {
      if minimum > 1 {
        minimum -= 1
      }
      self.min_gallop = minimum
      let count = self.gallop_right(self.order[b], temporary, a, na, 0)
      acount = count
      if count > 0 {
        logit_sort_copy(self.order, target, temporary, a, count)
        target += count
        a += count
        na -= count
        if na == 1 {
          logit_sort_move(self.order, target, b, nb)
          self.order[target + nb] = temporary[a]
          return
        }
        if na == 0 {
          return
        }
      }
      self.order[target] = self.order[b]
      target += 1
      b += 1
      nb -= 1
      if nb == 0 {
        logit_sort_copy(self.order, target, temporary, a, na)
        return
      }
      let count = self.gallop_left(temporary[a], self.order, b, nb, 0)
      bcount = count
      if count > 0 {
        logit_sort_move(self.order, target, b, count)
        target += count
        b += count
        nb -= count
        if nb == 0 {
          logit_sort_copy(self.order, target, temporary, a, na)
          return
        }
      }
      self.order[target] = temporary[a]
      target += 1
      a += 1
      na -= 1
      if na == 1 {
        logit_sort_move(self.order, target, b, nb)
        self.order[target + nb] = temporary[a]
        return
      }
      if acount < 7 && bcount < 7 {
        break
      }
    }
    minimum += 1
    self.min_gallop = minimum
  }
}

///|
fn LogitSortState::merge_hi(
  self : LogitSortState,
  first : Int32,
  left_length : Int32,
  second : Int32,
  right_length : Int32,
) -> Unit {
  let temporary = Array::makei(right_length, index => self.order[second + index])
  let mut na = left_length
  let mut nb = right_length
  let mut a = first + na - 1
  let mut b = nb - 1
  let mut target = second + nb - 1
  self.order[target] = self.order[a]
  target -= 1
  a -= 1
  na -= 1
  if na == 0 {
    logit_sort_copy(self.order, target - nb + 1, temporary, 0, nb)
    return
  }
  if nb == 1 {
    logit_sort_move(self.order, target - na + 1, a - na + 1, na)
    self.order[target - na] = temporary[b]
    return
  }
  let mut minimum = self.min_gallop
  while true {
    let mut acount = 0
    let mut bcount = 0
    while true {
      if self.less(temporary[b], self.order[a]) {
        self.order[target] = self.order[a]
        target -= 1
        a -= 1
        acount += 1
        bcount = 0
        na -= 1
        if na == 0 {
          logit_sort_copy(self.order, target - nb + 1, temporary, 0, nb)
          return
        }
        if acount >= minimum {
          break
        }
      } else {
        self.order[target] = temporary[b]
        target -= 1
        b -= 1
        bcount += 1
        acount = 0
        nb -= 1
        if nb == 1 {
          logit_sort_move(self.order, target - na + 1, a - na + 1, na)
          self.order[target - na] = temporary[b]
          return
        }
        if bcount >= minimum {
          break
        }
      }
    }
    minimum += 1
    while true {
      if minimum > 1 {
        minimum -= 1
      }
      self.min_gallop = minimum
      let count = na -
        self.gallop_right(temporary[b], self.order, first, na, na - 1)
      acount = count
      if count > 0 {
        target -= count
        a -= count
        logit_sort_move(self.order, target + 1, a + 1, count)
        na -= count
        if na == 0 {
          logit_sort_copy(self.order, target - nb + 1, temporary, 0, nb)
          return
        }
      }
      self.order[target] = temporary[b]
      target -= 1
      b -= 1
      nb -= 1
      if nb == 1 {
        logit_sort_move(self.order, target - na + 1, a - na + 1, na)
        self.order[target - na] = temporary[b]
        return
      }
      let count = nb - self.gallop_left(self.order[a], temporary, 0, nb, nb - 1)
      bcount = count
      if count > 0 {
        target -= count
        b -= count
        logit_sort_copy(self.order, target + 1, temporary, b + 1, count)
        nb -= count
        if nb == 1 {
          logit_sort_move(self.order, target - na + 1, a - na + 1, na)
          self.order[target - na] = temporary[b]
          return
        }
        if nb == 0 {
          return
        }
      }
      self.order[target] = self.order[a]
      target -= 1
      a -= 1
      na -= 1
      if na == 0 {
        logit_sort_copy(self.order, target - nb + 1, temporary, 0, nb)
        return
      }
      if acount < 7 && bcount < 7 {
        break
      }
    }
    minimum += 1
    self.min_gallop = minimum
  }
}

///|
fn LogitSortState::merge_at(self : LogitSortState, index : Int32) -> Unit {
  let first = self.pending[index].start
  let mut na = self.pending[index].length
  let second = self.pending[index + 1].start
  let mut nb = self.pending[index + 1].length
  self.pending[index].length = na + nb
  if index == self.pending.length() - 3 {
    self.pending[index + 1] = self.pending[index + 2]
  }
  ignore(self.pending.pop())
  let skipped = self.gallop_right(self.order[second], self.order, first, na, 0)
  let first = first + skipped
  na -= skipped
  if na == 0 {
    return
  }
  nb = self.gallop_left(
    self.order[first + na - 1],
    self.order,
    second,
    nb,
    nb - 1,
  )
  if nb == 0 {
    return
  }
  if na <= nb {
    self.merge_lo(first, na, second, nb)
  } else {
    self.merge_hi(first, na, second, nb)
  }
}

///|
fn logit_sort_power(
  start : Int32,
  first : Int32,
  second : Int32,
  length : Int32,
) -> Int32 {
  let total = Int64::from_int(length)
  let mut a = 2L * Int64::from_int(start) + Int64::from_int(first)
  let mut b = a + Int64::from_int(first) + Int64::from_int(second)
  let mut power = 0
  while true {
    power += 1
    if a >= total {
      a -= total
      b -= total
    } else if b >= total {
      break
    }
    a *= 2L
    b *= 2L
  }
  power
}

///|
fn LogitSortState::found_run(self : LogitSortState, length : Int32) -> Unit {
  let count = self.pending.length()
  if count == 0 {
    return
  }
  let previous = self.pending[count - 1]
  let power = logit_sort_power(
    previous.start,
    previous.length,
    length,
    self.order.length(),
  )
  while self.pending.length() > 1 &&
        self.pending[self.pending.length() - 2].power > power {
    self.merge_at(self.pending.length() - 2)
  }
  self.pending[self.pending.length() - 1].power = power
}

///|
fn logit_sort_indices(
  pessimistic : Array[Double],
  sums : Array[Double],
) -> Array[Int32] {
  let count = pessimistic.length()
  let order = Array::makei(count, index => index)
  if count < 2 {
    return order
  }
  let state : LogitSortState = {
    pessimistic,
    sums,
    order,
    pending: [],
    min_gallop: 7,
  }
  let mut short = count
  let mut remainder = 0
  while short >= 64 {
    remainder = remainder | (short & 1)
    short = short >> 1
  }
  let minrun = short + remainder
  let mut lower = 0
  while lower < count {
    let (natural, descending) = state.count_run(lower, count)
    let mut length = natural
    if descending {
      let mut left = lower
      let mut right = lower + natural - 1
      while left < right {
        let saved = order[left]
        order[left] = order[right]
        order[right] = saved
        left += 1
        right -= 1
      }
    }
    if length < minrun {
      let forced = Int32::min(minrun, count - lower)
      state.binary_sort(lower, lower + forced, lower + length)
      length = forced
    }
    state.found_run(length)
    state.pending.push({ start: lower, length, power: 0, })
    lower += length
  }
  while state.pending.length() > 1 {
    let mut index = state.pending.length() - 2
    if index > 0 &&
      state.pending[index - 1].length < state.pending[index + 1].length {
      index -= 1
    }
    state.merge_at(index)
  }
  order
}
