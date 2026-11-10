///|
pub fn SecondaryAxis::set_tick_label_size(
  self : SecondaryAxis,
  size : Double,
) -> Unit {
  self.numeric_axis.set_tick_label_size(size)
}

///|
pub fn SecondaryAxis::tick_label_size(self : SecondaryAxis) -> Double {
  self.numeric_axis.tick_label_size()
}

///|
pub fn SecondaryAxis::get_tick_space(self : SecondaryAxis) -> Double {
  self.numeric_axis.get_tick_space()
}

///|
/// Synchronize limits using the currently installed context, without scale reset.
pub fn SecondaryAxis::apply_aspect(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  let (lower, upper) = self.mapped_parent_view_interval()
  self.store_formatter_view(lower, upper)
  self.active_bounds = self.original_bounds
}

///|
// Positioned aspect is distinct from draw's later parent-scale synchronization.
fn SecondaryAxis::synchronize_formatter_frame(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  let (lower, upper) = self.mapped_parent_view_interval()
  self.store_formatter_view(lower, upper)
  let (origin, length) = match self.parent_axis {
    Some(parent) =>
      parent
      .formatter_display_geometry()
      .unwrap_or_else(() => {
        let original = self.original_bounds.transformed(self.figure_to())
        if self.horizontal {
          (original.x0(), original.width())
        } else {
          (original.y0(), original.height())
        }
      })
    None => {
      let original = self.original_bounds.transformed(self.figure_to())
      if self.horizontal {
        (original.x0(), original.width())
      } else {
        (original.y0(), original.height())
      }
    }
  }
  // Retain the D40 controlled one-dimensional geometry profile without a second
  // authority. Real positioned rendering supplies the full parent frame.
  let bounds = self.active_bounds
  if self.horizontal {
    let reciprocal = 1.0 / self.figure_bounds.width()
    self.active_bounds = @transforms.bbox(
      origin * reciprocal,
      bounds.y0(),
      (origin + length) * reciprocal,
      bounds.y1(),
    )
  } else {
    let reciprocal = 1.0 / self.figure_bounds.height()
    self.active_bounds = @transforms.bbox(
      bounds.x0(),
      origin * reciprocal,
      bounds.x1(),
      (origin + length) * reciprocal,
    )
  }
}

///|
fn SecondaryAxis::store_formatter_view(
  self : SecondaryAxis,
  lower : Double,
  upper : Double,
) -> Unit raise @core.DataError {
  // Match the existing checked secondary error before touching old scale state.
  if lower.is_nan() || lower.is_inf() || upper.is_nan() || upper.is_inf() {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Axis limits cannot be NaN or Inf",
    )
  }
  ignore(
    self.numeric_axis.set_bound_limits_checked(
      lower,
      upper,
      automatic=Some(false),
    ),
  )
}

///|
fn SecondaryAxis::initialize_formatter_view(
  self : SecondaryAxis,
) -> Unit raise @core.DataError {
  self.synchronize_parent_scale()
}

///|
// Locators and formatters query the child's actual stored view, not its parent.
fn SecondaryAxis::numeric_view_interval(
  self : SecondaryAxis,
) -> (Double, Double) raise @core.DataError {
  self.numeric_axis.view_interval_checked()
}

///|
// Parent limits are consumed only at the source aspect/draw synchronization stage.
fn SecondaryAxis::mapped_parent_view_interval(
  self : SecondaryAxis,
) -> (Double, Double) raise @core.DataError {
  let (lower, upper) = match self.parent_axis {
    Some(parent) => parent.view_interval_checked()
    None => (0.0, 1.0)
  }
  let first = (self.forward)(lower)
  let last = (self.forward)(upper)
  if (first < last) != (lower < upper) {
    (last, first)
  } else {
    (first, last)
  }
}
