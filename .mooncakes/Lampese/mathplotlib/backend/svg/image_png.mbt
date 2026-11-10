///|
fn uses_raster_png(
  scale : Scale,
  interpolation : @render.ImageInterpolation,
) -> Bool {
  match interpolation {
    @render.ImageInterpolation::Nearest => false
    _ =>
      !scale.x_axis_scale.is_nonlinear() && !scale.y_axis_scale.is_nonlinear()
  }
}

///|
// The source buffer is always collected in row-major order. `none` and the
// nearest branch copy those source pixels directly; filtered branches first
// resample them into a display-sized buffer. The SVG transform handles both
// origins, reversed extents, and reversed axes without rewriting either PNG.
// A nested SVG viewport clips the image in display coordinates, independently
// of that transform, and needs no document-global clip identifier.
fn append_png_image(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  rows : Int32,
  columns : Int32,
  origin : @render.ImageOrigin,
  extent : (Double, Double, Double, Double)?,
  alpha : Double,
  interpolation : @render.ImageInterpolation,
  pixel : (Int32, Int32) -> @colors.Rgba,
) -> Unit {
  let (left_bound, right_bound, bottom_bound, top_bound) = image_extent(
    rows, columns, origin, extent,
  )
  let (first_y, last_y) = match origin {
    @render.ImageOrigin::Upper => (top_bound, bottom_bound)
    @render.ImageOrigin::Lower => (bottom_bound, top_bound)
  }
  let x0 = map_x(scale, left, plot_width, left_bound)
  let x1 = map_x(scale, left, plot_width, right_bound)
  let y0 = map_y(scale, top, plot_height, first_y)
  let y1 = map_y(scale, top, plot_height, last_y)
  if Double::max(x0, x1) <= left ||
    Double::min(x0, x1) >= left + plot_width ||
    Double::max(y0, y1) <= top ||
    Double::min(y0, y1) >= top + plot_height {
    return
  }
  let source = Array(capacity=rows)
  for row in 0..<rows {
    let source_row = Array(capacity=columns)
    for column in 0..<columns {
      source_row.push(pixel(row, column))
    }
    source.push(source_row)
  }
  let display_columns = raster_dimension(Double::abs(x1 - x0))
  let display_rows = raster_dimension(Double::abs(y1 - y0))
  let resolved_interpolation = resolve_interpolation(
    interpolation, display_columns, display_rows, columns, rows,
  )
  let use_filter = match resolved_interpolation {
    @render.ImageInterpolation::Nearest
    | @render.ImageInterpolation::NoInterpolation => false
    _ => true
  }
  let output_columns = if use_filter { display_columns } else { columns }
  let output_rows = if use_filter { display_rows } else { rows }
  let pixels = @buffer.Buffer()
  for row in 0..<output_rows {
    for column in 0..<output_columns {
      let color = if use_filter {
        filtered_pixel(
          source, row, column, output_rows, output_columns, resolved_interpolation,
        )
      } else {
        source[row][column]
      }
      // Matplotlib's bytes=True conversion truncates normalized channels.
      pixels.write_byte((color.red() * 255.0).to_int().to_byte())
      pixels.write_byte((color.green() * 255.0).to_int().to_byte())
      pixels.write_byte((color.blue() * 255.0).to_int().to_byte())
      pixels.write_byte((color.alpha() * 255.0).to_int().to_byte())
    }
  }
  let uri = try! @png.rgba_data_uri(
    output_columns,
    output_rows,
    pixels.to_bytes(),
  )
  let sx = (x1 - x0) / output_columns.to_double()
  let sy = (y1 - y0) / output_rows.to_double()
  let style = match resolved_interpolation {
    @render.ImageInterpolation::NoInterpolation
    | @render.ImageInterpolation::Nearest =>
      "image-rendering:crisp-edges;image-rendering:pixelated"
    _ => "image-rendering:auto"
  }
  try! writer.start_element("svg", [
    ("x", float_text(left)),
    ("y", float_text(top)),
    ("width", float_text(plot_width)),
    ("height", float_text(plot_height)),
    ("overflow", "hidden"),
    ("xmlns:xlink", "http://www.w3.org/1999/xlink"),
  ])
  try! writer.empty_element("image", [
    ("width", output_columns.to_string()),
    ("height", output_rows.to_string()),
    (
      "transform",
      "matrix(\{float_text(sx)} 0 0 \{float_text(sy)} \{float_text(x0 - left)} \{float_text(y0 - top)})",
    ),
    ("preserveAspectRatio", "none"),
    ("style", style),
    ("opacity", float_text(alpha)),
    ("xlink:href", uri),
  ])
  try! writer.end_element("svg")
}

///|
/// Keep generated SVG images bounded when an extent covers a very large
/// display region. The affine transform still maps the result to the exact
/// data extent, while the cap avoids unbounded allocations from user input.
fn raster_dimension(display_extent : Double) -> Int32 {
  Int32::max(1, Int32::min(4096, display_extent.ceil().to_int()))
}

///|
/// Matplotlib's `auto` mode uses nearest for large/integer upscales and
/// Hanning for the remaining cases. The resolver in `image_filters.mbt`
/// applies that choice before the separable filtered sampler runs.
fn auto_uses_nearest(
  display_columns : Int32,
  display_rows : Int32,
  columns : Int32,
  rows : Int32,
) -> Bool {
  let x = display_columns.to_double() / columns.to_double()
  let y = display_rows.to_double() / rows.to_double()
  (x > 3.0 || x == 1.0 || x == 2.0) && (y > 3.0 || y == 1.0 || y == 2.0)
}
