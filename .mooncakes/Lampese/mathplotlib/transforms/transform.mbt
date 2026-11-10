///|
/// A composable two-dimensional transform tree.
///
/// Every constructor in this first tree is affine in the plane, but keeping
/// composition explicit mirrors Matplotlib's transform graph and lets layout
/// code carry one value through point, path, and BBox operations.
pub(all) enum Transform2D {
  Affine(Affine2D)
  Composite(Transform2D, Transform2D)
  BboxMap(BBox, BBox)
  BboxTo(BBox)
  BboxFrom(BBox)
  Blended(Transform2D, Transform2D)
  ScaledTranslation(Double, Double, Affine2D)
}

///|
/// Wrap an affine transform in the transform tree.
pub fn affine_transform(value : Affine2D) -> Transform2D {
  Transform2D::Affine(value)
}

///|
/// Return the identity transform as a tree node.
pub fn identity_transform() -> Transform2D {
  Transform2D::Affine(identity())
}

///|
/// Compose transforms so that `second` is applied first, matching
/// `Affine2D::then`.
pub fn composite_transform(
  first : Transform2D,
  second : Transform2D,
) -> Transform2D {
  Transform2D::Composite(first, second)
}

///|
/// Map coordinates linearly from one bounding box to another.
pub fn bbox_transform(input : BBox, output : BBox) -> Transform2D {
  Transform2D::BboxMap(input, output)
}

///|
/// Map the unit box to `output`.
pub fn bbox_transform_to(output : BBox) -> Transform2D {
  Transform2D::BboxTo(output)
}

///|
/// Map `input` to the unit box.
pub fn bbox_transform_from(input : BBox) -> Transform2D {
  Transform2D::BboxFrom(input)
}

///|
/// Use one transform for the x coordinate and another for y.
pub fn blended_transform(
  x_transform : Transform2D,
  y_transform : Transform2D,
) -> Transform2D {
  Transform2D::Blended(x_transform, y_transform)
}

///|
/// Translate by `(x, y)` after expressing that offset in `scale_transform`'s
/// coordinate system. This is the transform-tree equivalent of
/// Matplotlib's `ScaledTranslation`.
pub fn scaled_translation(
  x : Double,
  y : Double,
  scale_transform : Affine2D,
) -> Transform2D {
  Transform2D::ScaledTranslation(x, y, scale_transform)
}

///|
fn bbox_map_affine(input : BBox, output : BBox) -> Affine2D {
  let input_width = input.width()
  let input_height = input.height()
  let x_scale = output.width() / input_width
  let y_scale = output.height() / input_height
  affine_from_values(
    x_scale,
    0.0,
    0.0,
    y_scale,
    output.x0() - input.x0() * x_scale,
    output.y0() - input.y0() * y_scale,
  )
}

///|
fn Transform2D::to_affine(self : Transform2D) -> Affine2D {
  match self {
    Transform2D::Affine(value) => value
    Transform2D::Composite(first, second) =>
      first.to_affine().then(second.to_affine())
    Transform2D::BboxMap(input, output) => bbox_map_affine(input, output)
    Transform2D::BboxTo(output) => bbox_map_affine(unit_bbox(), output)
    Transform2D::BboxFrom(input) => bbox_map_affine(input, unit_bbox())
    Transform2D::Blended(x_transform, y_transform) => {
      let x_values = x_transform.to_affine().to_values()
      let y_values = y_transform.to_affine().to_values()
      let (x_a, _, x_c, _, x_e, _) = x_values
      let (_, y_b, _, y_d, _, y_f) = y_values
      affine_from_values(x_a, y_b, x_c, y_d, x_e, y_f)
    }
    Transform2D::ScaledTranslation(x, y, scale_transform) => {
      let offset = scale_transform.apply(@core.point(x, y))
      affine_from_values(1.0, 0.0, 0.0, 1.0, offset.x(), offset.y())
    }
  }
}

///|
/// Materialize the current tree as one affine transform.
pub fn Transform2D::affine(self : Transform2D) -> Affine2D {
  self.to_affine()
}

///|
/// Apply the transform to one point.
pub fn Transform2D::apply(
  self : Transform2D,
  value : @core.Point,
) -> @core.Point {
  self.to_affine().apply(value)
}

///|
/// Apply the transform to an array without mutating the input.
pub fn Transform2D::apply_all(
  self : Transform2D,
  values : Array[@core.Point],
) -> Array[@core.Point] {
  self.to_affine().apply_all(values)
}

///|
/// Apply the transform to a displacement vector.
pub fn Transform2D::apply_delta(
  self : Transform2D,
  value : @core.Point,
) -> @core.Point {
  self.to_affine().apply_delta(value)
}

///|
/// Compose a tree transform using the same order as `Affine2D::then`.
pub fn Transform2D::then(
  self : Transform2D,
  other : Transform2D,
) -> Transform2D {
  composite_transform(self, other)
}

///|
/// Return whether the materialized transform has no x/y cross terms.
pub fn Transform2D::is_separable(self : Transform2D) -> Bool {
  self.to_affine().is_separable()
}

///|
/// Invert the transform tree.
pub fn Transform2D::inverse(
  self : Transform2D,
) -> Transform2D raise TransformError {
  match self {
    Transform2D::Affine(value) => Transform2D::Affine(value.inverse())
    Transform2D::Composite(first, second) =>
      Transform2D::Composite(second.inverse(), first.inverse())
    Transform2D::BboxMap(input, output) => Transform2D::BboxMap(output, input)
    Transform2D::BboxTo(output) => Transform2D::BboxFrom(output)
    Transform2D::BboxFrom(input) => Transform2D::BboxTo(input)
    Transform2D::Blended(x_transform, y_transform) => {
      if !x_transform.is_separable() || !y_transform.is_separable() {
        raise TransformError::Singular
      }
      Transform2D::Blended(x_transform.inverse(), y_transform.inverse())
    }
    Transform2D::ScaledTranslation(x, y, scale_transform) =>
      Transform2D::Affine(
        scaled_translation(x, y, scale_transform).affine().inverse(),
      )
  }
}

///|
/// Transform all four corners and return the enclosing axis-aligned box.
pub fn Transform2D::transform_bbox(self : Transform2D, value : BBox) -> BBox {
  value.transformed(self.to_affine())
}

///|
/// Transform every vertex and code in a path.
pub fn Transform2D::transform_path(
  self : Transform2D,
  value : Path,
) -> Path raise PathError {
  value.transformed(self.to_affine())
}
