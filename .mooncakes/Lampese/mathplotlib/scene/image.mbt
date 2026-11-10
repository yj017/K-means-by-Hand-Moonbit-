///|
/// The vertical orientation used when mapping matrix rows to data space.
pub(all) enum ImageOrigin {
  Upper
  Lower
}

///|
/// The sampling policy used when an image is mapped to the SVG display area.
///
/// `Nearest` draws source cells as vector rectangles. `NoInterpolation` embeds
/// source pixels in a PNG on linear axes; nonlinear axes use the same cell
/// geometry as `Nearest`. The remaining modes use a display-sized PNG on
/// linear axes and fall back to source-cell geometry on nonlinear axes.
pub(all) enum ImageInterpolation {
  Nearest
  NoInterpolation
  Bilinear
  Bicubic
  Spline16
  Spline36
  Hanning
  Hamming
  Hermite
  Kaiser
  Quadric
  Catrom
  Gaussian
  Bessel
  Mitchell
  Sinc
  Lanczos
  Blackman
  Auto
  Antialiased
}

///|
fn parse_image_origin(value : String) -> ImageOrigin raise @core.DataError {
  match value {
    "upper" => ImageOrigin::Upper
    "lower" => ImageOrigin::Lower
    _ =>
      raise @core.DataError::InvalidImage(
        message="image origin must be 'upper' or 'lower'",
      )
  }
}

///|
fn parse_image_interpolation(
  value : String,
) -> ImageInterpolation raise @core.DataError {
  match value.to_lower() {
    "nearest" => ImageInterpolation::Nearest
    "none" => ImageInterpolation::NoInterpolation
    "bilinear" => ImageInterpolation::Bilinear
    "bicubic" => ImageInterpolation::Bicubic
    "spline16" => ImageInterpolation::Spline16
    "spline36" => ImageInterpolation::Spline36
    "hanning" => ImageInterpolation::Hanning
    "hamming" => ImageInterpolation::Hamming
    "hermite" => ImageInterpolation::Hermite
    "kaiser" => ImageInterpolation::Kaiser
    "quadric" => ImageInterpolation::Quadric
    "catrom" => ImageInterpolation::Catrom
    "gaussian" => ImageInterpolation::Gaussian
    "bessel" => ImageInterpolation::Bessel
    "mitchell" => ImageInterpolation::Mitchell
    "sinc" => ImageInterpolation::Sinc
    "lanczos" => ImageInterpolation::Lanczos
    "blackman" => ImageInterpolation::Blackman
    "auto" => ImageInterpolation::Auto
    "antialiased" => ImageInterpolation::Antialiased
    _ =>
      raise @core.DataError::InvalidImage(
        message="image interpolation supports 'nearest', 'none', 'bilinear', 'bicubic', 'spline16', 'spline36', 'hanning', 'hamming', 'hermite', 'kaiser', 'quadric', 'catrom', 'gaussian', 'bessel', 'mitchell', 'sinc', 'lanczos', 'blackman', 'auto', and 'antialiased'",
      )
  }
}

///|
fn parse_image_extent(
  values : Array[Double],
) -> (Double, Double, Double, Double)? raise @core.DataError {
  if values.length() == 0 {
    return None
  }
  if values.length() != 4 {
    raise @core.DataError::InvalidImage(
      message="image extent must contain four values",
    )
  }
  let left = values[0]
  let right = values[1]
  let bottom = values[2]
  let top = values[3]
  if left.is_nan() ||
    left.is_inf() ||
    right.is_nan() ||
    right.is_inf() ||
    bottom.is_nan() ||
    bottom.is_inf() ||
    top.is_nan() ||
    top.is_inf() {
    raise @core.DataError::InvalidImage(message="image extent must be finite")
  }
  if left == right || bottom == top {
    raise @core.DataError::InvalidImage(
      message="image extent bounds must be distinct",
    )
  }
  Some((left, right, bottom, top))
}

///|
fn Axes::apply_image_aspect(
  self : Axes,
  value : String,
) -> Unit raise @core.DataError {
  match value {
    "equal" => self.set_aspect_equal()
    "auto" => self.set_aspect_auto()
    _ =>
      raise @core.DataError::InvalidImage(
        message="image aspect must be 'equal' or 'auto'",
      )
  }
}

///|
/// Validate the global opacity applied to an image artist.
fn validate_image_alpha(alpha : Double) -> Unit raise @core.DataError {
  if alpha.is_nan() || alpha.is_inf() || alpha < 0.0 || alpha > 1.0 {
    raise @core.DataError::InvalidImage(
      message="image alpha must be finite and between 0 and 1",
    )
  }
}

///|
fn copy_image_data(data : Array[Array[Double]]) -> Array[Array[Double]] {
  let result = Array(capacity=data.length())
  for row in data {
    result.push(row.copy())
  }
  result
}

///|
fn validate_image_data(
  data : Array[Array[Double]],
  vmin : Double?,
  vmax : Double?,
) -> Unit raise @core.DataError {
  if data.length() == 0 || data[0].length() == 0 {
    raise @core.DataError::InvalidImage(
      message="image must have at least one cell",
    )
  }
  let columns = data[0].length()
  for row in data {
    if row.length() != columns {
      raise @core.DataError::InvalidImage(
        message="image rows must have equal length",
      )
    }
  }
  match vmin {
    Some(value) =>
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidImage(message="vmin must be finite")
      }
    None => ()
  }
  match vmax {
    Some(value) =>
      if value.is_nan() || value.is_inf() {
        raise @core.DataError::InvalidImage(message="vmax must be finite")
      }
    None => ()
  }
}

///|
fn resolve_colormap(name : String) -> @colors.ColorMap raise @core.DataError {
  match @colors.find_colormap(name) {
    Some(value) => value
    None =>
      raise @core.DataError::InvalidImage(message="unknown colormap: \{name}")
  }
}

///|
fn linear_color_norm(
  vmin : Double?,
  vmax : Double?,
) -> @colors.ColorNorm raise @core.DataError {
  try {
    let norm = match (vmin, vmax) {
      (Some(lower), Some(upper)) => @colors.normalize(vmin=lower, vmax=upper)
      (Some(lower), None) => @colors.normalize(vmin=lower)
      (None, Some(upper)) => @colors.normalize(vmax=upper)
      (None, None) => @colors.normalize()
    }
    @colors.linear_color_norm(norm)
  } catch {
    @colors.NormalizeError::InvalidBounds(message~)
    | @colors.NormalizeError::InvalidBase(message~)
    | @colors.NormalizeError::InvalidValue(message~) =>
      raise @core.DataError::InvalidImage(message~)
    @colors.NormalizeError::NoFiniteData
    | @colors.NormalizeError::NotScaled
    | @colors.NormalizeError::NotInvertible =>
      raise @core.DataError::InvalidImage(message="invalid image normalization")
  }
}

///|
fn Axes::add_image(
  self : Axes,
  data : Array[Array[Double]],
  vmin : Double?,
  vmax : Double?,
  cmap : @colors.ColorMap,
  origin~ : String,
  extent~ : Array[Double],
  aspect~ : String,
  alpha~ : Double,
  interpolation~ : String,
) -> Unit raise @core.DataError {
  validate_image_data(data, vmin, vmax)
  validate_image_alpha(alpha)
  let image_origin = parse_image_origin(origin)
  let image_interpolation = parse_image_interpolation(interpolation)
  let image_extent = parse_image_extent(extent)
  let norm = linear_color_norm(vmin, vmax)
  self.apply_image_aspect(aspect)
  self.attach_image_checked(
    Artist::ImageNorm(
      copy_image_data(data),
      norm,
      cmap,
      image_origin,
      image_extent,
      alpha,
      image_interpolation,
    ),
    data.length(),
    data[0].length(),
    image_origin,
    image_extent,
  )
}

///|
fn Axes::add_image_norm(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String,
  extent~ : Array[Double],
  aspect~ : String,
  alpha~ : Double,
  interpolation~ : String,
) -> Unit raise @core.DataError {
  validate_image_data(data, norm.vmin(), norm.vmax())
  validate_image_alpha(alpha)
  let image_origin = parse_image_origin(origin)
  let image_interpolation = parse_image_interpolation(interpolation)
  let image_extent = parse_image_extent(extent)
  self.apply_image_aspect(aspect)
  self.attach_image_checked(
    Artist::ImageNorm(
      copy_image_data(data),
      norm,
      cmap,
      image_origin,
      image_extent,
      alpha,
      image_interpolation,
    ),
    data.length(),
    data[0].length(),
    image_origin,
    image_extent,
  )
}

///|
/// Add a two-dimensional scalar image. Non-finite cells use the colormap's
/// bad color (transparent by default). `interpolation` accepts the Matplotlib
/// filter names `"nearest"` (the default), `"none"`, `"bilinear"`,
/// `"bicubic"`, `"spline16"`, `"spline36"`, `"hanning"`, `"hamming"`,
/// `"hermite"`, `"kaiser"`, `"quadric"`, `"catrom"`, `"gaussian"`,
/// `"bessel"`, `"mitchell"`, `"sinc"`, `"lanczos"`, `"blackman"`,
/// `"auto"`, and `"antialiased"`, ignoring case. On linear axes, `"none"`
/// embeds original-resolution pixels, while the filtered modes rasterize to
/// the display size before embedding the PNG. `"auto"` and `"antialiased"`
/// choose nearest for integer or large upscales and Hanning otherwise.
///
/// ```mbt check
/// test {
///   let fig = @scene.figure()
///   fig.imshow([[0.0, 1.0]], interpolation="none")
///   assert_true(fig.to_svg().contains("data:image/png;base64,"))
/// }
/// ```
pub fn Figure::imshow(
  self : Figure,
  data : Array[Array[Double]],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image(
    data,
    vmin,
    vmax,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image using a custom or builtin colormap object.
pub fn Figure::imshow_with_colormap(
  self : Figure,
  data : Array[Array[Double]],
  cmap : @colors.ColorMap,
  vmin? : Double,
  vmax? : Double,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image(
    data,
    vmin,
    vmax,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image with an explicit linear or logarithmic normalization.
pub fn Figure::imshow_with_norm(
  self : Figure,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image_norm(
    data,
    norm,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image with explicit normalization and colormap objects.
pub fn Figure::imshow_with_norm_and_colormap(
  self : Figure,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self
  .axes()
  .add_image_norm(
    data,
    norm,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image through the axes view.
pub fn Axes::imshow(
  self : Axes,
  data : Array[Array[Double]],
  vmin? : Double,
  vmax? : Double,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image(
    data,
    vmin,
    vmax,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image through the axes view using a colormap object.
pub fn Axes::imshow_with_colormap(
  self : Axes,
  data : Array[Array[Double]],
  cmap : @colors.ColorMap,
  vmin? : Double,
  vmax? : Double,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image(
    data,
    vmin,
    vmax,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image through the axes view with an explicit normalization.
pub fn Axes::imshow_with_norm(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap~ : String = "gray",
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image_norm(
    data,
    norm,
    resolve_colormap(cmap),
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}

///|
/// Add a scalar image through the axes view with explicit normalization and
/// colormap objects.
pub fn Axes::imshow_with_norm_and_colormap(
  self : Axes,
  data : Array[Array[Double]],
  norm : @colors.ColorNorm,
  cmap : @colors.ColorMap,
  origin~ : String = "upper",
  extent~ : Array[Double] = [],
  aspect~ : String = "equal",
  alpha~ : Double = 1.0,
  interpolation~ : String = "nearest",
) -> Unit raise @core.DataError {
  self.add_image_norm(
    data,
    norm,
    cmap,
    origin~,
    extent~,
    aspect~,
    alpha~,
    interpolation~,
  )
}
