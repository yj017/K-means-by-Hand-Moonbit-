# Hexbin interaction

`Figure::hexbin` and `Axes::hexbin` now prepare whole-face hover/click targets
when `marginals=false` (the default). Rabbita's
existing `view`, `on_event`, `tooltip`, `tooltip_class`, and hit-mode options work
with these targets without a separate chart component.

```moonbit
let fig = @plot.figure(width=640, height=360)
let bins = fig.hexbin(
  [0.8, 1.2, 2.8, 3.1, 3.2],
  [1.6, 2.2, 1.6, 2.0, 2.2],
  values=[2.0, 6.0, 10.0, 20.0, 30.0],
  gridsize=2,
  extent=[0.0, 4.0, 0.0, 4.0],
  reduce="sum",
  bins="log",
  label="Totals",
)
let drawing = fig.to_drawing()
// bins.values() and HitInfo.value contain 8 and 60, not their logarithms.
```

The snippet assumes the facade package is imported as `@plot` and errors are
propagated by the enclosing function. `bins` remains the existing `Hexbin`
result with copying `centers()`, `values()`, and `counts()` accessors.

## Corrected hexagonal partition

The earlier static algorithm assigned rectangular buckets and then drew
separately spaced hexagons. For `extent=[0,4,0,4], gridsize=2`, input `(0.1,0.1)`
was counted in a hexagon centered at `(1,1.5)` whose lowest y was `0.5`.
Neighboring faces could overlap or leave gaps. This release corrects the
mathematical partition; hexbin SVG vertices, centers, counts, reduced groups,
and numerical row/column identities can therefore change. It does not preserve
the old incorrect static output.

The corrected core follows the two interleaved lattices and weighted nearest
selection in the pinned Matplotlib v3.11.2 `Axes.hexbin` source (`_axes.py`,
SHA256 `f61e1cb43575eca70b01c9c80f16d3015e91a8101fe9ce0cc3fdc3d80441c8a7`).
It keeps MoonPlot's existing typed inputs and occupied-only behavior:

- `nx=gridsize`, `ny=max(1,floor(nx/sqrt(3)))`. Keeping `ny>=1` preserves the
  accepted `gridsize=1` case. Steps are `sx=x_span/nx`, `sy=y_span/ny` in the
  current axes' transformed coordinates.
- Integer centers `(i,j)` and half-grid centers `(i+0.5,j+0.5)` are compared
  using normalized `dx²+3dy²`. Nearest integer coordinates use ties-to-even;
  equal distances between the two families choose the half grid. Half-grid
  coordinate ties choose the floor-indexed candidate, clamped to the valid
  finite grid at the maximum extent edges.
- `row=2*j+parity`, `column=i`, where parity is zero for integer centers and
  one for half centers. Odd rows shift X by half a column; rows advance by half
  a Y step. Return order remains the first occurrence of each occupied cell.
- The matching vertices are offsets `(±sx/2,±sy/6)` and `(0,±sy/3)`. Shared
  vertices use identical global integer-numerator expressions, avoiding seams
  from different arithmetic orders. Each retained sample belongs to its actual
  face; neighboring lattice faces share edges without positive-area overlap.
- Explicit extents retain MoonPlot's original data units, reversed-bound
  handling and inclusive prefilter on all four edges. No extra extent padding
  or zero-count cells are added. A sparse plot can have unpainted empty cells.
  Input order within a reducer group is preserved.

The example above has centers `(1,2)` and `(3,2)`, both on row 1, columns 0 and 1,
and counts 2 and 3. With `mincnt=3`, only the second is returned, at index 0.

## Source metadata

A hit has `HitInfo.kind == Hexbin`, its supplied label in `series`, and
`HitInfo.hexbin: HexbinInfo?` with immutable scalar fields:

| Field | Meaning |
| --- | --- |
| `row`, `column` | Zero-based lattice indices calculated during the original binning |
| `count` | Number of input samples aggregated into this occupied bin |
| `reduction` | `Count`, `Mean`, `Sum`, `Min`, `Max`, or `Custom` |

`HitPoint.data_x` and `data_y` are the original bin center, rather than an
individual input sample or a cursor interpolation. `HitPoint.point_index`
indexes the arrays returned by this call to `hexbin`, after `mincnt` filtering.
Invisible or offscreen faces do not compact that index again. Each cell is
still a separate Polygon artist; `artist_index` follows the frame's actual
artist ordering.

`HitInfo.value` is the already computed count or reduced scalar. With no
`values`, reduction is `Count` regardless of the `reduce` string. A supplied
`reduce_fn` takes precedence and reports `Custom`; preparing or rebuilding a
Drawing never calls it again. Color normalization, identical colors, and
`bins="log"` cannot change the stored value. The raw sample count remains
available even when the value represents a mean, sum, or custom result.

The facade re-exports `HexbinInfo` and `HexbinReduction`. Drawing adds the
optional `hexbin=None` argument to `hit_info`; existing calls keep their
defaults. Exhaustive matches on `HitKind` must add the `Hexbin` case.

## Actual geometry and ordering

Scene records source semantics when it pushes each original Polygon. The
renderer captures the same valid vertices emitted by the ordinary polygon
writer, maps them with that draw's scales and panel rectangle, and checks that
all six form a finite, strictly convex face. A diagonal divides that real
six-sided face into two immutable `Quadrilateral` targets. Both share one
`HitInfo` and one `HitPoint`; the Drawing's point array contains the bin once.
No new public hit shape or mutable polygon collection is needed.

Both halves and their common diagonal return the same cell. Bounding-box
corners outside the polygon do not hit. A bbox is used only to discard faces
wholly outside the panel, while a visible face whose center lies outside the
viewport remains selectable. The panel bounds clip hits; legend exclusions,
later painted faces, later visible error-bar/box-plot geometry, multiple panels,
CSS viewport mapping, and letterboxing retain their existing ordering rules.
`Nearest` and `XNearest` both select the containing face; hexbin does not add a
nearest-center fallback outside a face.

Logarithmic, SymLog, Asinh, and Logit coordinate scales use the existing
transformed-coordinate binning and inverse-mapped centers/vertices. This is
independent of linear/log color bins. Changing axes later maps the stored
polygons with the new drawing configuration; it does not repeat aggregation.

## Visibility and scope

- Only occupied cells passing `count >= mincnt` exist. `mincnt=0` does not
  synthesize empty cells. Extent filtering and the returned ordering are kept.
- `marginals=true` keeps the entire call static for this slice. Marginal
  rectangles are painted over the cells within the same axes and include
  counts from cells filtered by `mincnt`; no Hexbin targets are emitted for
  either the faces or these rectangles. X marginals group actual integer/half
  column centers, while Y marginals group encoded rows. Their midpoint-based
  intervals are clipped to the extent, retain each direction's total count,
  and use that direction's maximum group count to bound the bar thickness.
- Colormap sampling retains actual RGBA alpha for capture. Known invisible
  explicit fills (`none`, `transparent`, zero-alpha hex colors) have no interior
  target, even with a visible outline. Other CSS paints retain the existing
  conservative paint handling; dynamic CSS and functional `rgba(...)` alpha
  are not fully resolved by the library's small color parser.
- Nonfinite reduced results, incomplete vertices after an axis-domain change,
  degenerate faces, and mapped faces failing convexity retain their ordinary
  static SVG but have no Hexbin target. Input/reducer validation and static
  drawing behavior are unchanged.
- Arbitrary Polygon artists and hexbin marginal bars do not acquire inferred
  bin semantics. No bin intervals are fabricated from a hexagon's bbox.

The default tooltip shows the center's x/y and sample Count. Reduced bins also
show Value. A custom Rabbita tooltip receives the full typed `HexbinInfo` and
can supply units, localized labels, reducer names, and application formatting.
