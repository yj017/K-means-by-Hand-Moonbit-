# Filled contour interaction

`contourf`, `tricontourf` and their triangulation wrappers keep their existing
parameters, field clipping, generated paths, masks, colors, `ContourSet` getters,
Container and static SVG. Their `to_drawing()` output adds `HitKind::ContourF`
for the actual painted scalar bands.

Each band artist supplies one `HitShape::FilledRegion`, including all of its
successfully written boundary loops. A simple Polygon uses SVG's nonzero fill
rule; a CompoundPolygon uses its actual even-odd rule across every loop.
Holes and the gap between disconnected components stay empty, allowing earlier
paint to show and interact through them. Rings are not independently filled
hit targets, bounding boxes or fan triangles. Both hit modes use physical fill
containment. Increasing the hover radius does not fill a hole or snap across
an empty panel.

## Band metadata

- `interval` is the exact finite scalar clipping pair: ordinary resolved
  interval `[levels[i], levels[i+1]]`, under extension `[data_min, levels[0]]`,
  or over extension `[levels[last], data_max]`.
- `value` is that interval's representative midpoint, rather than a field value
  sampled at the cursor. Finite existing layer values are preserved exactly;
  when adding two finite endpoints overflows, only interaction uses a safe
  half-plus-half average. Existing `ContourSet` getter arithmetic is unchanged.
- `series` is the immutable label of the generating call.
- `point.point_index` is the original logical band/color slot, including gaps
  left by empty bands or requested empty extensions. With an under extension,
  ordinary interval `i` uses slot `i+1`; otherwise it uses slot `i`. Under is
  slot0, and over follows the last ordinary slot.
- `point.artist_index` is the actual current Polygon or CompoundPolygon.
  `category`, `cell`, `band`, `vector`, `error` and `fraction` have no value.

Logical band slots are neither flattened `segments()` ring indices nor
`layers()` indices. One band can return several boundary loops. Empty bands
have no artist, while their original slot remains reserved. `layers()` also
deduplicates representative values and has its existing fallback when there
are no paths. Use `interval` and the original logical slot as band identity,
not color, representative-value equality or a returned ring index.

The existing scalar clipping includes both boundaries; later actual paint
wins when neighboring bands share a boundary. Extensions report their actual
finite clipping range without fabricated infinite endpoints.

## Geometry anchors and paint

`point.data_x/y` and `point.screen_x/y` describe generated region geometry,
not a grid observation or mouse sample. The renderer scans the actual emitted
mapped boundary edges. For the first nonzero edge intersecting the plot,
data coordinates are its safe midpoint before viewport clipping, and screen
coordinates are the midpoint of its visible clipped portion. These need not
be the same mapped point on a nonlinear axis.

If no boundary intersects the plot, one exact-rule containment check at the
plot center distinguishes whole-plot coverage from a hole or empty viewport.
A covered viewport uses its center as the screen anchor and the first emitted
fillable nonzero edge's safe data midpoint as the data anchor. Otherwise it
has no target. Collinear rings do not create fill or supply fill anchors;
self-crossing lobes are retained even when signed area cancels.

Interaction is limited to the usual plot bounds and panel exclusions. The
legacy static writer can paint beyond those bounds into a figure margin;
that margin remains static. This feature does not add an SVG axes clip path.
Invalid-scale vertices follow the writer's actual filtering and closure, so
semantic geometry uses the exact successfully emitted loops.

Zero stroke width does not suppress a visible fill. Transparent or absent
fill supplies no target. Separate Line alpha is not emitted by these polygon
writers and does not suppress a fill they actually write. Strokes are outside
this fill-only capability. Later filled bands cover earlier shapes; visible
statistical or contour strokes painted later remain selectable above a fill.

## Immutable regions and source ownership

`filled_region(rings, even_odd=false)` constructs an opaque `FilledRegion`
from `Array[Array[(Double, Double)]]` screen coordinates. Construction copies
both array levels. `rings()` returns deep copies and `even_odd()` returns the
rule. Region validation, fillable-ring mask and actual-extrema bounds are
cached privately. Sharing a region between manually built shapes or Drawings,
or mutating constructor inputs/getter arrays, cannot change an old Drawing.

Generated bands retain their original outer and inner identities, one expected
geometry snapshot and scalar lineage. A complete guard precedes actual paint
once per artist. Identity/content changes conservatively retain static output
and omit interaction; they cannot borrow another call's band metadata. Clear,
ordinary Line removal, image prefixes and inline contour index changes keep
filled-band, line-contour and Barbs ownership aligned. Empty filled results
retain static legend/Container behavior without relabeling a previous artist.

Extra snapshot, guard and capture work is linear in generated geometry.
There is one complete region per band artist, with no grid copy per edge or
new field calculation. Pointer containment visits the region's relevant
boundary edges; it does not repeat complete validation.

The default Rabbita tooltip displays **Range** and **Representative**, together
with the call label. A custom callback receives the same immutable `HitInfo`
as `hit_test` followed by `hit_info`; generated anchor coordinates should not
be presented as original observations.
