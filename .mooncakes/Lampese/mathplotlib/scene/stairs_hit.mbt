///|
fn stairs_hit_data(
  values : Array[Double],
  edges : Array[Double],
  orientation : String,
  baseline : Double,
  fill : Bool,
  path : Array[@core.Point],
) -> @render.DiscreteLineHitData {
  let horizontal = orientation == "horizontal"
  let datums = []
  for i, value in values {
    let p = if horizontal {
      @core.point(value, edges[i])
    } else {
      @core.point(edges[i], value)
    }
    datums.push(
      @render.discrete_datum(
        i,
        p,
        value,
        interval=Some((edges[i], edges[i + 1])),
        band=if fill {
          Some(@drawing.band_info(baseline, value, horizontal~))
        } else {
          None
        },
      ),
    )
  }
  let owners = []
  if fill && !values.is_empty() {
    owners.push(0)
  }
  for i in 0..<values.length() {
    if i > 0 {
      owners.push(i)
    }
    owners.push(i)
  }
  if fill && !values.is_empty() {
    owners.push(values.length() - 1)
  }
  @render.discrete_line_hit_data(Stairs, path, datums, owners).unwrap()
}
