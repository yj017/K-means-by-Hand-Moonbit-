# Line contour interaction

`Figure::contour`, `Axes::contour`, `tricontour` and their triangulation wrappers
retain their existing parameters, validation, `ContourSet` result and Contour
container. Their generated paths and static SVG stay unchanged. Line contours
now expose `HitKind::Contour` through `to_drawing()` and Rabbita.

Each target describes a real, nonzero edge of an emitted contour polyline:

- `value` is the exact resolved scalar **level**, including automatic levels.
- `series` is the label of the call that generated that path.
- `point.point_index` is the original path slot in `ContourSet::segments()`.
  It is neither a grid-cell index nor an observation index. Disconnected paths
  at the same level have different slots. Several edges can share one slot.
- `point.artist_index` identifies the actual current Line fragment.
- `point.data_x` and `point.data_y` are the overflow-safe data-space midpoint of
  that actual valid-run edge **before viewport clipping**.
- `point.screen_x` and `point.screen_y` are the midpoint of its visible clipped
  portion. On nonlinear axes, this need not be the mapped data midpoint.

These coordinates describe generated contour geometry, rather than original
input observations or a sample interpolated at the mouse pointer. The remaining
optional `HitInfo` fields, including `interval`, `fraction`, `cell`, `band`,
`error` and `vector`, have no value for these targets.

Both `Nearest` and `XNearest` require physical proximity to a real Segment.
The radius passed to `hit_test_client` remains in CSS pixels. A closed contour
is a stroked loop, so its empty center does not hit. There are no synthetic
endpoint Points, filled loop targets, grid-cell rectangles or panel-wide
horizontal snapping. Invalid/nonfinite or scale-invalid vertices break the
actual writer's runs; interaction never bridges the resulting gaps. Only
segments intersecting the current panel can hit, with the usual panel and
other-axes exclusions.

## Labels and lifecycle

`clabel(contours)` keeps its existing default inline gap and text rendering.
Both resulting fragments retain the original generated path slot, level and
call label. Text and erased gaps have no contour targets. Returned
`ContourSet::segments()` and level getters still return independent copies of
the original paths, including after inline labeling.

The existing inline eraser can split multiple Lines with identical geometry.
Each known Contour retains its own call's level, slot and label; an ordinary
Line or Barbs component with the same color or coordinates does not become a
Contour. An unproven or invalidated source cannot gain ownership through an
inline split. `inline=false` adds text without undoing an earlier gap; rebuild
the figure when an application wants to toggle inline erasure off.

Known path identity or content changes, or a prepared Line context without
matching Contour provenance, conservatively retain static rendering and omit
interaction. They do not reopen ordinary Line endpoint targets. Source and
fragment snapshots remain private, with one complete geometry guard per
fragment before paint and constant work per captured edge; the input grid is
not copied for every edge. Clear, ordinary Line removal and inline index shifts
keep this ownership aligned with other chart types. An old Drawing retains its
own immutable targets.

An empty line-contour result retains its static legend and Container behavior
without changing the series of an earlier Line or Contour. Transparent paint,
zero width or zero opacity supplies no targets. Unsupported custom dashed
strokes remain conservatively static instead of claiming hit geometry in dash
gaps. Later actual contour strokes can be selected over earlier filled regions;
later filled regions cover earlier strokes.

## Tooltips and example

The default Rabbita tooltip displays the call label and **Level**. A custom
callback receives the same `HitInfo` as `hit_test` followed by `hit_info`; use
“contour-line position” when displaying its generated data coordinates.

```moonbit
let fig = @mathplotlib.figure(width=480, height=320)
let contours = fig.contour(
  [[0.0, 1.0, 2.0], [1.0, 2.0, 3.0], [2.0, 3.0, 4.0]],
  x=[10.0, 20.0, 40.0],
  y=[-3.0, 1.0, 8.0],
  levels=[0.5, 1.5, 2.5],
  label="Field",
)
fig.clabel(contours)
let frame = fig.to_drawing()
// Pass frame to @plot.view; hovered/clicked metadata has kind Contour.
```

`contourf` and `tricontourf` filled bands, multiple rings and holes remain a
separate capability. They do not receive line-level metadata in this slice.
