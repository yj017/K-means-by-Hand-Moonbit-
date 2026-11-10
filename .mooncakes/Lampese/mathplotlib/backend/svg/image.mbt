///|
fn image_extent(
  rows : Int32,
  columns : Int32,
  origin : @render.ImageOrigin,
  extent : (Double, Double, Double, Double)?,
) -> (Double, Double, Double, Double) {
  match extent {
    Some(bounds) => bounds
    None => {
      let right = Double::from_int(columns) - 0.5
      let last_row = Double::from_int(rows) - 0.5
      match origin {
        @render.ImageOrigin::Upper => (-0.5, right, last_row, -0.5)
        @render.ImageOrigin::Lower => (-0.5, right, -0.5, last_row)
      }
    }
  }
}

///|
fn artist_image_extent(
  artist : @render.Artist,
) -> (Double, Double, Double, Double)? {
  match artist {
    @render.Artist::Image(data, _, _, _) =>
      if data.is_empty() || data[0].is_empty() {
        None
      } else {
        Some(
          image_extent(
            data.length(),
            data[0].length(),
            @render.ImageOrigin::Upper,
            None,
          ),
        )
      }
    @render.Artist::ImageNorm(data, _, _, origin, extent, _, _) =>
      if data.is_empty() || data[0].is_empty() {
        None
      } else {
        Some(image_extent(data.length(), data[0].length(), origin, extent))
      }
    @render.Artist::ColorImage(data, origin, extent, _, _) =>
      if data.is_empty() || data[0].is_empty() {
        None
      } else {
        Some(image_extent(data.length(), data[0].length(), origin, extent))
      }
    _ => None
  }
}

///|
fn flatten_image(data : Array[Array[Double]]) -> Array[Double] {
  let values = Array(capacity=data.length())
  for row in data {
    for value in row {
      values.push(value)
    }
  }
  values
}

///|
fn append_image(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin : @render.ImageOrigin,
  extent : (Double, Double, Double, Double)?,
  alpha : Double,
  interpolation : @render.ImageInterpolation,
  on_cell~ : ((RenderedCell) -> Unit)? = None,
) -> Unit {
  if data.length() == 0 || data[0].length() == 0 {
    return
  }
  let rows = data.length()
  let columns = data[0].length()
  norm.autoscale_none(flatten_image(data))
  if uses_raster_png(scale, interpolation) {
    append_png_image(
      writer,
      scale,
      left,
      top,
      plot_width,
      plot_height,
      rows,
      columns,
      origin,
      extent,
      alpha,
      interpolation,
      (row, column) => scalar_image_pixel(data[row][column], norm, cmap),
    )
    return
  }
  let (left_bound, right_bound, bottom_bound, top_bound) = image_extent(
    rows, columns, origin, extent,
  )
  let cell_width = (right_bound - left_bound) / Double::from_int(columns)
  let cell_height = (top_bound - bottom_bound) / Double::from_int(rows)
  for row in 0..<rows {
    for column in 0..<columns {
      let value = data[row][column]
      if norm.is_valid(value) || cmap.bad() is Some(_) {
        let column_value = Double::from_int(column)
        let row_value = Double::from_int(row)
        let x_start = left_bound + column_value * cell_width
        let x_end = x_start + cell_width
        let (y_start, y_end) = match origin {
          @render.ImageOrigin::Upper =>
            (
              top_bound - row_value * cell_height,
              top_bound - (row_value + 1.0) * cell_height,
            )
          @render.ImageOrigin::Lower =>
            (
              bottom_bound + row_value * cell_height,
              bottom_bound + (row_value + 1.0) * cell_height,
            )
        }
        if scale.x_axis_scale.is_valid(x_start) &&
          scale.x_axis_scale.is_valid(x_end) &&
          scale.y_axis_scale.is_valid(y_start) &&
          scale.y_axis_scale.is_valid(y_end) {
          let x1 = map_x(scale, left, plot_width, x_start)
          let x2 = map_x(scale, left, plot_width, x_end)
          let y1 = map_y(scale, top, plot_height, y_start)
          let y2 = map_y(scale, top, plot_height, y_end)
          let pixel = scalar_image_pixel(value, norm, cmap)
          try! writer.empty_element("rect", [
            ("x", float_text(Double::min(x1, x2))),
            ("y", float_text(Double::min(y1, y2))),
            ("width", float_text(Double::abs(x2 - x1))),
            ("height", float_text(Double::abs(y2 - y1))),
            ("fill", try! pixel.scale_alpha(alpha).to_css()),
          ])
          if interpolation is @render.ImageInterpolation::Nearest &&
            alpha > 0.0 &&
            pixel.alpha() > 0.0 &&
            norm.is_valid(value) &&
            !value.is_nan() &&
            !value.is_inf() &&
            on_cell is Some(collect) {
            collect({
              row,
              column,
              columns,
              value,
              x_range: (x_start, x_end),
              y_range: (y_start, y_end),
              rectangle: (
                Double::min(x1, x2),
                Double::min(y1, y2),
                Double::abs(x2 - x1),
                Double::abs(y2 - y1),
              ),
            })
          }
        }
      }
    }
  }
}

///|
/// Append an already-colored RGB/RGBA image. The pixel geometry deliberately
/// mirrors `append_image`; only scalar normalization and colormap sampling are
/// bypassed.
fn append_color_image(
  writer : @xml.Writer,
  scale : Scale,
  left : Double,
  top : Double,
  plot_width : Double,
  plot_height : Double,
  data : Array[Array[@colors.Rgba]],
  origin : @render.ImageOrigin,
  extent : (Double, Double, Double, Double)?,
  alpha : Double,
  interpolation : @render.ImageInterpolation,
) -> Unit {
  if data.length() == 0 || data[0].length() == 0 {
    return
  }
  let rows = data.length()
  let columns = data[0].length()
  if uses_raster_png(scale, interpolation) {
    append_png_image(
      writer,
      scale,
      left,
      top,
      plot_width,
      plot_height,
      rows,
      columns,
      origin,
      extent,
      alpha,
      interpolation,
      (row, column) => data[row][column],
    )
    return
  }
  let (left_bound, right_bound, bottom_bound, top_bound) = image_extent(
    rows, columns, origin, extent,
  )
  let cell_width = (right_bound - left_bound) / Double::from_int(columns)
  let cell_height = (top_bound - bottom_bound) / Double::from_int(rows)
  for row in 0..<rows {
    for column in 0..<columns {
      let column_value = Double::from_int(column)
      let row_value = Double::from_int(row)
      let x_start = left_bound + column_value * cell_width
      let x_end = x_start + cell_width
      let (y_start, y_end) = match origin {
        @render.ImageOrigin::Upper =>
          (
            top_bound - row_value * cell_height,
            top_bound - (row_value + 1.0) * cell_height,
          )
        @render.ImageOrigin::Lower =>
          (
            bottom_bound + row_value * cell_height,
            bottom_bound + (row_value + 1.0) * cell_height,
          )
      }
      if scale.x_axis_scale.is_valid(x_start) &&
        scale.x_axis_scale.is_valid(x_end) &&
        scale.y_axis_scale.is_valid(y_start) &&
        scale.y_axis_scale.is_valid(y_end) {
        let x1 = map_x(scale, left, plot_width, x_start)
        let x2 = map_x(scale, left, plot_width, x_end)
        let y1 = map_y(scale, top, plot_height, y_start)
        let y2 = map_y(scale, top, plot_height, y_end)
        try! writer.empty_element("rect", [
          ("x", float_text(Double::min(x1, x2))),
          ("y", float_text(Double::min(y1, y2))),
          ("width", float_text(Double::abs(x2 - x1))),
          ("height", float_text(Double::abs(y2 - y1))),
          ("fill", try! data[row][column].scale_alpha(alpha).to_css()),
        ])
      }
    }
  }
}

///|
fn scalar_image_pixel(
  value : Double,
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
) -> @colors.Rgba {
  if norm.is_valid(value) {
    cmap.sample_extended(try! norm.transform(value))
  } else {
    cmap.sample_extended(0.0 / 0.0)
  }
}
