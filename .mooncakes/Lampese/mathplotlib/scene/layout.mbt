///|
/// Construct a regular subplot grid using this figure's display dimensions.
pub fn Figure::grid_spec(
  self : Figure,
  rows : Int32,
  columns : Int32,
  hspace? : Double,
  vspace? : Double,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> @gridspec.GridSpec raise @gridspec.LayoutError {
  ignore(self)
  @gridspec.gridspec(
    rows,
    columns,
    hspace?,
    vspace?,
    width_ratios~,
    height_ratios~,
  )
}

///|
/// Compute subplot rectangles for a regular grid on this figure.
pub fn Figure::grid_cells(
  self : Figure,
  rows : Int32,
  columns : Int32,
  hspace? : Double,
  vspace? : Double,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> Array[@gridspec.Rect] raise @gridspec.LayoutError {
  let grid = self.grid_spec(
    rows,
    columns,
    hspace?,
    vspace?,
    width_ratios~,
    height_ratios~,
  )
  let result = Array(capacity=rows * columns)
  for row in 0..<rows {
    for column in 0..<columns {
      result.push(self.subplot_rect(grid.cell_spec(row, column)))
    }
  }
  result
}

///|
/// Return the current normalized bounds as `(left, bottom, right, top)`.
/// Initial bounds correspond to the figure's 56-pixel margin on each side.
pub fn Figure::subplot_bounds(
  self : Figure,
) -> (Double, Double, Double, Double) {
  (self.subplot_left, self.subplot_bottom, self.subplot_right, self.subplot_top)
}

///|
fn finite_layout_value(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
/// Add an axes panel at a normalized Figure rectangle.
///
/// The four arguments use Matplotlib's lower-left origin: `left` and `bottom`
/// locate the panel, while `width` and `height` describe its size. The panel
/// is independent from GridSpec and remains at this position after later
/// `subplots_adjust` calls. Zero width or height is allowed; negative sizes
/// and non-finite coordinates are rejected without changing the figure.
/// Rectangles may extend beyond the figure.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure(width=400, height=300)
///   let axes = try! fig.add_axes(0.1, 0.2, 0.5, 0.4)
///   let rect = axes.rect().unwrap()
///   assert_eq(
///     (rect.x(), rect.y(), rect.width(), rect.height()),
///     (40.0, 120.0, 200.0, 120.0),
///   )
/// }
/// ```
pub fn Figure::add_axes(
  self : Figure,
  left : Double,
  bottom : Double,
  width : Double,
  height : Double,
) -> Axes raise @gridspec.LayoutError {
  let rect = self.position_rect(left, bottom, width, height)
  let state = new_axes_state(Some(rect), None)
  self.insert_axes_state(state)
  { figure: self, state, }
}

///|
fn Figure::position_rect(
  self : Figure,
  left : Double,
  bottom : Double,
  width : Double,
  height : Double,
) -> @gridspec.Rect raise @gridspec.LayoutError {
  if !finite_layout_value(left) ||
    !finite_layout_value(bottom) ||
    !finite_layout_value(width) ||
    !finite_layout_value(height) ||
    !finite_layout_value(left + width) ||
    !finite_layout_value(bottom + height) ||
    width < 0.0 ||
    height < 0.0 {
    raise @gridspec.LayoutError::InvalidBounds
  }
  let figure_width = Double::from_int(self.width)
  let figure_height = Double::from_int(self.height)
  let rect = @gridspec.rect(
    figure_width * left,
    figure_height * (1.0 - bottom - height),
    figure_width * width,
    figure_height * height,
  )
  if !finite_layout_value(rect.x()) ||
    !finite_layout_value(rect.y()) ||
    !finite_layout_value(rect.width()) ||
    !finite_layout_value(rect.height()) ||
    !finite_layout_value(rect.x() + rect.width()) ||
    !finite_layout_value(rect.y() + rect.height()) {
    raise @gridspec.LayoutError::InvalidBounds
  }
  rect
}

///|
/// Adjust subplot bounds and spacing, including already-created nested axes.
///
/// Bounds are fractions of the figure width/height, measured from the bottom
/// left. `wspace` controls horizontal gaps and `hspace` vertical gaps, as
/// fractions of the average panel size. Existing grid constructors retain
/// their horizontal `hspace` / vertical `vspace` names. Explicit grid spacing
/// takes precedence over figure spacing. Unspecified values are preserved.
///
/// Bounds must be finite with left < right and bottom < top; they may extend
/// beyond the figure. Spacing must be finite and nonnegative. Invalid calls
/// leave the existing layout untouched. Initial spacing remains 0.1.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure(width=400, height=300)
///   let axes = try! fig.subplots(1, 2)
///   try! fig.subplots_adjust(
///     left=0.25,
///     bottom=0.25,
///     right=0.75,
///     top=0.75,
///     wspace=0.5,
///   )
///   assert_eq(fig.subplot_bounds(), (0.25, 0.25, 0.75, 0.75))
///   match axes[0].rect() {
///     Some(rect) => assert_eq(rect.width(), 80.0)
///     None => fail("expected a subplot rectangle")
///   }
/// }
/// ```
pub fn Figure::subplots_adjust(
  self : Figure,
  left? : Double,
  bottom? : Double,
  right? : Double,
  top? : Double,
  wspace? : Double,
  hspace? : Double,
) -> Unit raise @gridspec.LayoutError {
  let next_left = left.unwrap_or(self.subplot_left)
  let next_bottom = bottom.unwrap_or(self.subplot_bottom)
  let next_right = right.unwrap_or(self.subplot_right)
  let next_top = top.unwrap_or(self.subplot_top)
  if !finite_layout_value(next_left) ||
    !finite_layout_value(next_bottom) ||
    !finite_layout_value(next_right) ||
    !finite_layout_value(next_top) ||
    !finite_layout_value(next_right - next_left) ||
    !finite_layout_value(next_top - next_bottom) ||
    next_left >= next_right ||
    next_bottom >= next_top {
    raise @gridspec.LayoutError::InvalidBounds
  }
  for spacing in [wspace, hspace] {
    if spacing is Some(value) && (!finite_layout_value(value) || value < 0.0) {
      raise @gridspec.LayoutError::InvalidSpacing
    }
  }
  // The convenience figure starts with an implicit single subplot. Attach a
  // spec in place so handles and plotted data survive its first adjustment.
  for state in self.axes {
    if state.val.subplot_spec is None && state.val.rect is None {
      state.val.subplot_spec = Some(@gridspec.gridspec(1, 1).cell_spec(0, 0))
    }
    if state.val.subplot_spec is Some(_) {
      state.val.position_override = None
      state.val.active_position = None
    }
  }
  self.subplot_left = next_left
  self.subplot_bottom = next_bottom
  self.subplot_right = next_right
  self.subplot_top = next_top
  if wspace is Some(_) {
    self.subplot_wspace = wspace
  }
  if hspace is Some(_) {
    self.subplot_hspace = hspace
  }
}

///|
fn Figure::subplot_rect(
  self : Figure,
  spec : @gridspec.SubplotSpec,
) -> @gridspec.Rect {
  let wspace = self.subplot_wspace
  let hspace = self.subplot_hspace
  spec.rect_with_bounds(
    self.width,
    self.height,
    self.subplot_left,
    self.subplot_bottom,
    self.subplot_right,
    self.subplot_top,
    wspace?,
    hspace?,
  )
}
