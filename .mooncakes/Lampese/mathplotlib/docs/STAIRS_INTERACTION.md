# Stairs interaction

`Figure::stairs` and `Axes::stairs` preserve their existing static SVG output
and parameters. Both horizontal and vertical stairs expose `HitKind::Stairs`.

A hit retains the original `values[i]` as `HitInfo.value`, the original index
as `point.point_index`, and the original `(edges[i], edges[i+1])` as `interval`.
Omitted edges use the existing integer boundaries. Descending intervals retain
their input direction. Source data coordinates are `(edges[i], values[i])`,
with x/y exchanged for horizontal stairs. Generated corners are not samples.

For outlines, the actual plateau belongs to its interval and the inside of a
jump belongs to the interval it enters. Exact unique source points retain
their original index. Synthetic-corner ties use later path-edge order.
Repeated original coordinates use the later original index, independently of
endpoint capture order. Missing vertices
split actual outline runs without compacting the original indices.

Filled stairs can be selected throughout each real interval strip, rather than
through the bounding box of the entire stairs polygon. The metadata also
contains `band=BandInfo(baseline, values[i], horizontal, false)`, preserving
negative and decreasing bounds. Outline stairs have `band=None` because their
baseline does not participate in drawing. A zero-area filled interval has no
area target. Shared area boundaries follow the later original interval when
both painted strips contain the location.

Filled interval capture requires finite strictly monotone edges, finite values
and baseline, valid source vertices on the actual axis scales, and the complete
original polygon surviving the renderer's vertex filtering. Nonmonotone or
repeated edges, missing values, and invalid scale endpoints keep their existing
static output without misleading interval targets. In particular a Log-axis
baseline of zero can cause the existing painter to remove vertices; that
altered face is not treated as a collection of original rectangles.

The renderer captures its actual polygon or line runs once, respecting panel
clipping, axis reversal and CSS hit radius. Array inputs are copied. Outline
Line2D mutation uses the same guarded context as Step; replaced data or another
drawstyle falls back to ordinary current Line interaction. Solid visible
strokes are supported; unsupported dash geometry uses the existing Line
fallback. Filled known transparent paints produce no area targets.

Default Rabbita tooltips show Range, Value and the actual filled Baseline when
available. Custom callbacks receive those same immutable scalar fields.
