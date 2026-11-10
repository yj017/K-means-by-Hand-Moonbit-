# MoonPlot for Rabbita

Interactive MoonPlot SVG components built with public
[Rabbita](https://github.com/moonbit-community/rabbita) APIs. The component returns
real SVG DOM inside composable `Html`; your application owns its state.

The component is the **`Lampese/mathplotlib/rabbita` package** in the unified
`Lampese/mathplotlib@0.18.0` module. See [installation and release status](../docs/PUBLISHING.md)
for the current publication result. There is no separate adapter module to install.

![Two interactive charts](https://raw.githubusercontent.com/moonbit-community/moonplot/master/assets/rabbita-interactive.png)

## Install and import

From your application's module directory:

```sh
moon add Lampese/mathplotlib@0.18.0
```

Import the packages used by your application's view in `moon.pkg`:

```moonbit nocheck
import {
  "Lampese/mathplotlib",
  "Lampese/mathplotlib/drawing",
  "Lampese/mathplotlib/rabbita" @plot_dom,
  "moonbit-community/rabbita",
  "moonbit-community/rabbita/html",
}

supported_targets = "js"
```

Keep the explicit `@plot_dom` alias so it does not conflict with Rabbita's own
`@rabbita` alias. The core facade still uses `@mathplotlib`.
Installing this one module resolves its declared Rabbita dependencies too.
Core plotting, Scene and Drawing do not import UI types; the browser component
and its executables declare `supported_targets = "js"`.

## Hover values and regions (0.3.0)

Line/scatter targets now carry semantic metadata. Bar and horizontal-bar rectangles,
histogram bins and pie sectors also support hover and click selection.
Set `hit_mode=@drawing.HitMode::XNearest` to select actual line samples by horizontal
position inside their panel. The default `Nearest` retains existing point-radius behavior.
Pass `tooltip=info => ...` for custom Rabbita content; `tooltip_visible=false` hides the
floating content while preserving events, and `tooltip_class` adds your styling hook.
`HitInfo` supplies series, category, value, histogram interval and pie fraction.
See the [complete tooltip guide](../docs/TOOLTIPS.md) and the
[six-chart example](https://github.com/moonbit-community/moonplot/blob/v0.3.0/rabbita/cmd/tooltips/main.mbt).

## Matrix cells and more charts (0.4.0)

Nearest scalar `imshow`/`matshow` cells expose `info.cell` (zero-based row,
column and data intervals) and the raw scalar `info.value`. Whole grouped and
stacked bar segments retain series/category/original values, including negative
stacks and horizontal layouts. True donut sectors reuse Pie tooltips and leave
the center hole empty. See the [chart guide](../docs/M3_CHARTS.md) and run
`moon build rabbita/cmd/charts --target js`, then open `/rabbita/charts.html`
from the repository's static server.

## Statistical ranges and distributions (0.5.0)

Error-bar centers, arms and caps expose `info.error`; confidence and stacked-area
interiors expose `info.band`; box bodies, whiskers, caps and outliers expose
`info.box`. These carry original values and computed statistics from the same
SVG draw. Default and custom tooltips share the typed metadata. See the
[statistics guide](../docs/STATISTICS.md); build `rabbita/cmd/statistics --target js`
and open `/rabbita/statistics.html` for five charts and a real error-bar overlay.

## Nonuniform meshes and 2D counts (0.6.0)

Flat 1D-boundary `pcolor` / `pcolormesh` reuse `Heatmap` and `info.cell` for
original scalar values and both boundary intervals. `hist2d` uses `Histogram2D`
with x/y bin intervals and raw counts, including zero-count cells. See the
[mesh guide](../docs/MESH_INTERACTION.md); build `rabbita/cmd/grids --target js`
and open `/rabbita/grids.html` for three independent, responsive charts.

## Hexagonal bins and violin distributions (0.7.0)

`Hexbin` targets cover the real six-vertex faces and retain original centers,
counts and computed reduction values in `HitInfo.hexbin`. `Violin` targets
distinguish KDE samples from mean, median, extrema, range and quantile strokes
through `HitInfo.violin`. KDE samples describe the density estimate rather than
individual observations. Existing custom tooltip callbacks receive both types.

Build `rabbita/cmd/distributions --target js` and open
`/rabbita/distributions.html` for four independent charts. Read the
[hexbin guide](../docs/HEXBIN_INTERACTION.md) for the corrected partition and
changed centers/counts, and the [violin guide](../docs/VIOLIN_INTERACTION.md)
for sample and part identities. Hexbin marginals remain static.

## Step, stairs and cumulative distributions (0.8.0)

`Step` retains original sample indices and values across pre/post/mid alignment;
interior risers belong to the incoming value. `Stairs` retains original values
and directed edge intervals; valid filled polygons provide whole-strip picking
with the original signed baseline/value in `HitInfo.band`. `Ecdf` uses the
actual `Ecdf.values()` / `probabilities()` return slots. Its `fraction` is the
computed after-probability and `band` holds the directed before/after jump,
including decreasing complementary probabilities. Compressed slots are not
unique input observation indices. Default and custom tooltips receive the same
metadata; no synthetic corner is presented as an extra observation.

Build `rabbita/cmd/discrete --target js` and open `/rabbita/discrete.html` for
four independent charts. See the [step](../docs/STEP_INTERACTION.md),
[stairs](../docs/STAIRS_INTERACTION.md) and [ECDF](../docs/ECDF_INTERACTION.md)
guides. Filled stairs with invalid or nonmonotonic polygons remain static;
complete dashed-gap picking is outside this release.

## Stem samples and baselines (0.9.0)

`Stem` targets cover the actual nonzero rod strokes and default circular heads.
Both carry original input indices, head coordinates, head values and labels.
`HitInfo.band` stores `(bottom,head,horizontal,false)`, preserving signed values
and nonzero baselines. Rods and heads retain their own actual artist identities;
the whole baseline remains static. Both hit modes select physical geometry.

Missing samples keep index gaps. A clipped rod retains the original head value;
a log-invalid bottom does not create a rod even when its head is visible. Build
`rabbita/cmd/stems --target js` and open `/rabbita/stems.html` for vertical,
horizontal and confidence-band examples. See the [stem guide](../docs/STEM_INTERACTION.md).

## Quiver vector components (0.10.0)

`Quiver` targets follow each actually written shaft and arrow wing. Each carries
its original input index, tail X/Y, label and immutable `HitInfo.vector.u/v`.
`HitInfo.value` is explicitly the original V component. Default tooltips label
X/Y/U/V; the component does not calculate a vector magnitude.

Both hit modes require physical stroke proximity. Zero vectors keep index gaps,
and clipping retains the original tail and signed components. The arrowhead is
open, with no filled triangle target. Build `rabbita/cmd/vectors --target js` and
open `/rabbita/vectors.html` for separate default/custom tooltips, a real reference
band, independent legends and replacement data. See the
[Quiver guide](../docs/QUIVER_INTERACTION.md) for exact boundaries.

## Component API

Your application must also declare `moonbit-community/rabbita@0.16.7` when importing
Rabbita APIs directly: `moon add moonbit-community/rabbita@0.16.7`. MoonPlot itself
is one module; this is your application’s framework dependency.


Create a drawing snapshot and compose it into the Rabbita view:

```moonbit nocheck
let drawing = figure.to_drawing()
let chart = @plot_dom.view(
  drawing,
  id="measurements",
  on_event=event => emit(Chart(event)),
  hovered?=model.hovered,
  selected?=model.selected,
  legend=[@plot_dom.legend_item("trend", "Trend", "#2563eb", model.show_trend)],
)
```

Handle `Hover(HitPoint?)`, `Click(HitPoint?)` and `ToggleSeries(String)` in your
update function. Prepare a new figure when visibility or data changes.
Create `create_pure_state` / `Val.view` **inside** the builder passed to `rabbita.new`.
The [complete demo](cmd/demo/main.mbt) shows model, update and view together.
Refresh or clear hover/selection when replacing the displayed data.

Load the included stylesheet through your application's asset pipeline:

```html
<link rel="stylesheet" href="/path/to/moonplot.css">
```

Copy or serve [moonplot.css](moonplot.css) from the installed module's `rabbita/`
directory. Its rules are scoped to `.moonplot`. Override `--moonplot-text`,
`--moonplot-muted`, `--moonplot-border` and `--moonplot-accent` on the component.
The floating inspector does not resize the chart on hover. `demo.css` only
styles the repository's example page.

## Run the repository examples

From the full repository root:

```sh
moon build rabbita/cmd/demo --target js
moon build rabbita/cmd/resources --target js
python3 -m http.server 8765 --bind 127.0.0.1
```

Open [the double-chart demo](http://127.0.0.1:8765/rabbita/) or
[the resource isolation case](http://127.0.0.1:8765/rabbita/resources.html).
Serve the repository root so the pages can find the JavaScript in its `_build`
directory. No local `moon.work` is required. Stop the server with Ctrl+C.

## Multi-chart resources and errors

Use a distinct, nonempty `id` per chart. M2 scopes every source SVG ID and its local
`url(...)`, `href` and `xlink:href` references to that chart, including inline CSS,
quoted/escaped URLs, UTF-8 fragment escapes, gradient chains and root references.
The public root remains `id + "-svg"`. Names are deterministic across redraws;
the original Drawing/SVG, geometry and hit coordinates are unchanged.

Duplicate/empty source IDs, missing local targets, ambiguous fragment spellings
and conflicting href/xlink:href values raise `AdapterError::InvalidSvg`.
External/data URLs and ordinary color literals are preserved. Unknown tags or
attributes raise an explicit adapter error. Rabbita 0.16.7 has no public SVG ARIA
setters, so SVG `aria-labelledby` / `aria-describedby` remain unsupported; HTML
legend buttons retain their accessibility attributes.

## Layout and scope

`HitPoint` contains panel, artist and per-chart source indices, numeric data values
and intrinsic SVG coordinates. ECDF indices refer to the returned distribution
slots; other exact identities are described in each chart guide. Picking covers
point anchors, bar and histogram regions, pie/donut sectors, matrix cells, error
and area geometry, boxplot parts, hexagonal faces, violin parts, discrete strokes,
stems, quiver arrows, wind barbs, line contours, filled contour bands and triangular faces. Contour indices identify
generated paths and values identify exact levels; their coordinates describe
generated-edge midpoints. Filled contours expose the finite clip interval,
representative value and original logical band slot. Whole nonzero/evenodd regions
preserve holes and separate islands, and both hit modes require actual fill within
the plot. Lines can also snap by X; segment interpolation is not provided;
indices belong to the current frame, not persistent identities across reordering.

The SVG uses responsive width and `xMidYMid meet`. Picking uses client coordinates,
the actual SVG viewport and letterbox offsets; `hit_radius~` defaults to 10 CSS px.
Scrolling and wrapper padding/borders are supported. Borders/padding or arbitrary
CSS transforms directly on the SVG root, other aspect policies, touch gestures,
zoom/pan and point keyboard navigation are outside M2.

Every `view` parses its snapshot and scans points for picking. Dense-data performance
and caching remain future work. Only JS browser interaction is claimed. The unified
module pins Rabbita 0.16.7 and XML 0.5.0; dependency resolution happens for the whole
module, while the static plotting packages do not compile or link this UI package.

The [wind example](http://127.0.0.1:8765/rabbita/barbs.html) is built with
`moon build rabbita/cmd/barbs --target js`. Its two cards cover real feather
strokes, filled flags and calm disks with the original input position and U/V.
The [Barbs guide](../docs/BARBS_INTERACTION.md) explains pivot, rounding and
physical-only picking in both hit modes.

The [contour example](http://127.0.0.1:8765/rabbita/contours.html) is built with
`moon build rabbita/cmd/contours --target js`. The two cards cover regular and
triangular grids, inline labels, masks, exact levels, independent legends and
replacement data. The [contour guide](../docs/CONTOUR_INTERACTION.md) describes
path slots and the difference between generated data and clipped screen anchors.

The [filled contour example](http://127.0.0.1:8765/rabbita/filled-contours.html)
is built with `moon build rabbita/cmd/filled_contours --target js`. Its two cards
cover nested bands, holes, disconnected islands, masks and replacement data.
The [filled contour guide](../docs/CONTOURF_INTERACTION.md) explains original band
slots, range-only tooltips, immutable region inspection and static margin paint.

The [triangular mesh example](http://127.0.0.1:8765/rabbita/triangles.html)
is built with `moon build rabbita/cmd/triangles --target js`. It exposes original
face slots and values or the existing vertex arithmetic mean, with ordered
`HitInfo.tricolor.vertices` and a `vertex_mean` flag. Both hit modes require the
actual nondegenerate face fill inside the plot; masks leave real gaps. Tooltips
show Value or Vertex mean, with no geometric X/Y rows. See the
[tripcolor guide](../docs/TRIPCOLOR_INTERACTION.md).

The [streamplot example](http://127.0.0.1:8765/rabbita/streamlines.html)
is built with `moon build rabbita/cmd/streamlines --target js`. Continuous body
strokes expose the original seed-attempt slot, generated edge index, sampled
U/V and optional raw color value through `HitInfo.streamplot`. Both hit modes
require physical stroke proximity. Default rows show U/V and optional Color
value; custom content can add units and local labels. Arrow components retain
static paint in this slice. See the [streamplot guide](../docs/STREAMPLOT_INTERACTION.md).

The [polar and radar example](http://127.0.0.1:8765/rabbita/polar.html)
is built with `moon build rabbita/cmd/polar --target js`. Two composable SVG
views show rose sectors with scatter points and clockwise bars with a radar profile.
The application updates data, toggles series, chooses direction, and remounts
the charts. Circular data clipping keeps the physical disk round in rectangular
panels. Polar tooltips expose original radians and radius plus per-call radar
categories. Both modes pick filled bars across their real sector areas; line and
marker observations use physical point proximity within the actual disk.
Hover and selection highlights share its circular clip. Default and custom
content support units and local labels. See the [polar guide](../docs/POLAR.md).

## Develop and verify

From a full repository checkout:

```sh
moon check rabbita --target js
moon test rabbita --target js
moon build rabbita/cmd/demo rabbita/cmd/resources --target js
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node rabbita/browser_test.cjs
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node rabbita/resource_browser_test.cjs
```

The browser runners require Playwright and installed Google Chrome.
`BROWSER_CHANNEL=bundled` selects Playwright's installed Chromium instead.
They use ephemeral loopback servers and close browser/server in `finally`.
The [M2 record](../docs/MILESTONE_M2.md) preserves v0.2.0's 14 unit tests, 11 main
browser checks, 7 resource groups and independent release-consumer acceptance;
those historical results are separate from the unified package's publication checks.

The earlier `moonbit-community/moonplot-rabbita` module path is replaced by
`Lampese/mathplotlib/rabbita`. See [migration notes](../docs/PUBLISHING.md#从早期模块路径迁移)
for the static package prefix change too.

Licensed under [Apache 2.0](../LICENSE). See the module's
[third-party notices](../docs/THIRD_PARTY_NOTICES.md) for dependencies and bundled data.
