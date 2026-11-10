///|
priv struct Scale {
  xmin : Double
  xmax : Double
  ymin : Double
  ymax : Double
  x_axis_scale : @ticker_scale.Scale
  y_axis_scale : @ticker_scale.Scale
}

///|
fn map_x(
  scale : Scale,
  left : Double,
  plot_width : Double,
  value : Double,
) -> Double {
  let transformed_min = scale.x_axis_scale.transform(scale.xmin)
  let transformed_max = scale.x_axis_scale.transform(scale.xmax)
  let transformed_value = scale.x_axis_scale.transform(value)
  let span = transformed_max - transformed_min
  if span == 0.0 {
    left + plot_width / 2.0
  } else {
    left + (transformed_value - transformed_min) / span * plot_width
  }
}

///|
fn map_y(
  scale : Scale,
  top : Double,
  plot_height : Double,
  value : Double,
) -> Double {
  let transformed_min = scale.y_axis_scale.transform(scale.ymin)
  let transformed_max = scale.y_axis_scale.transform(scale.ymax)
  let transformed_value = scale.y_axis_scale.transform(value)
  let span = transformed_max - transformed_min
  if span == 0.0 {
    top + plot_height / 2.0
  } else {
    top + (transformed_max - transformed_value) / span * plot_height
  }
}
