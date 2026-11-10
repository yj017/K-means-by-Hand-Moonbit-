# Polar plots, rose plots and outline radar charts

`Figure::add_polar_axes(left, bottom, width, height)` creates a typed
`PolarAxes` at a normalized Figure rectangle, using the same lower-left layout
coordinates as `add_axes`. Polar and ordinary panels can share a Figure.
Polar panels produce SVG and composable Rabbita DOM, with hover and click
metadata for eligible original samples and filled bar areas.

```mbt
let figure = @plot.figure(width=460, height=300)
let polar = figure.add_polar_axes(0.0, 0.0, 1.0, 1.0)
polar.set_radius_max(1.0)
polar.plot([0.0, 1.0, 2.0, 3.0], [0.3, 0.8, 0.6, 1.0], label="Profile")
polar.scatter([0.0, 1.0, 2.0], [0.3, 0.8, 0.6], size=4.0)
let drawing = figure.to_drawing()
```

## Coordinates and appearance

Angles are radians. Zero points east, with increasing angles counterclockwise.
`set_theta_offset(radians)` moves zero; `set_direction(PolarDirection::Clockwise)`
reverses the angular direction. The offset and raw angles remain in radians
even when custom labels display degrees or category names. Huge finite angles
are reduced only while evaluating trigonometry; stored source values stay intact.

The radial domain is linear `[0, rmax]`. Its automatic maximum uses jointly
valid finite angle/radius pairs with nonnegative radius. Empty and all-zero data
use maximum1. `set_radius_max(value)` requires a finite positive value and
changes the view without rewriting observations. The circle uses one physical
radius in a rectangular panel; labels and a title receive layout allowance,
and unused space keeps the circle round.

`plot(theta, radius, color~="", linewidth~=1.5, label~="", closed~=false)`
draws straight chords between the projected samples. It does not insert an
arc or an interpolated observation. Provide enough samples for a smooth spiral.
`scatter(theta, radius, color~="", size~=3.5, label~="")` draws circular markers;
**size is SVG pixel radius**, rather than marker area. Colors use the existing
color cycle and labels use the existing automatic legend.

The two coordinate arrays must have equal length. Negative radius and
nonfinite angle/radius pairs are missing: lines break into separate runs and
scatter skips them. Radius zero is valid. Radii above an explicit maximum stay
in the raw source; a real SVG circle clips their painted strokes and markers.
An unrepresentable derived projection conservatively breaks the run instead of
writing nonfinite SVG coordinates.

For `closed=true`, only the rendered path gains a final copy of its first point,
and only when the complete original group projects validly. Missing values do
not get bridged to close a shape. Inspection still returns the original N points.

## Polar bars and rose plots

`bar(theta, radius, width~, color~="", label~="")` draws filled sectors from
radius zero, centered on each original angle. **width is a required scalar in
radians**, shared by that call, and must be finite with `0 < width <= 2π`.
Array lengths and width are checked before adding an artist or consuming a color.
Each call retains one ordinary `Bar` artist with the original N theta/r pairs;
it does not create a Container or turn bars into Line samples.

```mbt
polar.set_radius_max(1.0)
polar.bar([0.0, 1.0, 2.0, 3.0], [0.6, 0.9, 0.4, 1.2],
  width=0.5, color="#398575", label="Rose")
```

The width is centered after reducing the angle and applying the panel's offset
and direction. Changing to clockwise rotates the centers consistently while
preserving the same positive angular span. Every bar uses one call color and
has fill only. Missing/nonfinite angles or radii, negative radii and radius zero
produce no filled area, without compacting the original source indices.

Bars share the automatic radial maximum with lines and markers. With an explicit
maximum, a larger raw radius fills up to that maximum and keeps its original value
for inspection and interaction; clipping occurs before the radial ratio so a huge
finite raw radius cannot overflow the SVG geometry. Width exactly `2π` produces
a real full circle. Smaller widths remain sector paths, including near-full
widths; a collapsed unrepresentable arc is omitted rather than given a fake hit.

`HitKind::PolarBar` identifies the actual filled sector. Its `point.data_x` is
the original angle, `point.data_y` and `value` are the original radius, and its
panel/artist/point indices and `series` identify the original call and slot.
There is no category, fraction, interval or interpolated radius. The target's
`Sector(cx,cy,radius,start,sweep)` uses intrinsic SVG geometry with degrees and
a positive counterclockwise sweep. The default tooltip shows **Theta (rad)**
and **Radius**; its DOM kind token is `polar-bar`.

Both hit modes select the actual filled area, with included edges and the same
per-panel circle admission as polar points. The caller's hover radius does not
pad the face, bridge a sector gap or expand the circle. A later polar point above
a bar can win only within its actual physical hover radius; a bar painted later
covers the earlier point. Empty corners of a sector's bounding box stay empty.
A whole-circle bar makes its real disk selectable; this does not add whole-disk
selection to ordinary polar line or marker plots.

## Grid labels and radar

`set_theta_ticks(angles, labels~=[])` and
`set_radius_ticks(radii, labels~=[])` copy their inputs. Positions must be finite;
radial ticks must also be nonnegative. A nonempty label list must have the same
length. Validation errors leave existing configuration intact. Radial positions
outside the current maximum are omitted without changing the range. Zero has no
separate ring. The initial angular grid has eight degree labels; custom angular
positions without labels display their numeric radian values.

`radar(values, labels, color~="", linewidth~=1.5, label~="")` requires at least
three categories and one label per value. It uses equally spaced angles and the
same closed chord outline. Subsequent radar calls on one panel require the same
ordered category labels. This helper does not rotate the panel, fill the shape
or normalize each dimension.

```mbt
polar.set_theta_offset(1.5707963267948966) // north zero
polar.set_direction(@plot.PolarDirection::Clockwise)
polar.set_radius_max(100.0)
polar.radar([80.0, 60.0, 90.0, 70.0, 50.0],
  ["Strength", "Speed", "Recovery", "Endurance", "Defense"], label="First")
polar.radar([60.0, 85.0, 65.0, 95.0, 75.0],
  ["Strength", "Speed", "Recovery", "Endurance", "Defense"], label="Second")
```

`set_title`, `set_legend`/`legend`, `legend_entries` and
`set_legend_position` forward the small existing presentation API. `legend([])`
sets an explicitly empty in-SVG legend when an application supplies its own DOM
controls. Data is clipped independently of the grid, labels, title and legend.

## Original sample interaction

For line, scatter and radar calls, `to_drawing()` captures `HitKind::Polar`
point targets. `HitInfo.point.data_x`
is the original angle in radians, `point.data_y` and `value` are the original
radius, and the panel, artist and point indices identify the original source
slot. They never describe projected Cartesian coordinates or a value inferred
from the mouse position. The series name is retained from the plotting call.
For radar, `category` is the original category for that call and source slot;
changing ticks or legend presentation does not relabel earlier observations.
The default Rabbita tooltip shows **Theta (rad)**, **Radius** and, when present,
**Category**. A custom formatter receives the same immutable metadata.

Both `Nearest` and `XNearest` use physical point distance for polar targets.
There is no chord interpolation, screen-X fallback or angle snapping. A sample
must be an endpoint of an actual nonzero painted chord or a visible positive-size
marker. Singleton and entirely coincident lines, zero-width/invisible strokes,
zero-size markers and missing samples do not create targets. A closing chord
can qualify the original first point, while the appended closing vertex never
creates another identity. Coincident eligible points retain the existing stable
point tie order; each remains in the frame's target list.

The original radius must be within `[0, rmax]` and its projected center must be
inside the same circular data clip. Radius zero retains its original angle.
An outside-center marker or chord may be partly visible after clipping without
creating a new observation inside the circle. Source indices retain holes.
`Drawing::polar_circle(panel_index)` returns a copied scalar `(cx, cy, radius)`
for that frame, or `None` when absent or invalid. Each candidate is admitted by
its own panel's circle, so a circle corner cannot select polar data even with a
large hover radius, and it does not block a different polar or ordinary panel.
A small binary64 projection-roundoff allowance preserves exact boundary anchors;
it is independent of the caller's hover radius and CSS scale.

`hit_test_client` uses CSS-pixel radius with the documented uniform meet mapping;
its rectangle is the actual SVG content viewport. `hit_test` uses intrinsic SVG
coordinates. The raw angle, radius and category remain unchanged in either path.
The drawing factory's optional `polar_circles` records are copied into the frame;
invalid or conflicting records fail closed for their panel. A manually constructed
Polar or PolarBar target without a valid circle also fails closed. Existing drawings without
circle records preserve their ordinary point behavior.

## Lifecycle and scope

Input arrays, tick settings and labels are copied. Ordinary artist inspection
through `figure.axes_list()[index].artists()` returns independent copies with
raw theta/r points. Projection happens at render time, so changing the radial
maximum or direction affects every series consistently. A previously built
Drawing retains its immutable SVG, circle and sample metadata. Source snapshots
and per-artist validation, projection and capture take O(samples + series), with
grid work O(ticks); outline closure never grows the original source. The same-draw
writer callbacks establish eligibility without repeated source copies per point.
Unproven or invalidated source identity/content stays static. Bar angular width
is retained independently of that guard, so changing a typed Bar's points can
still paint at its configured width without exposing stale metadata. A hand-built
Bar without typed angular configuration is rejected in checked polar rendering;
replacing a typed bar with a Line or Scatter cannot acquire bar metadata.

`PolarAxes::clear()` removes series, title and legend while keeping the polar
projection and its range/direction/tick configuration. Public `Figure::clear()`
and `clear_checked()` also preserve the panel's polar identity. A later radar
group can establish its category list again.

Inherited Cartesian operations reachable through ordinary Figure/Axis handles
are not a polar configuration API. Cartesian scales, bounds, limits, tick
formatters/locators, axis-off, custom Cartesian grid/spine/margin/anchor settings,
sharing, aspect adjustments, secondary axes and foreign artists fail clearly in
checked rendering. There is no raw Axes or
mutable Line2D conversion method on `PolarAxes`.

This slice covers a full circle with radial minimum zero. It does not add
logarithmic or reversed radii, nonzero inner radii, angular wedges, filled radar,
arbitrary artist projection, interpolated polar observations, stacked bars,
nonzero bar bottoms, per-bar widths/colors or automatic angular binning. `to_drawing()` and ordinary SVG share the exact draw, while polar
targets retain their original polar semantics. Ordinary panels keep their
existing interaction.

[Capabilities](CAPABILITIES.md) · [Architecture](ARCHITECTURE.md) ·
[Rabbita DOM](RABBITA_DOM.md)
