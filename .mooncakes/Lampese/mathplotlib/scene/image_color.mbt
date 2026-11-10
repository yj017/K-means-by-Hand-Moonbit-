///|
/// Copy and validate a matrix of already validated RGBA pixels.
fn copy_color_image(
  data : Array[Array[@colors.Rgba]],
) -> Array[Array[@colors.Rgba]] raise @core.DataError {
  if data.length() == 0 || data[0].length() == 0 {
    raise @core.DataError::InvalidImage(
      message="color image must have at least one cell",
    )
  }
  let columns = data[0].length()
  let result = Array(capacity=data.length())
  for row in data {
    if row.length() != columns {
      raise @core.DataError::InvalidImage(
        message="color image rows must have equal length",
      )
    }
    result.push(row.copy())
  }
  result
}

///|
/// Convert a raw pixel channel vector to an RGBA value. NaN and infinite
/// channels follow Matplotlib's invalid-pixel rule and produce a fully
/// transparent pixel; finite channels are clipped to [0, 1].
fn color_pixel_from_channels(
  channels : Array[Double],
  expected : Int32,
) -> @colors.Rgba raise @core.DataError {
  if channels.length() != expected {
    raise @core.DataError::InvalidImage(
      message="color image pixels must have \{expected} channels",
    )
  }
  let mut has_nan = false
  for value in channels {
    if value.is_nan() {
      has_nan = true
    } else if value.is_inf() {
      has_nan = true
    }
  }
  if has_nan {
    try! @colors.rgba(0.0, 0.0, 0.0, alpha=0.0)
  } else if expected == 3 {
    try! @colors.rgba(
      clip_color_channel(channels[0]),
      clip_color_channel(channels[1]),
      clip_color_channel(channels[2]),
    )
  } else {
    try! @colors.rgba(
      clip_color_channel(channels[0]),
      clip_color_channel(channels[1]),
      clip_color_channel(channels[2]),
      alpha=clip_color_channel(channels[3]),
    )
  }
}

///|
fn clip_color_channel(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn color_image_from_channels(
  data : Array[Array[Array[Double]]],
  expected : Int32,
) -> Array[Array[@colors.Rgba]] raise @core.DataError {
  if data.length() == 0 || data[0].length() == 0 {
    raise @core.DataError::InvalidImage(
      message="color image must have at least one cell",
    )
  }
  let columns = data[0].length()
  let result = Array(capacity=data.length())
  for row in data {
    if row.length() != columns {
      raise @core.DataError::InvalidImage(
        message="color image rows must have equal length",
      )
    }
    let pixels = Array(capacity=columns)
    for channels in row {
      pixels.push(color_pixel_from_channels(channels, expected))
    }
    result.push(pixels)
  }
  result
}

///|
fn color_image_from_rgb(
  data : Array[Array[@colors.Rgb]],
) -> Array[Array[@colors.Rgba]] raise @core.DataError {
  if data.length() == 0 || data[0].length() == 0 {
    raise @core.DataError::InvalidImage(
      message="color image must have at least one cell",
    )
  }
  let columns = data[0].length()
  let result = Array(capacity=data.length())
  for row in data {
    if row.length() != columns {
      raise @core.DataError::InvalidImage(
        message="color image rows must have equal length",
      )
    }
    let pixels = Array(capacity=columns)
    for pixel in row {
      pixels.push(pixel.to_rgba())
    }
    result.push(pixels)
  }
  result
}

///|
fn Axes::add_color_image(
  self : Axes,
  data : Array[Array[@colors.Rgba]],
  origin~ : String,
  extent~ : Array[Double],
  aspect~ : String,
  alpha~ : Double,
  interpolation~ : String,
) -> Unit raise @core.DataError {
  let pixels = copy_color_image(data)
  validate_image_alpha(alpha)
  let image_origin = parse_image_origin(origin)
  let image_interpolation = parse_image_interpolation(interpolation)
  let image_extent = parse_image_extent(extent)
  self.apply_image_aspect(aspect)
  self.attach_image_checked(
    Artist::ColorImage(
      pixels, image_origin, image_extent, alpha, image_interpolation,
    ),
    pixels.length(),
    pixels[0].length(),
    image_origin,
    image_extent,
  )
}

///|
/// Add a prevalidated RGBA image. Pixels are placed with the same extent,
/// origin, aspect, and shared-axis behavior as scalar `imshow`.
pub fn Figure::imshow_rgba(
  self : Figure,
  data : Array[Array[@colors.Rgba]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_color_image(data, origin~, extent~, aspect~, alpha~, interpolation~)
}

///|
/// Add an opaque RGB image. Alpha is filled with one before it enters the
/// backend-neutral scene model.
pub fn Figure::imshow_rgb(
  self : Figure,
  data : Array[Array[@colors.Rgb]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(
    color_image_from_rgb(data),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add an RGBA image from raw normalized four-channel pixels.
pub fn Figure::imshow_rgba_channels(
  self : Figure,
  data : Array[Array[Array[Double]]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(
    color_image_from_channels(data, 4),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add an RGB image from raw normalized three-channel pixels.
pub fn Figure::imshow_rgb_channels(
  self : Figure,
  data : Array[Array[Array[Double]]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(
    color_image_from_channels(data, 3),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Alias for the typed RGBA entry point.
pub fn Figure::imshow_color(
  self : Figure,
  data : Array[Array[@colors.Rgba]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(data, origin~, extent~, aspect~, alpha~, interpolation~)
}

///|
/// Add a prevalidated RGBA image through an axes handle.
pub fn Axes::imshow_rgba(
  self : Axes,
  data : Array[Array[@colors.Rgba]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_color_image(data, origin~, extent~, aspect~, alpha~, interpolation~)
}

///|
/// Add an opaque RGB image through an axes handle.
pub fn Axes::imshow_rgb(
  self : Axes,
  data : Array[Array[@colors.Rgb]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(
    color_image_from_rgb(data),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add an RGBA image from raw normalized four-channel pixels through axes.
pub fn Axes::imshow_rgba_channels(
  self : Axes,
  data : Array[Array[Array[Double]]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(
    color_image_from_channels(data, 4),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add an RGB image from raw normalized three-channel pixels through axes.
pub fn Axes::imshow_rgb_channels(
  self : Axes,
  data : Array[Array[Array[Double]]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(
    color_image_from_channels(data, 3),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Alias for the typed RGBA axes entry point.
pub fn Axes::imshow_color(
  self : Axes,
  data : Array[Array[@colors.Rgba]],
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.imshow_rgba(data, origin~, extent~, aspect~, alpha~, interpolation~)
}
