# Quiver interaction

`Figure::quiver(xs, ys, us, vs, color~="", label~="")` and the equivalent
`Axes::quiver` keep their existing validation, `Unit` return, single artist and
Quiver container. Static SVG and arrow calculations remain unchanged.

The actual arrow consists of three stroked SVG lines: shaft, first wing,
second wing. Each visible line supplies a `HitKind::Quiver` Segment target;
there is no filled arrowhead triangle or additional tail point. Both hit modes
use physical proximity and the caller's CSS pixel radius, without a panel-wide
`XNearest` fallback.

Every part returns the same original datum:

- `point.point_index`: original input index, including gaps left by skipped arrows.
- `point.data_x` and `point.data_y`: original tail position.
- `vector`: readonly `VectorInfo{u,v}`, containing the original data-space components.
- `value`: original **V component**, rather than vector length or screen length.
- `series`: supplied label; `point.artist_index`: the actual Quiver artist.

The existing Scene API rejects a nonfinite value in any of the four input
arrays for the whole call. Zero vectors, invalid scale endpoints, and endpoint
addition overflow retain their static behavior and do not fabricate hit
geometry. A finite vector whose mathematical length exceeds the floating-point
range can still be drawn on a nonlinear scale and retains its original U/V.
This interaction API does not calculate magnitude.

Hit geometry comes from the same successful writes as the SVG. Each segment
must intersect the panel; its anchor is the midpoint of that visible portion.
Clipping and reversed axes retain original tail/component values, even if the
tail and tip lie outside the panel or only a wing enters it. This does not add
an SVG clip path to the existing static renderer. Known transparent stroke
colors and zero stroke width produce no targets. Separate line alpha, dash,
fill and linestyle settings are not emitted by this Quiver writer and do not
suppress a stroke it actually writes.

Input data is copied into one call-level source table. Both actual arrays must
retain their source identity, and one complete content check precedes the
artist's actual paint. Changed arrays or unbound low-level IR geometry keep
their static output with conservative semantic omission. No per-arrow copy of
the entire call is made. Quiver does not invoke or replace the Line2D prepared
context provider.

Later actual arrow strokes can be selected over earlier filled regions;
later filled regions cover earlier arrows. Same-position arrows from later
calls retain their own real artist and label. Default Rabbita tooltips display
X, Y, U and V. Custom callbacks receive the same immutable scalar metadata as
`hit_test` followed by `hit_info`; an independently constructed Quiver hit
without `vector` safely displays only X and Y.
