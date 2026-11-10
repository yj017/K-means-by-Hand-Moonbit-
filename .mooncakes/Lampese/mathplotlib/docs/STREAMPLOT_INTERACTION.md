# Streamplot body interaction

`Figure::streamplot`, `Axes::streamplot`, the `streamplot_mesh` wrappers and
`streamplot_with_style_grids` keep their current parameters, integration,
seeding, colors and SVG output. `to_drawing()` adds `HitKind::Streamplot` to
continuous body strokes. The returned `StreamplotSet` and the single complete
Streamplot Container retain their existing line and arrow artists.

## Generated samples and indices

Each body-edge target contains optional, read-only `HitInfo.streamplot`:

```mbt
StreamplotInfo {
  seed_index : Int32
  u : Double
  v : Double
  color_value : Double?
}
```

The root facade exports `StreamplotInfo` and
`streamplot_info(seed_index, u, v, color_value~=None)`. The record contains no
mutable field grid or trajectory arrays. `HitInfo.streamplot` defaults to None
for callers constructing their own metadata.

- `seed_index` is the original seed-attempt slot, including rejected seeds.
  Explicit starts and the existing default seed sequence use the same rule.
  Occupied, stagnant or short trajectories leave gaps in this index.
- `point.point_index` is edge i in the original joined generated trajectory:
  `line[i]` to `line[i + 1]`. Backward and forward integration use the joined
  path's actual order. Missing style samples and invalid axis-domain runs do
  not compact these edge slots.
- `point.artist_index` identifies the actual current body Line. A uniform
  trajectory usually has one Line; style grids can split it into separate
  two-point artists. This index is independent of seed and edge slots.
- `series` is the immutable label of the call that generated the body.
- `u` and `v` are the existing bilinear field samples at the old arithmetic
  edge midpoint `((ax + bx) / 2, (ay + by) / 2)`. They are generated field
  estimates, rather than original grid observations, normalized integration
  directions or values recalculated under the pointer.
- `HitInfo.value` always equals the sampled **V component**.
- `color_value`, when present, is the raw scalar from the same midpoint
  evaluation that painted the style-grid edge, before normalization and color
  mapping. It can lie outside explicit color bounds. No color grid means None,
  including when a linewidth grid splits the trajectory.

No matrix row/column, category, interval, fraction or vector magnitude is
invented. The old sampler, interpolation arithmetic and integration behavior
remain in use. If the old midpoint or a new U/V sample cannot be finite, that
actually painted edge remains static. Existing missing style samples continue
to omit exactly the body artists they omitted before.

## Physical stroke hits

Both Nearest and XNearest use real, nonzero body Segment targets and the CSS
pointer radius. They can hit between generated vertices. Empty panel space
does not snap to the closest trajectory merely because its x coordinate is
nearby. Overlapping strokes and other interactive fills follow actual paint
order and the existing Segment tie rules.

Capture uses the successful Line writer's consecutive valid runs. A domain
gap does not become a bridge. Only the part intersecting the plot can receive
hits; reversed and nonlinear axes retain original seed and edge identity.
Actual solid-line width, alpha and paint visibility apply. Zero-width,
transparent and unproven dashed replacements stay static.

`point.data_x/data_y` describe the original generated edge midpoint before
clipping. `point.screen_x/screen_y` describe the visible clipped stroke's
midpoint. The two anchors can map differently after clipping. They do not
claim an observed grid coordinate or the pointer's current field value.

Arrow components remain static in this slice. Every actual shaft, open or
filled head and bar is marked as owned static, including shafts absent from
`StreamplotSet.arrows()`. Their paint and return behavior stay intact; they do
not produce generic generated-y Point tooltips or new arrow hit regions.
An interactive body stroke can still pass underneath their static paint.

## Tooltips and callbacks

The default Rabbita tooltip shows the call's series, **U**, **V**, and
**Color value** only when a raw color sample is present. It avoids an
observation-style XY or speed-magnitude display. A manually constructed
Streamplot hit without typed metadata safely falls back to Value.

A custom tooltip or event callback can read the same frame's immutable values:

```mbt
if info.kind is Streamplot && info.streamplot is Some(sample) {
  let original_seed_slot = sample.seed_index
  let generated_edge_slot = info.point.point_index
  let u = sample.u
  let v = sample.v
  let raw_color_value = sample.color_value
  // Add application units and labels without re-sampling the field.
}
```

## Provenance, lifecycle and cost

Each trajectory copies its generated points and optional edge samples once.
Uniform body Lines guard their actual array identity and contents once per
frame. Split Lines check their own two points and retain a constant offset
into that shared source. Geometry storage, snapshot guarding, preparation and
capture are O(points + edges), without a whole-trajectory or mesh copy per edge.
The additional U/V sample construction deliberately retains the old linear
axis locator: its lookup work is **O(edges × (nx + ny))**. This is separate
from the geometry cost; the total routine is not claimed to be strictly linear.

The existing Set getters copy their outer arrays while nested point arrays
can alias the actual artists. Changing those points invalidates affected
current ownership, while a previously built Drawing remains immutable.
Changes to original field or style-grid arrays after construction do not
re-sample stored metadata or repaint existing artists.

Lost identity, changed contents, incompatible artist types, conflicting
metadata and unproven prepared Line contexts stay static. They cannot revive
generic Point targets or borrow another chart's semantics. Prepared provider
painting and completion still run. Images, inline contour expansion,
ordinary Line removal and clear maintain ownership alignment; frame indices
are not persistent across rebuilds.

An empty or rejected stream call keeps its old static legend and empty
Streamplot Container without relabeling an earlier plot's interaction series.

[Capabilities](CAPABILITIES.md) · [Architecture](ARCHITECTURE.md) ·
[Interactive DOM](RABBITA_DOM.md)
