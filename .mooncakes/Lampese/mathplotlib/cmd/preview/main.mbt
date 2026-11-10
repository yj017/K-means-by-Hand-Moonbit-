///|
/// Render a small two-series chart with the existing library.
fn main raise {
  let xs = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
  let first = [
    9.0, 12.0, 18.0, 16.0, 24.0, 28.0, 27.0, 34.0, 38.0, 36.0, 44.0, 48.0,
  ]
  let second = [
    6.0, 9.0, 10.0, 14.0, 17.0, 19.0, 23.0, 22.0, 28.0, 31.0, 33.0, 39.0,
  ]
  let fig = @mathplotlib.figure(width=880, height=460)
  fig.set_title("Two series (sample data)")
  fig.set_x_label("Week")
  fig.set_y_label("Tasks")
  fig.set_x_limits(0.5, 12.5)
  fig.set_y_limits(0.0, 65.0)
  fig.set_x_ticks(xs)
  fig.set_x_tick_labels([
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12",
  ])
  fig.set_y_ticks([0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0])
  fig.set_y_tick_labels(["0", "10", "20", "30", "40", "50", "60"])
  fig.grid(visible=true, color="#e2e8f0", linewidth=0.7)
  fig.plot(xs, first, color="#2563eb", label="Series A")
  fig.plot(xs, second, color="#f97316", label="Series B")
  fig.scatter(
    xs.map(x => @mathplotlib.point(x, first[x.to_int() - 1])),
    color="#2563eb",
  )
  fig.scatter(
    xs.map(x => @mathplotlib.point(x, second[x.to_int() - 1])),
    color="#f97316",
  )
  fig.legend(fig.legend_entries())
  println(fig.to_svg_checked())
}
