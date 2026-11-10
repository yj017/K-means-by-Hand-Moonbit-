///|
// Two interleaved lattices share the metric dx^2 + 3*dy^2 and these exact
// six-vertex Voronoi cells. See the pinned Matplotlib hexbin source described
// in docs/HEXBIN_INTERACTION.md; no rectangular bucket stands in for a hex.
priv struct HexbinGrid {
  xmin : Double
  ymin : Double
  sx : Double
  sy : Double
  nx : Int32
  ny : Int32
}

///|
fn hexbin_grid(
  xmin : Double,
  xmax : Double,
  ymin : Double,
  ymax : Double,
  nx : Int32,
) -> HexbinGrid raise @core.DataError {
  let ny = Int32::max(1, (nx.to_double() / 3.0.sqrt()).floor().to_int())
  let sx = (xmax - xmin) / nx.to_double()
  let sy = (ymax - ymin) / ny.to_double()
  if !hexbin_finite(xmin) ||
    !hexbin_finite(ymin) ||
    !hexbin_finite(sx) ||
    !hexbin_finite(sy) ||
    sx <= 0.0 ||
    sy <= 0.0 ||
    ny > 1073741823 {
    raise @core.DataError::InvalidStatistics(
      message="hexbin grid must have finite positive steps and representable indices",
    )
  }
  { xmin, ymin, sx, sy, nx, ny, }
}

///|
// Match nearest-integer ties-to-even explicitly, independently of a target's
// native rounding convention. Normalized grid coordinates are nonnegative.
fn hexbin_nearest_integer(value : Double) -> Int32 {
  let lower = value.floor().to_int()
  let fraction = value - lower.to_double()
  if fraction > 0.5 || (fraction == 0.5 && lower % 2 != 0) {
    lower + 1
  } else {
    lower
  }
}

///|
fn HexbinGrid::cell(
  self : HexbinGrid,
  x : Double,
  y : Double,
) -> (Int32, Int32) {
  let ix = ((x - self.xmin) / self.sx).clamp(min=0.0, max=self.nx.to_double())
  let iy = ((y - self.ymin) / self.sy).clamp(min=0.0, max=self.ny.to_double())
  let ax = hexbin_nearest_integer(ix)
  let ay = hexbin_nearest_integer(iy)
  // On an exact maximum edge the half-grid candidate just outside has an
  // equally near inside partner. Clamp before comparing, so inclusive extent
  // samples are neither dropped nor assigned to an integer hex too far away.
  let bx = Int32::min(self.nx - 1, ix.floor().to_int())
  let by = Int32::min(self.ny - 1, iy.floor().to_int())
  let adx = ix - ax.to_double()
  let ady = iy - ay.to_double()
  let bdx = ix - bx.to_double() - 0.5
  let bdy = iy - by.to_double() - 0.5
  let a_distance = adx * adx + 3.0 * ady * ady
  let b_distance = bdx * bdx + 3.0 * bdy * bdy
  if a_distance < b_distance {
    (ax, ay * 2)
  } else {
    // Odd rows are the half-offset lattice. Each row's column remains a
    // whole x-step index; the row's parity supplies its half-step x offset.
    (bx, by * 2 + 1)
  }
}

///|
fn HexbinGrid::center(
  self : HexbinGrid,
  column : Int32,
  row : Int32,
) -> (Double, Double) {
  (
    self.xmin + (column.to_double() + (row % 2).to_double() / 2.0) * self.sx,
    self.ymin + row.to_double() / 2.0 * self.sy,
  )
}

///|
fn HexbinGrid::vertices(
  self : HexbinGrid,
  column : Int32,
  row : Int32,
  x_scale : @scale.Scale,
  y_scale : @scale.Scale,
) -> Array[@core.Point] {
  let result = Array(capacity=6)
  let x_index = 2.0 * column.to_double() + (row % 2).to_double()
  let y_index = 3.0 * row.to_double()
  // Global integer numerators ensure neighboring cells compute shared
  // vertices with the same expression, including after inverse transforms.
  for
    (dx, dy) in [
      (1.0, -1.0),
      (1.0, 1.0),
      (0.0, 2.0),
      (-1.0, 1.0),
      (-1.0, -1.0),
      (0.0, -2.0),
    ] {
    result.push(
      @core.point(
        x_scale.inverse(self.xmin + (x_index + dx) / 2.0 * self.sx),
        y_scale.inverse(self.ymin + (y_index + dy) / 6.0 * self.sy),
      ),
    )
  }
  result
}

///|
priv struct HexbinMarginals {
  columns : Map[(Int32, Int32), Int32]
  rows : Map[Int32, Int32]
}

///|
fn hexbin_marginals(cells : Array[HexbinCell]) -> HexbinMarginals {
  let columns : Map[(Int32, Int32), Int32] = Map([])
  let rows : Map[Int32, Int32] = Map([])
  for cell in cells {
    // Integer and half-grid columns have different actual x centers.
    let key = (cell.col, cell.row % 2)
    let column_count = match columns.get(key) {
      Some(n) => n
      None => 0
    }
    let row_count = match rows.get(cell.row) {
      Some(n) => n
      None => 0
    }
    columns[key] = column_count + cell.count
    rows[cell.row] = row_count + cell.count
  }
  { columns, rows, }
}
