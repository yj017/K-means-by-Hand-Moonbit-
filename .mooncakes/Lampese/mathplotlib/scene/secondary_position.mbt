///|
// A failed blend leaves the installed locator unchanged even though the raw
// location metadata has already been assigned by set_location.
priv struct SecondaryLocationLocator {
  position : Double
  transform : @transforms.Affine2D?
}

///|
fn secondary_location_position(location : SecondaryAxisLocation) -> Double {
  match location {
    Top | Right => 1.0
    Bottom | Left => 0.0
    Position(value) => value
  }
}

///|
/// Return the requested numerical location without changing active geometry.
pub fn SecondaryAxis::position(self : SecondaryAxis) -> Double {
  secondary_location_position(self.location)
}

///|
pub fn SecondaryAxis::alignment(self : SecondaryAxis) -> SecondaryAxisAlignment {
  self.alignment
}

///|
/// Change the requested location. Positioning is deferred to an aspect stage.
pub fn SecondaryAxis::set_location(
  self : SecondaryAxis,
  location : SecondaryAxisLocation,
  transform~ : @transforms.Affine2D? = None,
) -> Unit raise @core.DataError {
  let valid = if self.horizontal {
    location is (Top | Bottom | Position(_))
  } else {
    location is (Left | Right | Position(_))
  }
  if !valid {
    raise @core.DataError::InvalidTicks(
      message=if self.horizontal {
        "secondary x axis location must be top or bottom"
      } else {
        "secondary y axis location must be left or right"
      },
    )
  }
  self.location = location
  if transform is Some(value) && !value.is_separable() {
    raise @core.DataError::InvalidTicks(
      message="ValueError: Both *x_transform* and *y_transform* must be 2D affine transforms",
    )
  }
  self.location_locator = {
    position: secondary_location_position(location),
    transform,
  }
}

///|
/// Change only the visible decoration side, independently of the location.
pub fn SecondaryAxis::set_alignment(
  self : SecondaryAxis,
  alignment : SecondaryAxisAlignment,
) -> Unit raise @core.DataError {
  let valid = if self.horizontal {
    alignment is (Top | Bottom)
  } else {
    alignment is (Left | Right)
  }
  if !valid {
    raise @core.DataError::InvalidTicks(
      message=if self.horizontal {
        "secondary x axis alignment must be top or bottom"
      } else {
        "secondary y axis alignment must be left or right"
      },
    )
  }
  self.alignment = alignment
}

///|
fn SecondaryAxis::figure_to(self : SecondaryAxis) -> @transforms.Affine2D {
  @transforms.scaling(self.figure_bounds.width(), self.figure_bounds.height())
}

///|
fn SecondaryAxis::display_bounds(self : SecondaryAxis) -> @transforms.BBox {
  self.active_bounds.transformed(self.figure_to())
}

///|
// Do not recover bottom-up formatter geometry from screen edges: subtracting
// the figure height twice would change the already-rounded display endpoints.
fn SecondaryAxis::formatter_geometry(self : SecondaryAxis) -> (Double, Double) {
  let bounds = self.display_bounds()
  if self.horizontal {
    (bounds.x0(), bounds.width())
  } else {
    (bounds.y0(), bounds.height())
  }
}

///|
fn SecondaryAxis::drawing_bounds(
  self : SecondaryAxis,
) -> (Double, Double, Double, Double) {
  let bounds = self.display_bounds()
  let height = self.figure_bounds.height()
  (bounds.x0(), height - bounds.y1(), bounds.x1(), height - bounds.y0())
}

///|
// The source locator returns a normalized Bbox before apply_aspect maps limits.
// Capture the requested thin box first so a mapping callback can only replace
// the NEXT locator, not the position already being applied in this call.
fn SecondaryAxis::positioned_aspect(
  self : SecondaryAxis,
  left : Double,
  top : Double,
  width : Double,
  height : Double,
) -> Unit raise @core.DataError {
  let locator = self.location_locator
  let position = locator.position
  let requested = if self.horizontal {
    @transforms.bbox_from_bounds(0.0, position, 1.0, 1.0e-10)
  } else {
    @transforms.bbox_from_bounds(position, 0.0, 1.0e-10, 1.0)
  }
  let figure_width = self.figure_bounds.width()
  let figure_height = self.figure_bounds.height()
  // The diagonal figure inverse uses direct reciprocal, not the generic
  // determinant inverse; the latter can differ by one binary64 rounding.
  let figure_from = @transforms.scaling(1.0 / figure_width, 1.0 / figure_height)
  let parent_to = @transforms.affine_from_values(
    width,
    0.0,
    0.0,
    height,
    left,
    figure_height - top - height,
  )
  let location_to = match locator.transform {
    None => parent_to
    Some(value) => {
      let parent = @transforms.affine_transform(parent_to)
      let user = @transforms.affine_transform(value)
      if self.horizontal {
        @transforms.blended_transform(parent, user).affine()
      } else {
        @transforms.blended_transform(user, parent).affine()
      }
    }
  }
  let candidate = requested.transformed(figure_from.then(location_to))
  let (lower, upper) = self.mapped_parent_view_interval()
  self.store_formatter_view(lower, upper)
  self.active_bounds = candidate
}
