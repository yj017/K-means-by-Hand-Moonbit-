# Barbs interaction

`Figure::barbs` and `Axes::barbs` retain their existing arguments, `Unit`
return, component order and static SVG. `barbs_with_options` keeps the same
increment, rounding, flip, calm-circle and pivot options. Neither API adds a
container. Each wind glyph continues to consist of ordinary Line, Polygon
and optional circular Scatter artists.

Every visible component provides `HitKind::Barbs` with the same original datum:

- `point.point_index` is the original input index, retaining gaps from skipped glyphs.
- `point.data_x` and `point.data_y` are the input position **before pivot**.
  Under `middle` or `tip`, this position is not necessarily the shaft tail.
- `vector` is the readonly `VectorInfo{u,v}` containing the original components.
- `value` is the original **V component**, rather than vector magnitude.
- `series` is the immutable call label; `point.artist_index` identifies the
  actual shaft, feather, flag or circle component artist.

The basic API captures actual nonzero shaft and feather segments from the
same valid runs that its SVG writer emitted. It does not turn a lone valid
vertex into a wind observation. In particular, an invalid Log shaft endpoint
can leave actual visible feathers without a shaft target.

Advanced flags capture their real triangle fill and visible three outline
edges. The filled region uses an existing quadrilateral with its final vertex
repeated; it does not substitute a bounding rectangle. A zero stroke width
retains the flag fill. Degenerate triangles create no filled region.

Calm glyphs are the actual filled circle, represented by a full Sector. The
circle radius is `barb_length * 0.3` SVG pixels; its fill is independent of
stroke width. A small nonzero vector can round to a calm glyph. Its circle is
drawn at the existing pivot-adjusted end, while metadata retains the input
position and original nonzero U/V. No hollow ring or zero vector is invented.

Both hit modes use physical geometry: CSS pixel proximity to real segments,
and actual filled containment for flags and circles. There is no panel-wide
Barbs `XNearest` fallback or extra endpoint observation. Axis reversal,
nonlinear mapping and panel intersections preserve raw input values. Targets
use only the panel-intersecting geometry; this does not add a static SVG clip
path. Known transparent paint, zero-radius circles and invisible strokes do
not create targets. Fill and stroke visibility follow their actual writers
separately. Later visible wind strokes can be selected over earlier fills;
later filled regions cover earlier components.

Input values and the call label are copied once into a shared source table.
Each component retains only a constant-size view and its one, two or three
expected path points, giving O(N+P) metadata for N inputs and P components.
Identity and current small-path guards prevent stale semantics. Known wind
components that lose their array identity remain static through an explicit
disabled provenance marker. Image prefixes, inline-contour expansion, normal
Line removal and clearing retain the correct intent alignment. Overriding
prepared Line contexts without matching Barbs provenance remain static too.
These cases do not reactivate generic Line or Scatter endpoint hints. Ordinary
Line behavior and its prepared-context cache remain unchanged.

Validation remains ordered by original input: an error at a later datum keeps
the already created valid prefix. Empty, zero and `fill_empty=false` calls that
create no component preserve prior series metadata while retaining their
existing static legend and color behavior.

Advanced expansion rejects nonfinite derived magnitudes or counts and counts
that cannot fit the existing integer component-array length, using the existing
`InvalidQuiver` error before integer conversion or component expansion. It
does not impose an arbitrary small component cap. The valid prefix remains
when a later datum fails. Normal glyph calculations and SVG are unchanged.
The basic API retains its existing arithmetic: norm underflow can omit a glyph;
norm overflow can leave a valid shaft and invalid feathers. That actual shaft
still returns its original finite components. No magnitude API is added.

Default Rabbita tooltips display X, Y, U and V. Custom callbacks receive the
same immutable metadata as `hit_test` followed by `hit_info`. An independently
constructed Barbs hit without `vector` safely displays only X and Y.
