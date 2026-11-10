///|
/// Print a small SVG example so the package can be tried without extra tooling.
fn main raise {
  let fig = @mathplotlib.figure(width=640, height=400)
  fig.set_title("MoonBit mathplotlib")
  fig.set_x_label("x")
  fig.set_y_label("y")
  fig.plot([0.0, 1.0, 2.0, 3.0], [0.0, 1.0, 0.5, 2.0])
  println(fig.to_svg())
}
