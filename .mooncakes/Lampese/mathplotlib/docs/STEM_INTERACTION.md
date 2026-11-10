# Stem interaction

`Figure::stem` and `Axes::stem` keep their existing signature, validation,
static SVG and `N+2` artist order. They add `HitKind::Stem` for the actual
rods and default circular heads. The existing Stem container remains a
snapshot of those same artists.

For either component, `point.point_index` is the original input index,
`value` is the original head scalar, and the data coordinate is the original
head `(location, head)`, exchanged for horizontal stems. `band` is
`BandInfo(bottom, head, horizontal, false)`; decreasing and negative bounds
retain their direction. `series` is the supplied label. Bottom is a reference
value rather than another observation.

Each rod retains its real component `artist_index`. All heads share the real
final Scatter artist's index. For an isolated stem call starting at artist
`s`, rod `i` is `s+i`, the static baseline is `s+N`, and the heads are `s+N+1`.
Additional images, removed lines and other artists can change these actual
indices without changing the original input indices.

Rods use their actually written nonzero line segments; heads use the centers
of actually written default circles. Both hit modes use physical proximity
with the caller's CSS pixel radius. There is no panel-wide Stem XNearest
fallback. The global baseline has no semantic target; its intersection with
a real rod still selects that rod's original head datum. NaN or invalid
locations preserve index holes. A zero-height rod has only its visible head.

Panel clipping and axis reversal retain the original head and band even when
only a middle part of a rod is visible. Invalid scale endpoints are not
repaired into new geometry: a Log-invalid bottom can leave a valid head circle
without a rod. Known transparent stroke and fill produce no corresponding
targets. Circle visibility follows its actual fill and radius, independently
of stroke width or line alpha.

Source values are copied once per call and shared by constant-size component
records. Rod validation is constant-time; the complete heads array is checked
once. Changed actual geometry and an overriding prepared Line context
conservatively disable stale Stem semantics without inventing ordinary bottom
points. General Line2D caches and the public container API are unchanged.
Unsupported nondefault head markers and dashed rods keep their static output
without new Stem targets.

Later painted rods and heads can be selected over earlier filled regions;
later regions cover earlier stems. Repeated heads at the same position use
the later original index. Default Rabbita tooltips display Location, Value
and Bottom. Custom callbacks receive the same immutable scalar metadata as
`hit_test` followed by `hit_info`.
