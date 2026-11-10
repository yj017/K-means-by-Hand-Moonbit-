///|
/// A collection of marker paths with per-point styles.
///
/// This is the data model used by the collection form of scatter.  Colors are
/// CSS-compatible strings and sizes are marker areas; a size of `s` is
/// rendered with radius `sqrt(s)` in SVG display units.
pub struct PathCollection {
  points : Array[@core.Point]
  styles : Array[@core.Style]
}

///|
fn[T] collection_values(
  values : Array[T],
  count : Int32,
  default : T,
) -> Array[T] {
  if count == 0 {
    []
  } else if values.length() == 0 {
    let result = Array(capacity=count)
    for _ in 0..<count {
      result.push(default)
    }
    result
  } else if values.length() == 1 {
    let result = Array(capacity=count)
    for _ in 0..<count {
      result.push(values[0])
    }
    result
  } else {
    values.copy()
  }
}

///|
/// Construct a marker collection with broadcastable colors and sizes.
pub fn path_collection(
  points : Array[@core.Point],
  colors~ : Array[String] = [],
  sizes~ : Array[Double] = [],
) -> PathCollection raise @core.DataError {
  let count = points.length()
  if count != 0 &&
    colors.length() != 0 &&
    colors.length() != 1 &&
    colors.length() != count {
    raise @core.DataError::LengthMismatch(
      expected=count,
      actual=colors.length(),
    )
  }
  if count != 0 &&
    sizes.length() != 0 &&
    sizes.length() != 1 &&
    sizes.length() != count {
    raise @core.DataError::LengthMismatch(expected=count, actual=sizes.length())
  }
  for size in sizes {
    if size.is_nan() || size.is_inf() || size < 0.0 {
      raise @core.DataError::InvalidCollection(
        message="marker sizes must be finite and non-negative",
      )
    }
  }
  let resolved_colors = collection_values(colors, count, "#ff7f0e")
  let resolved_sizes = collection_values(sizes, count, 12.25)
  let styles = Array(capacity=count)
  for i in 0..<count {
    styles.push(
      @core.style(
        resolved_colors[i],
        width=0.0,
        radius=resolved_sizes[i].sqrt(),
      ),
    )
  }
  { points: points.copy(), styles, }
}

///|
/// Return a copy of the collection's data points.
pub fn PathCollection::points(self : PathCollection) -> Array[@core.Point] {
  self.points.copy()
}

///|
/// Return a copy of the per-point styles.
pub fn PathCollection::styles(self : PathCollection) -> Array[@core.Style] {
  self.styles.copy()
}

///|
/// Return the number of markers in this collection.
pub fn PathCollection::length(self : PathCollection) -> Int32 {
  self.points.length()
}

///|
/// Copy a collection for the owning figure's value semantics.
fn copy_path_collection(collection : PathCollection) -> PathCollection {
  { points: collection.points.copy(), styles: collection.styles.copy(), }
}

///|
/// Add a per-point marker collection to the default axes.
pub fn Figure::scatter_collection(
  self : Figure,
  points : Array[@core.Point],
  colors~ : Array[String] = [],
  sizes~ : Array[Double] = [],
  label~ : String = "",
) -> PathCollection raise @core.DataError {
  self.axes().scatter_collection(points, colors~, sizes~, label~)
}

///|
/// Add a per-point marker collection to this axes.
pub fn Axes::scatter_collection(
  self : Axes,
  points : Array[@core.Point],
  colors~ : Array[String] = [],
  sizes~ : Array[Double] = [],
  label~ : String = "",
) -> PathCollection raise @core.DataError {
  let collection = path_collection(points, colors~, sizes~)
  self.push_artist(Artist::PathCollection(collection))
  let legend_color = if colors.length() == 0 { "#ff7f0e" } else { colors[0] }
  self.add_auto_legend(label, legend_color, LegendKind::Marker)
  collection
}
