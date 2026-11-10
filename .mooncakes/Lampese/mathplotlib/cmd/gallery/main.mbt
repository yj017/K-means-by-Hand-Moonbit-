///|
/// A small gallery of everyday charts, printed as one SVG document.
fn main raise {
  let fig = @mathplotlib.figure(width=1200, height=420)
  let panels = fig.subplots(1, 3)
  fig.subplots_adjust(
    left=0.065,
    right=0.97,
    bottom=0.19,
    top=0.80,
    wspace=0.38,
  )
  fig.suptitle("MoonPlot | everyday charts")
  let line = panels[0]
  line.set_title("Line")
  line.set_x_label("time")
  line.set_y_label("value")
  line.grid(visible=true, color="#e2e8f0", linewidth=0.7)
  line.plot(
    [0.0, 1.0, 2.0, 3.0, 4.0],
    [1.0, 2.4, 1.8, 3.2, 4.0],
    color="#2563eb",
    label="Series A",
  )
  line.plot(
    [0.0, 1.0, 2.0, 3.0, 4.0],
    [0.7, 1.3, 2.1, 2.0, 2.8],
    color="#f97316",
    label="Series B",
  )
  line.set_legend_position(@mathplotlib.LegendPosition::UpperLeft)
  let scatter = panels[1]
  scatter.set_title("Scatter")
  scatter.set_x_label("x")
  scatter.set_y_label("y")
  scatter.grid(visible=true, color="#e2e8f0", linewidth=0.7)
  scatter.scatter(
    [
      @mathplotlib.point(1.0, 1.2),
      @mathplotlib.point(1.5, 2.0),
      @mathplotlib.point(2.0, 1.7),
      @mathplotlib.point(2.5, 3.1),
      @mathplotlib.point(3.0, 2.6),
      @mathplotlib.point(3.5, 3.8),
      @mathplotlib.point(4.0, 3.4),
    ],
    color="#16a34a",
  )
  let bar = panels[2]
  bar.set_title("Bar")
  bar.set_x_label("category")
  bar.set_y_label("count")
  bar.grid(visible=true, axis="y", color="#e2e8f0", linewidth=0.7)
  bar.bar_category(["A", "B", "C", "D"], [3.0, 5.0, 4.0, 7.0], color="#f97316")
  println(fig.to_svg_checked())
}
