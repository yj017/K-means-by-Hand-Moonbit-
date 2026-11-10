///|
// This callback sees the same valid source polygon that append_polygon wrote.
// Only 1D-boundary flat meshes attach MeshHitData; general polygons and the 2D
// grid/nearest/Gouraud APIs keep their existing static-only behavior.
fn collect_drawing_mesh(
  output : DrawingCapture,
  panel_index : Int32,
  artist_index : Int32,
  points : Array[@core.Point],
  scale : Scale,
  position : (Double, Double, Double, Double),
  metadata : @render.HitMetadata,
) -> Unit {
  guard metadata.mesh() is Some(mesh) else { return }
  if points.length() != 4 || mesh.columns <= 0 {
    return
  }
  let (left, top, width, height) = position
  let screen = points.map(p => {
    (map_x(scale, left, width, p.x()), map_y(scale, top, height, p.y()))
  })
  let a = screen[0]
  let b = screen[1]
  let c = screen[2]
  let d = screen[3]
  // Never turn a partially valid or changed quadrilateral into a bounding box.
  if a.0 != d.0 || b.0 != c.0 || a.1 != b.1 || c.1 != d.1 {
    return
  }
  let cell = mesh.cell
  collect_drawing_cell(
    output,
    panel_index,
    artist_index,
    {
      row: cell.row,
      column: cell.column,
      columns: mesh.columns,
      value: mesh.value,
      x_range: cell.x_range,
      y_range: cell.y_range,
      rectangle: (
        a.0.min(b.0),
        a.1.min(d.1),
        (b.0 - a.0).abs(),
        (d.1 - a.1).abs(),
      ),
    },
    position,
    kind=if mesh.histogram { Histogram2D } else { Heatmap },
  )
}
