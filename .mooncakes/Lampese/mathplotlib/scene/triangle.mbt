///|
fn validate_tri_mesh(
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
) -> Unit raise @core.DataError {
  if xs.length() != ys.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=ys.length(),
    )
  }
  if xs.length() < 3 || triangles.length() == 0 {
    raise @core.DataError::InvalidContour(
      message="triangular mesh requires vertices and at least one triangle",
    )
  }
  for index in 0..<xs.length() {
    if xs[index].is_nan() ||
      xs[index].is_inf() ||
      ys[index].is_nan() ||
      ys[index].is_inf() {
      raise @core.DataError::InvalidContour(
        message="triangular mesh coordinates must be finite",
      )
    }
  }
  for triangle in triangles {
    if triangle.length() != 3 {
      raise @core.DataError::InvalidContour(
        message="each triangular mesh face must have three indices",
      )
    }
    let first = triangle[0]
    let second = triangle[1]
    let third = triangle[2]
    if first < 0 ||
      second < 0 ||
      third < 0 ||
      first >= xs.length() ||
      second >= xs.length() ||
      third >= xs.length() ||
      first == second ||
      first == third ||
      second == third {
      raise @core.DataError::InvalidContour(
        message="triangular mesh indices must be distinct and in range",
      )
    }
  }
}

///|
fn validate_tri_mask(
  mask : Array[Bool],
  triangles : Array[Array[Int32]],
) -> Unit raise @core.DataError {
  if mask.length() != 0 && mask.length() != triangles.length() {
    raise @core.DataError::LengthMismatch(
      expected=triangles.length(),
      actual=mask.length(),
    )
  }
}

///|
fn triangle_is_visible(mask : Array[Bool], index : Int32) -> Bool {
  mask.length() == 0 || !mask[index]
}

///|
fn validate_tri_contour_values(
  values : Array[Double],
) -> Unit raise @core.DataError {
  for value in values {
    if value.is_nan() || value.is_inf() {
      raise @core.DataError::NonFiniteLimit(axis="z")
    }
  }
}

///|
fn tricontour_render_filled_band(
  axes : Axes,
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  values : Array[Double],
  mask : Array[Bool],
  lower : Double,
  upper : Double,
  style : @core.Style,
  slot : Int32,
  series : String,
) -> Array[Array[@core.Point]] {
  if lower >= upper {
    return []
  }
  let polygons : Array[Array[@core.Point]] = []
  for index, triangle in triangles {
    if !triangle_is_visible(mask, index) {
      continue
    }
    let first = {
      point: @core.point(xs[triangle[0]], ys[triangle[0]]),
      value: values[triangle[0]],
    }
    let second = {
      point: @core.point(xs[triangle[1]], ys[triangle[1]]),
      value: values[triangle[1]],
    }
    let third = {
      point: @core.point(xs[triangle[2]], ys[triangle[2]]),
      value: values[triangle[2]],
    }
    let polygon = contour_clipped_triangle(first, second, third, lower, upper)
    if polygon.length() >= 3 {
      polygons.push(polygon)
    }
  }
  let merged = contour_union_polygons(polygons)
  axes.push_contourf_band(merged, style, slot, lower, upper, series)
  merged
}

///|
/// Draw triangle edges from vertices and explicit index triples.
///
/// Use `triangulation` and `triplot_triangulation` when the faces should be
/// generated automatically and reused.
pub fn Figure::triplot(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  mask~ : Array[Bool] = [],
) -> Unit raise @core.DataError {
  self.axes().triplot(xs, ys, triangles, color~, linewidth~, label~, mask~)
}

///|
/// Draw triangle edges from vertices and explicit index triples.
pub fn Axes::triplot(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  mask~ : Array[Bool] = [],
) -> Unit raise @core.DataError {
  let mesh = triangulation(xs, ys, triangles~, mask~)
  let mesh_x = mesh.x()
  let mesh_y = mesh.y()
  let mesh_triangles = mesh.triangles()
  let mesh_mask = mesh.mask()
  if linewidth.is_nan() || linewidth.is_inf() || linewidth < 0.0 {
    raise @core.DataError::InvalidContour(
      message="triplot linewidth must be finite and non-negative",
    )
  }
  let resolved_color = self.resolve_color(color)
  let style = @core.style(resolved_color, width=linewidth)
  for index, triangle in mesh_triangles {
    if !triangle_is_visible(mesh_mask, index) {
      continue
    }
    let first = @core.point(mesh_x[triangle[0]], mesh_y[triangle[0]])
    let second = @core.point(mesh_x[triangle[1]], mesh_y[triangle[1]])
    let third = @core.point(mesh_x[triangle[2]], mesh_y[triangle[2]])
    self.push_artist(Artist::Line([first, second, third, first], style))
  }
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
/// Draw each visible edge of a validated triangulation once.
pub fn Figure::triplot_triangulation(
  self : Figure,
  mesh : Triangulation,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().triplot_triangulation(mesh, color~, linewidth~, label~)
}

///|
/// Draw each visible edge of a validated triangulation once.
pub fn Axes::triplot_triangulation(
  self : Axes,
  mesh : Triangulation,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
) -> Unit raise @core.DataError {
  if linewidth.is_nan() || linewidth.is_inf() || linewidth < 0.0 {
    raise @core.DataError::InvalidContour(
      message="triplot linewidth must be finite and non-negative",
    )
  }
  let xs = mesh.x()
  let ys = mesh.y()
  let resolved_color = self.resolve_color(color)
  let style = @core.style(resolved_color, width=linewidth)
  for (first, second) in mesh.edges() {
    self.push_artist(
      Artist::Line(
        [@core.point(xs[first], ys[first]), @core.point(xs[second], ys[second])],
        style,
      ),
    )
  }
  self.add_auto_legend(label, resolved_color, LegendKind::Line)
}

///|
fn tripcolor_mesh(
  axes : Axes,
  xs : Array[Double],
  ys : Array[Double],
  triangles : Array[Array[Int32]],
  values : Array[Double],
  mask : Array[Bool],
  vmin : Double?,
  vmax : Double?,
  cmap : String,
  series : String,
) -> String? raise @core.DataError {
  validate_tri_mesh(xs, ys, triangles)
  validate_tri_mask(mask, triangles)
  if values.length() != xs.length() && values.length() != triangles.length() {
    raise @core.DataError::LengthMismatch(
      expected=xs.length(),
      actual=values.length(),
    )
  }
  let color_map = resolve_colormap(cmap)
  let norm = linear_color_norm(vmin, vmax)
  norm.autoscale_none(values)
  if !norm.scaled() {
    return None
  }
  let mut first_color : String? = None
  let face_values = values.length() == triangles.length()
  for index, triangle in triangles {
    if !triangle_is_visible(mask, index) {
      continue
    }
    let value = if face_values {
      values[index]
    } else {
      let first_value = values[triangle[0]]
      let second_value = values[triangle[1]]
      let third_value = values[triangle[2]]
      (first_value + second_value + third_value) / 3.0
    }
    if norm.is_valid(value) {
      let color = color_map
        .sample_extended(mesh_transform(norm, value))
        .to_css()
      if first_color is None {
        first_color = Some(color)
      }
      axes.push_tripcolor_face(
        [
          @core.point(xs[triangle[0]], ys[triangle[0]]),
          @core.point(xs[triangle[1]], ys[triangle[1]]),
          @core.point(xs[triangle[2]], ys[triangle[2]]),
        ],
        @core.style(color, width=0.0, fill=color),
        index,
        value,
        (triangle[0], triangle[1], triangle[2]),
        !face_values,
        series,
      )
    }
  }
  first_color
}

///|
/// Fill triangle faces using vertex means or one scalar per face.
pub fn Figure::tripcolor(
  self : Figure,
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
      self
      .axes()
      .tripcolor(xs, ys, triangles, values, vmin~, vmax~, cmap~, label~, mask~)
    (Some(vmin), None) =>
      self
      .axes()
      .tripcolor(xs, ys, triangles, values, vmin~, cmap~, label~, mask~)
    (None, Some(vmax)) =>
      self
      .axes()
      .tripcolor(xs, ys, triangles, values, vmax~, cmap~, label~, mask~)
    (None, None) =>
      self.axes().tripcolor(xs, ys, triangles, values, cmap~, label~, mask~)
  }
}

///|
/// Fill triangle faces using the mean of their vertex scalar values.
pub fn Axes::tripcolor(
  self : Axes,
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
  let mesh = triangulation(xs, ys, triangles~, mask~)
  let start = self.state.val.artists.length()
  let legend_color = match
    tripcolor_mesh(
      self,
      mesh.x(),
      mesh.y(),
      mesh.triangles(),
      values,
      mesh.mask(),
      vmin,
      vmax,
      cmap,
      label,
    ) {
    Some(color) => color
    None => "#000000"
  }
  self.add_auto_legend(
    label,
    legend_color,
    LegendKind::Patch,
    record_series=self.state.val.artists.length() > start,
  )
}

///|
/// Fill faces from a validated triangulation using vertex or face values.
pub fn Figure::tripcolor_triangulation(
  self : Figure,
  mesh : Triangulation,
  values : Array[Double],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  label~ : String = "",
) -> Unit raise @core.DataError {
  match (vmin, vmax) {
    (Some(vmin), Some(vmax)) =>
      self
      .axes()
      .tripcolor_triangulation(mesh, values, vmin~, vmax~, cmap~, label~)
    (Some(vmin), None) =>
      self.axes().tripcolor_triangulation(mesh, values, vmin~, cmap~, label~)
    (None, Some(vmax)) =>
      self.axes().tripcolor_triangulation(mesh, values, vmax~, cmap~, label~)
    (None, None) =>
      self.axes().tripcolor_triangulation(mesh, values, cmap~, label~)
  }
}

///|
/// Fill faces from a validated triangulation using vertex or face values.
pub fn Axes::tripcolor_triangulation(
  self : Axes,
  mesh : Triangulation,
  values : Array[Double],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "viridis",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let start = self.state.val.artists.length()
  let legend_color = match
    tripcolor_mesh(
      self,
      mesh.x(),
      mesh.y(),
      mesh.triangles(),
      values,
      mesh.mask(),
      vmin,
      vmax,
      cmap,
      label,
    ) {
    Some(color) => color
    None => "#000000"
  }
  self.add_auto_legend(
    label,
    legend_color,
    LegendKind::Patch,
    record_series=self.state.val.artists.length() > start,
  )
}

///|
/// Draw contour lines over a validated triangular mesh.
pub fn Figure::tricontour(
  self : Figure,
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
) -> ContourSet raise @core.DataError {
  self
  .axes()
  .tricontour(
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
/// Draw contour lines over a validated triangular mesh.
pub fn Axes::tricontour(
  self : Axes,
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
  locator~ : @ticker.Locator? = None,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> ContourSet raise @core.DataError {
  let mesh = triangulation(xs, ys, triangles~, mask~)
  let mesh_x = mesh.x()
  let mesh_y = mesh.y()
  let mesh_triangles = mesh.triangles()
  let mesh_mask = mesh.mask()
  if values.length() != mesh_x.length() {
    raise @core.DataError::LengthMismatch(
      expected=mesh_x.length(),
      actual=values.length(),
    )
  }
  validate_tri_contour_values(values)
  let resolved_levels = contour_levels(
    [values],
    levels,
    nlevels,
    false,
    locator,
  )
  validate_contour_style(linewidth)
  validate_contour_linewidths(linewidths)
  let resolved_color = if colors.length() > 0 {
    if color == "" {
      colors[0]
    } else {
      color
    }
  } else {
    self.resolve_color(color)
  }
  let start = self.state.val.artists.length()
  let segments : Array[Array[@core.Point]] = []
  let segment_levels : Array[Double] = []
  for level_index, level in resolved_levels {
    let style = @core.style(
      contour_line_color(resolved_color, colors, level_index),
      width=contour_linewidth(linewidth, linewidths, level_index),
    )
    let raw_segments : Array[Array[@core.Point]] = []
    for index, triangle in mesh_triangles {
      if !triangle_is_visible(mesh_mask, index) {
        continue
      }
      let first = {
        point: @core.point(mesh_x[triangle[0]], mesh_y[triangle[0]]),
        value: values[triangle[0]],
      }
      let second = {
        point: @core.point(mesh_x[triangle[1]], mesh_y[triangle[1]]),
        value: values[triangle[1]],
      }
      let third = {
        point: @core.point(mesh_x[triangle[2]], mesh_y[triangle[2]]),
        value: values[triangle[2]],
      }
      for segment in contour_triangle_segments(first, second, third, level) {
        raw_segments.push(segment)
      }
    }
    for path in contour_stitch_segments(raw_segments) {
      self.push_contour_path(path, style, segments.length(), level, label)
      segments.push(path.copy())
      segment_levels.push(level)
    }
  }
  self.add_auto_legend(
    label,
    contour_line_color(resolved_color, colors, 0),
    LegendKind::Line,
    record_series=self.state.val.artists.length() > start,
  )
  self.add_container(ContainerKind::Contour, start, label)
  {
    levels: resolved_levels,
    filled: false,
    segments,
    segment_levels,
    extend_mode: "neither",
    corner_mask: true,
  }
}

///|
/// Draw contour lines from a validated triangulation.
pub fn Figure::tricontour_triangulation(
  self : Figure,
  mesh : Triangulation,
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  locator? : @ticker.Locator,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> ContourSet raise @core.DataError {
  self
  .axes()
  .tricontour_triangulation(
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
/// Draw contour lines from a validated triangulation.
pub fn Axes::tricontour_triangulation(
  self : Axes,
  mesh : Triangulation,
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  label~ : String = "",
  locator~ : @ticker.Locator? = None,
  colors~ : Array[String] = [],
  linewidths~ : Array[Double] = [],
) -> ContourSet raise @core.DataError {
  self.tricontour(
    mesh.x(),
    mesh.y(),
    mesh.triangles(),
    values,
    levels~,
    nlevels~,
    color~,
    linewidth~,
    label~,
    mask=mesh.mask(),
    locator~,
    colors~,
    linewidths~,
  )
}

///|
/// Draw filled contour bands over a validated triangular mesh.
pub fn Figure::tricontourf(
  self : Figure,
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
) -> ContourSet raise @core.DataError {
  self
  .axes()
  .tricontourf(
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
/// Draw filled contour bands over a validated triangular mesh.
pub fn Axes::tricontourf(
  self : Axes,
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
  locator~ : @ticker.Locator? = None,
) -> ContourSet raise @core.DataError {
  let mesh = triangulation(xs, ys, triangles~, mask~)
  let mesh_x = mesh.x()
  let mesh_y = mesh.y()
  let mesh_triangles = mesh.triangles()
  let mesh_mask = mesh.mask()
  if values.length() != mesh_x.length() {
    raise @core.DataError::LengthMismatch(
      expected=mesh_x.length(),
      actual=values.length(),
    )
  }
  validate_tri_contour_values(values)
  validate_contour_extend(extend_mode)
  let resolved_levels = contour_levels([values], levels, nlevels, true, locator)
  let bands = resolved_levels.length() - 1
  let (data_lower, data_upper) = contour_data_limits([values])
  let extension_count = (if contour_extend_min(extend_mode) { 1 } else { 0 }) +
    (if contour_extend_max(extend_mode) { 1 } else { 0 })
  let rendered_bands = bands + extension_count
  let start = self.state.val.artists.length()
  let mut color_index = 0
  let filled_segments : Array[Array[@core.Point]] = []
  let filled_segment_levels : Array[Double] = []
  if contour_extend_min(extend_mode) {
    let fill_color = contour_palette_color(
      color_index, rendered_bands, colors, cmap,
    )
    let paths = tricontour_render_filled_band(
      self,
      mesh_x,
      mesh_y,
      mesh_triangles,
      values,
      mesh_mask,
      data_lower,
      resolved_levels[0],
      @core.style(fill_color, width=0.0, fill=fill_color),
      color_index,
      label,
    )
    for path in paths {
      filled_segments.push(path.copy())
      filled_segment_levels.push((data_lower + resolved_levels[0]) / 2.0)
    }
    color_index += 1
  }
  for band in 0..<bands {
    let fill_color = contour_palette_color(
      color_index, rendered_bands, colors, cmap,
    )
    let style = @core.style(fill_color, width=0.0, fill=fill_color)
    let lower = resolved_levels[band]
    let upper = resolved_levels[band + 1]
    let polygons : Array[Array[@core.Point]] = []
    for index, triangle in mesh_triangles {
      if !triangle_is_visible(mesh_mask, index) {
        continue
      }
      let first = {
        point: @core.point(mesh_x[triangle[0]], mesh_y[triangle[0]]),
        value: values[triangle[0]],
      }
      let second = {
        point: @core.point(mesh_x[triangle[1]], mesh_y[triangle[1]]),
        value: values[triangle[1]],
      }
      let third = {
        point: @core.point(mesh_x[triangle[2]], mesh_y[triangle[2]]),
        value: values[triangle[2]],
      }
      let polygon = contour_clipped_triangle(first, second, third, lower, upper)
      if polygon.length() >= 3 {
        polygons.push(polygon)
      }
    }
    let merged = contour_union_polygons(polygons)
    self.push_contourf_band(merged, style, color_index, lower, upper, label)
    if merged.length() == 1 {
      filled_segments.push(merged[0].copy())
      filled_segment_levels.push((lower + upper) / 2.0)
    } else if merged.length() > 1 {
      for polygon in merged {
        filled_segments.push(polygon.copy())
        filled_segment_levels.push((lower + upper) / 2.0)
      }
    }
    color_index += 1
  }
  if contour_extend_max(extend_mode) {
    let fill_color = contour_palette_color(
      color_index, rendered_bands, colors, cmap,
    )
    let paths = tricontour_render_filled_band(
      self,
      mesh_x,
      mesh_y,
      mesh_triangles,
      values,
      mesh_mask,
      resolved_levels[resolved_levels.length() - 1],
      data_upper,
      @core.style(fill_color, width=0.0, fill=fill_color),
      color_index,
      label,
    )
    for path in paths {
      filled_segments.push(path.copy())
      filled_segment_levels.push(
        (resolved_levels[resolved_levels.length() - 1] + data_upper) / 2.0,
      )
    }
  }
  let legend_color = contour_palette_color(0, rendered_bands, colors, cmap)
  self.add_auto_legend(
    label,
    legend_color,
    LegendKind::Patch,
    record_series=self.state.val.artists.length() > start,
  )
  self.add_container(ContainerKind::Contour, start, label)
  {
    levels: resolved_levels,
    filled: true,
    segments: filled_segments,
    segment_levels: filled_segment_levels,
    extend_mode,
    corner_mask: true,
  }
}

///|
/// Draw filled contour bands from a validated triangulation.
pub fn Figure::tricontourf_triangulation(
  self : Figure,
  mesh : Triangulation,
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  locator? : @ticker.Locator,
) -> ContourSet raise @core.DataError {
  self
  .axes()
  .tricontourf_triangulation(
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

///|
/// Draw filled contour bands from a validated triangulation.
pub fn Axes::tricontourf_triangulation(
  self : Axes,
  mesh : Triangulation,
  values : Array[Double],
  levels~ : Array[Double] = [],
  nlevels~ : Int32 = 7,
  colors~ : Array[String] = [],
  cmap~ : String = "viridis",
  label~ : String = "",
  extend_mode~ : String = "neither",
  locator~ : @ticker.Locator? = None,
) -> ContourSet raise @core.DataError {
  self.tricontourf(
    mesh.x(),
    mesh.y(),
    mesh.triangles(),
    values,
    levels~,
    nlevels~,
    colors~,
    cmap~,
    label~,
    extend_mode~,
    mask=mesh.mask(),
    locator~,
  )
}
