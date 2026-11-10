///|
priv struct AsinhGridCursor {
  run : AsinhGridRun
  first : Int64
  last : Int64
  reverse : Bool
  factor : Double
  subdivision : Int32
  multiplier : Int64
  next : Int64
  value : Double
  rank : Int64
}

///|
fn asinh_grid_cursor(
  context : AsinhGridContext,
  run : AsinhGridRun,
  first : Int64,
  last : Int64,
  reverse : Bool,
  factor : Double,
  subdivision : Int32,
  multiplier : Int64,
  position : Int64,
) -> AsinhGridCursor {
  let native = fn(index : Int64) {
    if reverse {
      last - 1L - index
    } else {
      first + index
    }
  }
  let value = context.value(run, native(position), factor)
  let next_position = position + 1L
  let next = if next_position == last - first ||
    context.value(run, native(next_position), factor) != value {
    next_position
  } else {
    next_position +
    asinh_grid_boundary(last - first - next_position, index => {
      context.value(run, native(next_position + index), factor) != value
    })
  }
  // A reversed equal-value plateau can contain either zero sign. Python set
  // retains the value at the earliest original outer(flatten) insertion rank.
  let representative = if reverse {
    native(next - 1L)
  } else {
    native(position)
  }
  {
    run,
    first,
    last,
    reverse,
    factor,
    subdivision,
    multiplier,
    next,
    value: context.value(run, representative, factor),
    rank: (run.rank + representative) * multiplier + subdivision.to_int64(),
  }
}

///|
fn asinh_grid_cursor_less(
  left : AsinhGridCursor,
  right : AsinhGridCursor,
) -> Bool {
  left.value < right.value ||
  (left.value == right.value && left.rank < right.rank)
}

///|
fn asinh_grid_push_numeric(
  heap : Array[AsinhGridCursor],
  context : AsinhGridContext,
  run : AsinhGridRun,
  first : Int64,
  last : Int64,
  factor : Double,
  subdivision : Int32,
  multiplier : Int64,
) -> Unit {
  let mut start = first
  while start < last {
    let finish = if context.base > 1.0 {
      last
    } else {
      // Across decimal phases 10*round(10^n) can exceed round(10^(n+1)).
      // Each constant-pows run has monotone separate multiply/round steps.
      let pows = context.point(run.at(context.line, start)).pows
      start +
      1L +
      asinh_grid_boundary(last - start - 1L, index => {
        context.point(run.at(context.line, start + 1L + index)).pows != pows
      })
    }
    let reverse = context.value(run, start, factor) >
      context.value(run, finish - 1L, factor)
    asinh_grid_heap_push(
      heap,
      asinh_grid_cursor(
        context, run, start, finish, reverse, factor, subdivision, multiplier, 0L,
      ),
    )
    start = finish
  }
}

///|
fn asinh_grid_heap_push(
  heap : Array[AsinhGridCursor],
  cursor : AsinhGridCursor,
) -> Unit {
  heap.push(cursor)
  let mut index = heap.length() - 1
  while index > 0 {
    let parent = (index - 1) / 2
    if !asinh_grid_cursor_less(heap[index], heap[parent]) {
      break
    }
    let value = heap[index]
    heap[index] = heap[parent]
    heap[parent] = value
    index = parent
  }
}

///|
fn asinh_grid_heap_pop(heap : Array[AsinhGridCursor]) -> AsinhGridCursor {
  let result = heap[0]
  let last = heap.pop().unwrap()
  if !heap.is_empty() {
    heap[0] = last
    let mut index = 0
    while index * 2 + 1 < heap.length() {
      let left = index * 2 + 1
      let right = left + 1
      let child = if right < heap.length() &&
        asinh_grid_cursor_less(heap[right], heap[left]) {
        right
      } else {
        left
      }
      if !asinh_grid_cursor_less(heap[child], heap[index]) {
        break
      }
      let value = heap[index]
      heap[index] = heap[child]
      heap[child] = value
      index = child
    }
  }
  result
}
