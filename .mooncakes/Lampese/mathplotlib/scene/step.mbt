///|
fn invalid_step(message : String) -> @core.DataError {
  @core.DataError::InvalidReference(message~)
}

///|
fn step_points(
  xs : Array[Double],
  ys : Array[Double],
  mode : String,
) -> Array[@core.Point] raise @core.DataError {
  if mode != "pre" && mode != "post" && mode != "mid" {
    raise invalid_step("step where must be pre, post, or mid")
  }
  let values = @core.series(xs, ys)
  let count = values.length()
  let points = Array(capacity=count * 2)
  if count == 0 {
    return points
  }
  if mode == "pre" {
    points.push(@core.point(xs[0], ys[0]))
    for index in 1..<count {
      points.push(@core.point(xs[index - 1], ys[index]))
      points.push(@core.point(xs[index], ys[index]))
    }
  } else if mode == "post" {
    points.push(@core.point(xs[0], ys[0]))
    for index in 1..<count {
      points.push(@core.point(xs[index], ys[index - 1]))
      points.push(@core.point(xs[index], ys[index]))
    }
  } else {
    points.push(@core.point(xs[0], ys[0]))
    for index in 1..<count {
      let middle = (xs[index - 1] + xs[index]) / 2.0
      points.push(@core.point(middle, ys[index - 1]))
      points.push(@core.point(middle, ys[index]))
      if index + 1 == count {
        points.push(@core.point(xs[index], ys[index]))
      }
    }
  }
  points
}

///|
fn stairs_edges(values : Array[Double], edges : Array[Double]) -> Array[Double] {
  if edges.length() != 0 {
    edges.copy()
  } else {
    let result = Array(capacity=values.length() + 1)
    for index in 0..<=values.length() {
      result.push(Double::from_int(index))
    }
    result
  }
}

///|
fn validate_stairs(
  values : Array[Double],
  edges : Array[Double],
  orientation : String,
) -> Unit raise @core.DataError {
  if orientation != "vertical" && orientation != "horizontal" {
    raise invalid_step("stairs orientation must be vertical or horizontal")
  }
  if edges.length() != 0 && edges.length() != values.length() + 1 {
    raise invalid_step("stairs edges must have one more value than values")
  }
}

///|
fn stairs_points(
  values : Array[Double],
  edges : Array[Double],
  orientation : String,
  baseline : Double,
  close : Bool,
) -> Array[@core.Point] {
  let result = Array(capacity=values.length() * 2 + 2)
  if values.length() == 0 {
    return result
  }
  if close {
    if orientation == "vertical" {
      result.push(@core.point(edges[0], baseline))
      result.push(@core.point(edges[0], values[0]))
    } else {
      result.push(@core.point(baseline, edges[0]))
      result.push(@core.point(values[0], edges[0]))
    }
  } else if orientation == "vertical" {
    result.push(@core.point(edges[0], values[0]))
  } else {
    result.push(@core.point(values[0], edges[0]))
  }
  for index in 0..<values.length() {
    if index > 0 {
      if orientation == "vertical" {
        result.push(@core.point(edges[index], values[index]))
      } else {
        result.push(@core.point(values[index], edges[index]))
      }
    }
    if orientation == "vertical" {
      result.push(@core.point(edges[index + 1], values[index]))
    } else {
      result.push(@core.point(values[index], edges[index + 1]))
    }
  }
  if close {
    let last = values.length() - 1
    if orientation == "vertical" {
      result.push(@core.point(edges[last + 1], baseline))
    } else {
      result.push(@core.point(baseline, edges[last + 1]))
    }
  }
  result
}

///|
/// Add a step plot with `pre`, `post`, or `mid` transition semantics.
pub fn Figure::step(
  self : Figure,
  xs : Array[Double],
  ys : Array[Double],
  where_~ : String = "pre",
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().step(xs, ys, where_~, color~, label~)
}

///|
/// Add a step plot through the axes view.
pub fn Axes::step(
  self : Axes,
  xs : Array[Double],
  ys : Array[Double],
  where_~ : String = "pre",
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let points = step_points(xs, ys, where_)
  let source = step_hit_data(xs, ys, where_, points)
  self.line(points, color~, label~)
  self.record_discrete_line(source)
}

///|
/// Draw a stepwise constant function from values and bin edges.
pub fn Figure::stairs(
  self : Figure,
  values : Array[Double],
  edges~ : Array[Double] = [],
  orientation~ : String = "vertical",
  baseline~ : Double = 0.0,
  fill~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self
  .axes()
  .stairs(values, edges~, orientation~, baseline~, fill~, color~, label~)
}

///|
/// Draw a stepwise constant function through the axes view.
pub fn Axes::stairs(
  self : Axes,
  values : Array[Double],
  edges~ : Array[Double] = [],
  orientation~ : String = "vertical",
  baseline~ : Double = 0.0,
  fill~ : Bool = false,
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  validate_stairs(values, edges, orientation)
  let actual_edges = stairs_edges(values, edges)
  let points = stairs_points(values, actual_edges, orientation, baseline, fill)
  let source = stairs_hit_data(
    values, actual_edges, orientation, baseline, fill, points,
  )
  if fill {
    let resolved_color = self.resolve_color(color)
    self.push_artist(
      Artist::Polygon(
        points,
        @core.style(resolved_color, width=0.0, fill=resolved_color),
      ),
    )
    self.record_discrete_face(source)
    self.add_auto_legend(label, resolved_color, LegendKind::Patch)
  } else {
    self.line(
      stairs_points(values, actual_edges, orientation, baseline, false),
      color~,
      label~,
    )
    self.record_discrete_line(source)
  }
}
