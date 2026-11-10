///|
/// Draw a vector field on the current axes.
pub fn quiver(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().quiver(xs, ys, us, vs, color~, label~)
}

///|
/// Draw one data-coordinate arrow on the current axes.
pub fn arrow(
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
  color~ : String = "",
  linewidth~ : Double = 1.0,
  head_length~ : Double = 0.15,
  head_width~ : Double = 0.10,
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().arrow(
    x,
    y,
    dx,
    dy,
    color~,
    linewidth~,
    head_length~,
    head_width~,
    label~,
  )
}

///|
/// Draw a vector key arrow and label on the current axes.
pub fn quiverkey(
  x : Double,
  y : Double,
  value : Double,
  label : String,
  color~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().quiverkey(x, y, value, label, color~)
}

///|
/// Draw basic wind barbs for paired vectors on the current axes.
pub fn barbs(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  barb_length~ : Double = 0.25,
  label~ : String = "",
) -> Unit raise @core.DataError {
  require_axes().barbs(xs, ys, us, vs, color~, linewidth~, barb_length~, label~)
}

///|
/// Draw wind barbs with Matplotlib-style increments and pivot options.
pub fn barbs_with_options(
  xs : Array[Double],
  ys : Array[Double],
  us : Array[Double],
  vs : Array[Double],
  color~ : String = "",
  linewidth~ : Double = 1.0,
  barb_length~ : Double = 0.25,
  label~ : String = "",
  half_increment~ : Double = 5.0,
  full_increment~ : Double = 10.0,
  flag_increment~ : Double = 50.0,
  rounding~ : Bool = true,
  flip~ : Bool = false,
  fill_empty~ : Bool = true,
  pivot~ : String = "tail",
) -> Unit raise @core.DataError {
  require_axes().barbs_with_options(
    xs,
    ys,
    us,
    vs,
    color~,
    linewidth~,
    barb_length~,
    label~,
    half_increment~,
    full_increment~,
    flag_increment~,
    rounding~,
    flip~,
    fill_empty~,
    pivot~,
  )
}
