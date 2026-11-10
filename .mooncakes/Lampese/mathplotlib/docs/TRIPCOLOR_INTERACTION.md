# Triangular face color interaction

`Figure::tripcolor`, `Axes::tripcolor` and their `tripcolor_triangulation`
wrappers keep their existing parameters, Unit return, triangulation, mask,
normalization, colors, automatic legend and static SVG. They do not create
Containers. `to_drawing()` now adds `HitKind::Tripcolor` for each actual painted
nondegenerate triangle.

## Face values and source identity

A target's `HitInfo` carries:

- `value`: the supplied finite face scalar, or the existing ordered vertex
  arithmetic mean `(values[a] + values[b] + values[c]) / 3.0`, before color
  normalization. This value is constant across the face and is not a scalar
  field interpolated at the mouse position.
- `point.point_index`: the original triangle-array slot in the actual validated
  or generated mesh. Masked faces and nonfinite resolved values leave holes;
  visible faces are not renumbered into compact source slots.
- `point.artist_index`: the actual current Polygon artist. Artist indices do
  compact after skipped faces and do not replace source face indices.
- `series`: the immutable label of the call that generated this face.
- `tricolor`: `Some(TriColorInfo)` containing the original ordered
  `vertices : (Int32, Int32, Int32)` and `vertex_mean : Bool`.

The vertex tuple indexes the original x/y coordinate arrays. With direct
`tripcolor` and an empty triangle list, the existing automatic Delaunay mesh
supplies its actual ordered faces. Callbacks can inspect the resolved vertices
without rebuilding a triangulation. `vertex_mean` is true only for the existing
per-vertex scalar branch. The read-only tuple contains no mutable mesh arrays.
The root facade exports `TriColorInfo` and
`tricolor_info(vertices, vertex_mean~=false)` for applications constructing
metadata. `HitInfo.tricolor` defaults to None.

Input length retains the existing precedence: when the values length equals
both face count and vertex count, **per-face values win**. Original finite mean
rounding and overflowing-mean omissions stay unchanged. Autoscaling still sees
all finite values in the complete input array, including masked-face values and
unused vertex values. Changing normalization repaints colors without changing
the original semantic scalar. No safe band-average substitution is applied.

Other metadata (`cell`, `interval`, `fraction`, `band`, `vector`, `error`, etc.)
is absent. These faces have no matrix row/column or contour clipping interval.

## Actual fill and geometry anchors

Each successfully written Polygon supplies one `HitShape::FilledRegion` with
one mapped screen ring and SVG's default nonzero fill rule. Both Nearest and
XNearest require physical fill containment inside the usual plot rectangle.
A large hover radius does not fill a missing face or its empty bounding-box
corners, or snap across the panel. Overlaps and shared edges follow actual
paint order; later painted faces win. A masked face lets earlier interactive
paint receive the pointer.

Visible filled faces remain interactive with their normal stroke width0.
Capture follows actual written fill visibility; an un-emitted line-alpha or
dash setting does not suppress the Polygon. Invalid axis-domain vertices that
prevent a three-point Polygon write, nonfinite mapped geometry, zero screen
area and invisible fill stay static. A separate strict three-point data-space
check keeps originally collinear faces static even if independent screen
rounding would create a tiny sliver. It uses power-of-two scaling rather than
an interaction tolerance; unprovable or nonfinite derived geometry stays static.
Existing Polygon output has no axes clip
resource; margin paint is preserved but remains outside plot interaction.

The anchor coordinates describe generated geometry. The first actual mapped
nonzero edge crossing the plot supplies a safe **data midpoint before clipping**
and a **screen midpoint after clipping**. If no boundary edge crosses but the
triangle covers the plot, one real region containment query proves that cover;
the screen anchor is plot center and data anchor is the first nonzero source
edge midpoint. These two anchors need not map onto each other. They are not a
vertex observation, triangle centroid or pointer-sampled field coordinate.

The opaque FilledRegion factory and `rings()` getter deep-copy both array
levels. Mutating input arrays, inspection copies, getter rings or a later frame
does not change an existing Drawing. Indices identify this frame's geometry and
are not persistent across clear/rebuild.

## Tooltip and application callbacks

The default Rabbita tooltip shows the series and **Value** for a supplied face
scalar, or **Vertex mean** for a computed mean. It does not display geometric
XY. A manually constructed Tripcolor hit without `tricolor` safely displays
Value. Custom tooltips receive the same frame's typed metadata and can display
vertex indices, original face names or application-specific units.

For example, an application callback can read:

```mbt
if info.kind is Tripcolor && info.tricolor is Some(face) {
  let original_face_slot = info.point.point_index
  let (a, b, c) = face.vertices
  let mean_of_vertex_values = face.vertex_mean
  let scalar = info.value
  // Format these immutable values for the application's own tooltip.
}
```

Creating a mesh explicitly uses the existing `@scene.triangulation` constructor
and the `tripcolor_triangulation` wrappers; no new plotting parameter or field
interpolator is required.

## Ownership, lifecycle and limits

Each emitted face stores a constant three-point identity/content snapshot,
source slot/scalar/tuple/mode and immutable call label. The actual original
array is guarded once before the successful-write callback. The renderer uses
its callback's actual retained points, not copied SVG parsing or same-color
matching. Preparation and capture are O(artists + generated faces); each
relevant face containment query is O(3). No whole-mesh copy or scan occurs per
face.

Known ownership that loses array identity, content or artist type stays static.
It cannot revive generic Line/Scatter/mesh targets or borrow ContourF lineage.
Unknown or conflicting prepared metadata also stays static. Images, inline
contour expansion, ordinary Line removal and clear maintain original ownership
alignment; old Drawings remain valid. An empty tripcolor call keeps its legacy
static legend entry without relabeling a preceding plot's interaction series.

This capability covers flat triangular face coloring. It does not add Gouraud
shading, a new interpolation algorithm or values estimated under the pointer.

[Capabilities](CAPABILITIES.md) · [Architecture](ARCHITECTURE.md) ·
[Filled contour interaction](CONTOURF_INTERACTION.md)
