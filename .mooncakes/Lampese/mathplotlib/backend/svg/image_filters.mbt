///|
/// Resolve the adaptive modes using Matplotlib's display-scale rule. The
/// filtered branch uses Hanning, which is the upstream default for `auto` and
/// `antialiased` when nearest-neighbor is not selected.
fn resolve_interpolation(
  interpolation : @render.ImageInterpolation,
  display_columns : Int32,
  display_rows : Int32,
  columns : Int32,
  rows : Int32,
) -> @render.ImageInterpolation {
  match interpolation {
    @render.ImageInterpolation::Auto
    | @render.ImageInterpolation::Antialiased =>
      if auto_uses_nearest(display_columns, display_rows, columns, rows) {
        @render.ImageInterpolation::Nearest
      } else {
        @render.ImageInterpolation::Hanning
      }
    _ => interpolation
  }
}

///|
/// Resample one display pixel with a separable, center-aligned filter. Alpha
/// and RGB are accumulated in premultiplied-alpha space, matching Matplotlib's
/// RGBA path and preventing transparent source colors from bleeding inward.
fn filtered_pixel(
  source : Array[Array[@colors.Rgba]],
  row : Int32,
  column : Int32,
  output_rows : Int32,
  output_columns : Int32,
  interpolation : @render.ImageInterpolation,
) -> @colors.Rgba {
  let source_rows = source.length()
  let source_columns = source[0].length()
  let source_x = (column.to_double() + 0.5) *
    source_columns.to_double() /
    output_columns.to_double() -
    0.5
  let source_y = (row.to_double() + 0.5) *
    source_rows.to_double() /
    output_rows.to_double() -
    0.5
  let scale_x = Double::min(
    1.0,
    output_columns.to_double() / source_columns.to_double(),
  )
  let scale_y = Double::min(
    1.0,
    output_rows.to_double() / source_rows.to_double(),
  )
  let radius = filter_radius(interpolation)
  let radius_x = radius / scale_x
  let radius_y = radius / scale_y
  let first_x = (source_x - radius_x).floor().to_int()
  let last_x = (source_x + radius_x).ceil().to_int()
  let first_y = (source_y - radius_y).floor().to_int()
  let last_y = (source_y + radius_y).ceil().to_int()
  let mut total_weight = 0.0
  let mut alpha = 0.0
  let mut red = 0.0
  let mut green = 0.0
  let mut blue = 0.0
  for y in first_y..<=last_y {
    let wy = filter_weight(
      interpolation,
      Double::abs(source_y - y.to_double()) * scale_y,
    )
    if wy != 0.0 {
      let sample_y = clamp_index(y, source_rows)
      for x in first_x..<=last_x {
        let wx = filter_weight(
          interpolation,
          Double::abs(source_x - x.to_double()) * scale_x,
        )
        let weight = wx * wy
        if weight != 0.0 {
          let sample_x = clamp_index(x, source_columns)
          let color = source[sample_y][sample_x]
          total_weight += weight
          alpha += weight * color.alpha()
          red += weight * color.red() * color.alpha()
          green += weight * color.green() * color.alpha()
          blue += weight * color.blue() * color.alpha()
        }
      }
    }
  }
  if Double::abs(total_weight) <= 1.0e-12 {
    let sample_x = clamp_index(source_x.round().to_int(), source_columns)
    let sample_y = clamp_index(source_y.round().to_int(), source_rows)
    source[sample_y][sample_x]
  } else {
    let output_alpha = alpha / total_weight
    if output_alpha <= 0.0 {
      try! @colors.rgba(0.0, 0.0, 0.0, alpha=0.0)
    } else {
      try! @colors.rgba(
        clamp_unit(red / total_weight / output_alpha),
        clamp_unit(green / total_weight / output_alpha),
        clamp_unit(blue / total_weight / output_alpha),
        alpha=clamp_unit(output_alpha),
      )
    }
  }
}

///|
fn clamp_index(value : Int32, length : Int32) -> Int32 {
  Int32::max(0, Int32::min(length - 1, value))
}

///|
fn clamp_unit(value : Double) -> Double {
  Double::max(0.0, Double::min(1.0, value))
}

///|
fn filter_radius(interpolation : @render.ImageInterpolation) -> Double {
  match interpolation {
    @render.ImageInterpolation::Bicubic
    | @render.ImageInterpolation::Catrom
    | @render.ImageInterpolation::Mitchell
    | @render.ImageInterpolation::Spline16 => 2.0
    @render.ImageInterpolation::Spline36 => 3.0
    @render.ImageInterpolation::Quadric => 1.5
    @render.ImageInterpolation::Gaussian => 2.0
    @render.ImageInterpolation::Bessel => 3.2383
    @render.ImageInterpolation::Sinc
    | @render.ImageInterpolation::Lanczos
    | @render.ImageInterpolation::Blackman => 4.0
    _ => 1.0
  }
}

///|
fn filter_weight(
  interpolation : @render.ImageInterpolation,
  distance : Double,
) -> Double {
  match interpolation {
    @render.ImageInterpolation::Bilinear =>
      if distance < 1.0 {
        1.0 - distance
      } else {
        0.0
      }
    @render.ImageInterpolation::Hanning =>
      if distance < 1.0 {
        0.5 + 0.5 * @math.cos(@math.PI * distance)
      } else {
        0.0
      }
    @render.ImageInterpolation::Hamming =>
      if distance < 1.0 {
        0.54 + 0.46 * @math.cos(@math.PI * distance)
      } else {
        0.0
      }
    @render.ImageInterpolation::Hermite =>
      if distance < 1.0 {
        (2.0 * distance - 3.0) * distance * distance + 1.0
      } else {
        0.0
      }
    @render.ImageInterpolation::Quadric =>
      if distance < 0.5 {
        0.75 - distance * distance
      } else if distance < 1.5 {
        let t = distance - 1.5
        0.5 * t * t
      } else {
        0.0
      }
    @render.ImageInterpolation::Bicubic =>
      if distance < 2.0 {
        let p0 = positive_cube(distance + 2.0)
        let p1 = positive_cube(distance + 1.0)
        let p2 = positive_cube(distance)
        let p3 = positive_cube(distance - 1.0)
        (p0 - 4.0 * p1 + 6.0 * p2 - 4.0 * p3) / 6.0
      } else {
        0.0
      }
    @render.ImageInterpolation::Catrom =>
      if distance < 1.0 {
        0.5 * (2.0 + distance * distance * (-5.0 + distance * 3.0))
      } else if distance < 2.0 {
        0.5 * (4.0 + distance * (-8.0 + distance * (5.0 - distance)))
      } else {
        0.0
      }
    @render.ImageInterpolation::Mitchell => {
      let p0 = (6.0 - 2.0 / 3.0) / 6.0
      let p2 = (-18.0 + 12.0 / 3.0 + 6.0 / 3.0) / 6.0
      let p3 = (12.0 - 9.0 / 3.0 - 6.0 / 3.0) / 6.0
      let q0 = (8.0 / 3.0 + 24.0 / 3.0) / 6.0
      let q1 = (-12.0 / 3.0 - 48.0 / 3.0) / 6.0
      let q2 = (6.0 / 3.0 + 30.0 / 3.0) / 6.0
      let q3 = (-1.0 / 3.0 - 6.0 / 3.0) / 6.0
      if distance < 1.0 {
        p0 + distance * distance * (p2 + distance * p3)
      } else if distance < 2.0 {
        q0 + distance * (q1 + distance * (q2 + distance * q3))
      } else {
        0.0
      }
    }
    @render.ImageInterpolation::Spline16 =>
      if distance < 1.0 {
        ((distance - 9.0 / 5.0) * distance - 1.0 / 5.0) * distance + 1.0
      } else if distance < 2.0 {
        let t = distance - 1.0
        ((-1.0 / 3.0 * t + 4.0 / 5.0) * t - 7.0 / 15.0) * t
      } else {
        0.0
      }
    @render.ImageInterpolation::Spline36 =>
      if distance < 1.0 {
        ((13.0 / 11.0 * distance - 453.0 / 209.0) * distance - 3.0 / 209.0) *
        distance +
        1.0
      } else if distance < 2.0 {
        let t = distance - 1.0
        ((-6.0 / 11.0 * t + 270.0 / 209.0) * t - 156.0 / 209.0) * t
      } else if distance < 3.0 {
        let t = distance - 2.0
        ((1.0 / 11.0 * t - 45.0 / 209.0) * t + 26.0 / 209.0) * t
      } else {
        0.0
      }
    @render.ImageInterpolation::Gaussian =>
      if distance < 2.0 {
        @math.exp(-2.0 * distance * distance) * (2.0 / @math.PI).sqrt()
      } else {
        0.0
      }
    @render.ImageInterpolation::Kaiser =>
      if distance < 1.0 {
        let beta = 6.33
        bessel_i0(beta * Double::max(0.0, 1.0 - distance * distance).sqrt()) /
        bessel_i0(beta)
      } else {
        0.0
      }
    @render.ImageInterpolation::Bessel =>
      if distance == 0.0 {
        @math.PI / 4.0
      } else if distance < 3.2383 {
        bessel_j1(@math.PI * distance) / (2.0 * distance)
      } else {
        0.0
      }
    @render.ImageInterpolation::Sinc => sinc_weight(distance, 4.0)
    @render.ImageInterpolation::Lanczos => lanczos_weight(distance, 4.0)
    @render.ImageInterpolation::Blackman => blackman_weight(distance, 4.0)
    _ => 0.0
  }
}

///|
fn positive_cube(value : Double) -> Double {
  if value <= 0.0 {
    0.0
  } else {
    value * value * value
  }
}

///|
fn sinc_weight(distance : Double, radius : Double) -> Double {
  if distance == 0.0 {
    1.0
  } else if distance < radius {
    let x = @math.PI * distance
    @math.sin(x) / x
  } else {
    0.0
  }
}

///|
fn lanczos_weight(distance : Double, radius : Double) -> Double {
  if distance == 0.0 {
    1.0
  } else if distance < radius {
    sinc_weight(distance, radius) * sinc_weight(distance / radius, 1.0)
  } else {
    0.0
  }
}

///|
fn blackman_weight(distance : Double, radius : Double) -> Double {
  if distance == 0.0 {
    1.0
  } else if distance < radius {
    let x = @math.PI * distance
    let xr = x / radius
    @math.sin(x) / x * (0.42 + 0.5 * @math.cos(xr) + 0.08 * @math.cos(2.0 * xr))
  } else {
    0.0
  }
}

///|
fn bessel_i0(value : Double) -> Double {
  let y = value * value / 4.0
  let mut term = 1.0
  let mut result = 1.0
  for index in 1..<=32 {
    let denominator = index.to_double() * index.to_double()
    term *= y / denominator
    result += term
    if term < 1.0e-14 {
      break
    }
  }
  result
}

///|
/// Numerical Recipes' rational approximation of the first-order Bessel J
/// function, sufficient for the bounded Bessel image filter radius.
fn bessel_j1(value : Double) -> Double {
  let absolute = Double::abs(value)
  if absolute < 8.0 {
    let y = value * value
    let numerator = value *
      (
        72362614232.0 +
        y *
        (
          -7895059235.0 +
          y *
          (
            242396853.1 +
            y * (-2972611.439 + y * (15704.48260 + y * -30.16036606))
          )
        )
      )
    let denominator = 144725228442.0 +
      y *
      (
        2300535178.0 +
        y * (18583304.74 + y * (99447.43394 + y * (376.9991397 + y)))
      )
    numerator / denominator
  } else {
    let z = 8.0 / absolute
    let y = z * z
    let xx = absolute - 2.356194491
    let numerator = 1.0 +
      y *
      (
        0.183105e-2 +
        y * (-0.3516396496e-4 + y * (0.2457520174e-5 + y * -0.240337019e-6))
      )
    let denominator = -0.04687499995 +
      y *
      (
        0.2002690873e-3 +
        y * (-0.8449199096e-5 + y * (0.88228987e-6 + y * -0.105787412e-6))
      )
    let result = (0.636619772 / absolute).sqrt() *
      (@math.cos(xx) * numerator - z * @math.sin(xx) * denominator)
    if value < 0.0 {
      -result
    } else {
      result
    }
  }
}
