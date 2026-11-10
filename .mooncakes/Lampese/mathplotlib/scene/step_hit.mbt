///|
fn step_hit_data(
  xs : Array[Double],
  ys : Array[Double],
  mode : String,
  path : Array[@core.Point],
) -> @render.DiscreteLineHitData {
  let n = xs.length()
  let datums = []
  for i in 0..<n {
    let interval = if n < 2 {
      None
    } else if mode == "pre" {
      if i == 0 {
        None
      } else {
        Some((xs[i - 1], xs[i]))
      }
    } else if mode == "post" {
      if i + 1 == n {
        None
      } else {
        Some((xs[i], xs[i + 1]))
      }
    } else {
      Some(
        (
          if i == 0 {
            xs[0]
          } else {
            (xs[i - 1] + xs[i]) / 2.0
          },
          if i + 1 == n {
            xs[i]
          } else {
            (xs[i] + xs[i + 1]) / 2.0
          },
        ),
      )
    }
    let interval = match interval {
      Some((a, b)) =>
        if a.is_nan() || a.is_inf() || b.is_nan() || b.is_inf() {
          None
        } else {
          Some((a, b))
        }
      None => None
    }
    datums.push(
      @render.discrete_datum(i, @core.point(xs[i], ys[i]), ys[i], interval~),
    )
  }
  let owners = []
  for i in 1..<n {
    owners.push(if mode == "pre" { i } else { i - 1 })
    owners.push(i)
    if mode == "mid" && i + 1 == n {
      owners.push(i)
    }
  }
  @render.discrete_line_hit_data(Step, path, datums, owners).unwrap()
}
