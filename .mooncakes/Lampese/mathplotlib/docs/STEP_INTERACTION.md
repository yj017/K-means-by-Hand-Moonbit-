# Step interaction

`Figure::step` and `Axes::step` keep their existing parameters and SVG paths.
Their interactive Drawing now identifies original `xs`/`ys` samples rather
than the extra vertices used to draw the stairs.

```moonbit
let fig = @plot.figure()
fig.step([0.0, 2.0, 5.0], [2.0, 6.0, 4.0], where_="post", label="Samples")
let frame = fig.to_drawing()
```

A hit returns `HitKind::Step`, the original `point.point_index`, original
`point.data_x/data_y`, `value=ys[i]`, the series label, and the sample's optional
plateau `interval`. Intervals retain input direction on descending data or
reversed axes:

- `pre`: sample `i>0` owns `(xs[i-1], xs[i]]`; the first sample has no plateau.
- `post`: sample `i<n-1` owns `[xs[i], xs[i+1])`; the last sample has no plateau.
- `mid`: boundaries use the existing arithmetic data midpoints. A plateau
  starts at the preceding midpoint and ends at the next midpoint, with the
  outer endpoints at the first and last source x. Midpoint transitions enter
  the next sample.

`HitInfo.interval` stores the two finite numeric endpoints, without open/closed
flags. Missing or nonfinite plateau bounds give `None` rather than an invented
range. The vertical interior of a jump belongs to the sample it enters; its
value is the actual source y, never an interpolation along the jump.

An exact unique original sample coordinate retains that sample's index.
Synthetic corners use later path-edge order. Coincident original samples use
the later original index, independently of endpoint capture order; one pointer
position cannot select every duplicate.
The screen anchor can lie on the actual visible segment while data coordinates
remain the source sample.

Both hit modes can select the actual visible plateau and jump segments using
the supplied CSS-pixel radius. `XNearest` additionally falls back to real source
points inside the panel. Expanded corners never enter that fallback. Clipping,
axis scales, legends, and panel exclusions use the same drawing frame.

NaN/Inf and invalid-scale vertices split paths exactly as in the SVG renderer;
valid runs keep their original sample slots. No line bridges missing data.
An isolated vertex or a wholly zero-length path produces no new segment hit.

The source record is copied. Modifying caller input arrays does not change it.
For attached Line2D handles, the actual drawing context must still match the
original data containers, current XY cache, complete path, and default
drawstyle. Data replacement, borrowed-view changes, or another drawstyle
conservatively fall back to ordinary current Line semantics. A matching NaN
is only a missing marker at the same slot, never a wildcard for changed data.
Removed/cleared artists do not transfer their record to reused positions.

This first implementation captures visible solid strokes. Dashed strokes use
the existing ordinary Line interaction until their dash geometry is supported.
Hidden, zero-width, zero-alpha and known transparent Step strokes have no
semantic targets. Static SVG and existing Line2D conversion/error timing are
preserved.

Default Rabbita tooltips show Range when present and the original Value.
Custom tooltips receive the same immutable HitInfo returned by
`Drawing::hit_test` followed by `Drawing::hit_info`.
