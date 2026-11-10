///|
/// Build a validated triangular mesh for reuse by multiple plot calls.
pub fn triangulation(
  xs : Array[Double],
  ys : Array[Double],
  triangles~ : Array[Array[Int32]] = [],
  mask~ : Array[Bool] = [],
) -> @scene.Triangulation raise @core.DataError {
  @scene.triangulation(xs, ys, triangles~, mask~)
}

///|
/// Return a point-to-triangle finder for a triangulation.
pub fn get_trifinder(mesh : @scene.Triangulation) -> @scene.TriFinder {
  mesh.get_trifinder()
}

///|
/// Draw triangle edges from vertices and optional index triples.
pub fn triplot(
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  mask~ : Array[Bool] = [],
) -> Unit raise @core.DataError {
  require_axes().triplot(xs, ys, triangles, color~, linewidth~, label~, mask~)
}

///|
/// Draw the unique visible edges of a reusable triangular mesh.
pub fn triplot_triangulation(
  mesh : @scene.Triangulation,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().triplot_triangulation(mesh, color~, linewidth~, label~)
}

///|
/// Fill triangle faces using the mean of their vertex scalar values.
pub fn tripcolor(
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  values : Array[Double],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  label~ : String = "",
  mask~ : Array[Bool] = [],
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().tripcolor(
        xs,
        ys,
        triangles,
        values,
        vmin~,
        vmax~,
        cmap~,
        label~,
        mask~,
      )
    (Some(vmin), None) =>
      require_axes().tripcolor(
        xs,
        ys,
        triangles,
        values,
        vmin~,
        cmap~,
        label~,
        mask~,
      )
    (None, Some(vmax)) =>
      require_axes().tripcolor(
        xs,
        ys,
        triangles,
        values,
        vmax~,
        cmap~,
        label~,
        mask~,
      )
    (None, None) =>
      require_axes().tripcolor(xs, ys, triangles, values, cmap~, label~, mask~)
  }
}

///|
/// Fill the faces of a reusable triangular mesh using vertex or face values.
pub fn tripcolor_triangulation(
  mesh : @scene.Triangulation,
  values : Array[Double],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  label~ : String = "",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      require_axes().tripcolor_triangulation(
        mesh,
        values,
        vmin~,
        vmax~,
        cmap~,
        label~,
      )
    (Some(vmin), None) =>
      require_axes().tripcolor_triangulation(mesh, values, vmin~, cmap~, label~)
    (None, Some(vmax)) =>
      require_axes().tripcolor_triangulation(mesh, values, vmax~, cmap~, label~)
    (None, None) =>
      require_axes().tripcolor_triangulation(mesh, values, cmap~, label~)
  }
}

///|
/// Draw contour lines over a validated triangular mesh.
pub fn tricontour(
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  mask~ : Array[Bool] = [],
  locator? : @ticker.Locator,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> @scene.ContourSet raise @core.DataError {
  require_axes().tricontour(
    xs,
    ys,
    triangles,
    values,
    levels~,
    nlevels~,
    color~,
    linewidth~,
    label~,
    mask~,
    locator~,
    colors~,
    linewidths~,
  )
}

///|
/// Draw contour lines from a reusable triangular mesh.
pub fn tricontour_triangulation(
  mesh : @scene.Triangulation,
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  locator? : @ticker.Locator,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> @scene.ContourSet raise @core.DataError {
  require_axes().tricontour_triangulation(
    mesh,
    values,
    levels~,
    nlevels~,
    color~,
    linewidth~,
    label~,
    locator~,
    colors~,
    linewidths~,
  )
}

///|
/// Draw filled contour bands over a validated triangular mesh.
pub fn tricontourf(
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  mask~ : Array[Bool] = [],
  locator? : @ticker.Locator,
) -> @scene.ContourSet raise @core.DataError {
  require_axes().tricontourf(
    xs,
    ys,
    triangles,
    values,
    levels~,
    nlevels~,
    colors~,
    cmap~,
    label~,
    extend_mode~,
    mask~,
    locator~,
  )
}

///|
/// Draw filled contour bands from a reusable triangular mesh.
pub fn tricontourf_triangulation(
  mesh : @scene.Triangulation,
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  locator? : @ticker.Locator,
) -> @scene.ContourSet raise @core.DataError {
  require_axes().tricontourf_triangulation(
    mesh,
    values,
    levels~,
    nlevels~,
    colors~,
    cmap~,
    label~,
    extend_mode~,
    locator~,
  )
}
