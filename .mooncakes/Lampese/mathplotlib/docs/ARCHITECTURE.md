# Source organization

The root package is a small public facade in [`api.mbt`](../api.mbt).
Applications import `Lampese/mathplotlib`; the plotting methods and default
`@mathplotlib` alias remain unchanged. The 0.2.1 distribution combines static
plotting and the browser component in one module; see [installation and path migration](PUBLISHING.md).

This follows the [pdf-viewer package organization](https://github.com/moonbit-community/pdf-viewer/blob/master/docs/architecture.md):
a small root facade, consumer tests in `tests/api`, generated resources with
clear owners, and implementation files split by responsibility within packages.
MoonPlot retains its existing focused packages rather than placing the entire
plotting library in one engine package.

## Package map

| Location | Responsibility |
| --- | --- |
| [`api.mbt`](../api.mbt) | Public type/function re-exports and `plot_svg` convenience function |
| [`core/`](../core) | Points, bounds, typed errors, styles, masked data, and color values |
| [`scene/`](../scene) | Figures, Axes, artists, layout state, and checked drawing preparation |
| [`drawing/`](../drawing) | Immutable SVG snapshots, semantic metadata, point/rectangle/sector hit testing |
| [`backend/svg/`](../backend/svg) | SVG layout, geometry, and serialization |
| [`ticker/`](../ticker) | Numeric/date locators, formatters, categories, and scales |
| [`transforms/`](../transforms) | Affine transforms, bounds, paths, and geometry |
| [`pyplot/`](../pyplot) | Stateful convenience facade over Scene |
| [`internal/`](../internal) | Shared render IR, host bridges, PNG helpers, generated color resources |
| [`rabbita/`](../rabbita/README.md) | JS-only interactive DOM package in the same module |
| [`cmd/`](../cmd) | Runnable static plotting examples |
| [`tests/api/`](../tests/api) | Consumer tests importing only the public root facade |
| [`tests/integration/`](../tests/integration) | Independent packages isolating process-global epoch/configuration tests |
| [`scripts/`](../scripts) | Fixed-upstream reference collection and resource generators |
| [`tools/`](../tools) | Repository maintenance checks |
| [`testdata/`](../testdata) | Independent oracle data, provenance, regeneration notes, and packed test fixtures |
| [`assets/`](../assets) | Checked-in sample output and actual UI screenshots |

`rabbita/moon.pkg` and its browser executables declare `supported_targets = "js"`.
The core facade, Scene, Drawing and static renderer do not import UI packages.
Dependency declarations belong to the module, so installing it also resolves
Rabbita and its transitive dependencies; package-level compilation preserves
the static backend boundary. There is no nested adapter module or adapter
`moon.work` in the current layout.

Blackbox and whitebox tests for an implementation package stay beside it when
they exercise that package's contracts or private helpers. Moving whitebox
tests into unrelated packages would require exposing private implementation.
The root's consumer tests do not need that access and have their own package.

## Files inside the main packages

`backend/svg/render.mbt` now contains the top-level rendering entry points.
`panel_layout.mbt` computes panel rectangles, and `panel.mbt` dispatches their
artists. `coordinates.mbt`, `line.mbt`, `markers.mbt`, `bar.mbt`, `polygon.mbt`,
`reference.mbt`, `grid.mbt`, `secondary_axis.mbt`, and `spines.mbt` own their
respective geometry. Annotation, table, legend, colorbar, pie, statistics, and
quiver serialization each have a named file. Existing image and tick-layout
files retain their responsibilities.

`pyplot/state.mbt` holds the current Figure/Axes lifecycle. Plotting methods,
statistics, vector plots, pcolor, streamplot, contour, triangulation, images,
tables, annotations, axis controls, and output live in their corresponding
files. `scene/figure.mbt` holds the Figure API; `artist_model.mbt`,
`axes_state.mbt`, `axes.mbt`, and `color_cycle.mbt` separate shared model values,
Axes lifecycle/settings, and color-cycle state.

These splits move complete `///|` blocks within the same compilation unit.
They do not add public helper functions or introduce another layout algorithm.

Barbs metadata has separate owners: `scene/barbs_hit.mbt` records immutable input
positions, vectors and the call label; `internal/render/barb_hit.mbt` shares that
table through constant-size component views; `backend/svg/barb_hit.mbt` captures
actual line runs, triangular flag paint and filled calm circles. Geometry stays
in the existing writers. Each component checks only its own points, so metadata
storage and validation remain O(N+P) for N inputs and P expanded components.

Line-contour lineage is owned by `scene/contour_hit.mbt` and
`internal/render/contour_hit.mbt`. Each generated path shares its call label,
exact level and original path slot; inline fragments retain their own lineage.
`backend/svg/contour_hit.mbt` captures the actual writer's finite line runs and
clips only the visible anchor. Fragment snapshots are checked once, edge capture
is constant work, and a linear preparation cursor preserves other artist
ownership after inline expansion. No grid is copied per fragment or edge.

Filled-contour metadata lives in `scene/contourf_hit.mbt` and
`internal/render/contourf_hit.mbt`. Each band keeps its original logical slot,
finite clip interval, representative value and immutable geometry snapshot.
`backend/svg/contourf_hit.mbt` receives the actual successful polygon/path writer
output once per band. `drawing/region.mbt` owns the opaque whole-region
value, cached validity and physical nonzero/evenodd containment. Separate rings
share one region; no grid or entire region is copied for each captured edge.

Tripcolor keeps a separate original face slot, raw scalar and ordered vertex
triple in `scene/tricolor_hit.mbt` / `internal/render/tricolor_hit.mbt`.
Each face validates only its own three-point identity, content and source area
once. `backend/svg/tricolor_hit.mbt` and the contourf collector share the small
`filled_region_hit.mbt` helper for actual writer geometry, clipping and anchors;
scalar semantics and source ownership remain separate. `drawing/tricolor.mbt`
provides readonly metadata. No full mesh is copied or searched per face.

Polar plots have a typed Scene owner in `scene/polar.mbt`, a copied readonly
configuration in `internal/render/polar.mbt`, and a dedicated SVG path in
`backend/svg/polar.mbt`. Original theta/radius pairs remain ordinary Line/Scatter/Bar
data; projection and an optional closing vertex are produced only for painting.
`backend/svg/polar_bar.mbt` writes centered filled sectors or complete circles
and captures that same area. Per-call scalar width stays available for static
paint even when capture provenance is invalid; source kinds prevent bar metadata
from being reused for a different primitive. `drawing/polar_bar.mbt` contains
only the new kind’s bounded arithmetic admission, leaving legacy Pie unchanged.
The polar branch bypasses Cartesian range/tick/aspect preparation and emits a
data-only circular clip. `internal/render/polar_hit.mbt` retains one original
call snapshot and checks identity/content once per artist. Actual writer
callbacks in `backend/svg/polar_hit.mbt` capture eligible original observations;
closing paint never creates a new source identity. `drawing/polar.mbt` owns the
copied panel-circle table and candidate-local admission. The private Rabbita
`svg_coordinates.mbt` bridge maps the actual SVG CTM once per event; polar
highlight clips use the same immutable frame circle. Ordinary mixed panels
retain their existing semantics.

## Generated data and reference tests

`internal/color_names` owns the complete pinned named-color table. Its three
generated files separate standard colors, XKCD colors, and grey/gray aliases.
Each entry retains exact IEEE-754 channel bits; a small private loader creates
the lookup map. Scene keeps the existing color parsing and lazy validation
behavior and delegates only exact named lookup.

The largest Logit sort references use small data-driven test harnesses and
losslessly packed fixtures under `testdata/packed`. They retain every original
case, scalar origin, input bit, expected output bit, and complete permutation.
Fixtures are derived from the checked-in independent oracle JSON, not from the
sorting implementation. Moon's embed step emits ignored, test-only loaders.
Production executables do not link these resources; source distribution keeps
the packed inputs required by the package's pre-build hooks.
See the [packed fixture guide](../testdata/packed/README.md) for the format and
saved-oracle verification commands.

Other generated numerical references still have large case files. Their
`*_reference_test.mbt` / `*_reference_wbtest.mbt` names and provenance separate
them from maintained implementation. They are not removed or mechanically
sharded to lower a line count. New large reference suites should use the packed
fixture pattern rather than duplicate large arrays as source code.

## Maintenance checks

```sh
python3 tools/check_structure.py
moon check --target all
moon test tests/api tests/integration/* --target all
moon info
moon fmt
```

The structure check limits maintained files to 2,000 lines and keeps root files
restricted to the facade, manifests, generated interface, and project metadata.
It reports generated references separately using their headers and naming
convention. `--json` prints the complete source inventory for deeper review.
Review generated `.mbti` changes after a move: file splits should preserve
public interfaces; moved isolated test package names and new internal packages
are expected exceptions.

Build output, dependency caches, generated fixture loaders, and agent working
state are ignored by Git. They are not source files to edit or move into a
product package. Reference reproduction still uses `scripts/` and `testdata/`
so existing pinned source checks and relative imports remain intact.

## Organization verification, 2026-10-24

| Item | Before | After |
| --- | --- | --- |
| Tracked root files | 23 | 10 |
| SVG main rendering file | 4,158 lines | 136 lines, with named geometry/layout files |
| pyplot state file | 2,353 lines | 157 lines, with named feature files |
| Scene figure file | 1,588 lines | 534 lines, with separate model/Axes files |
| Generated Scene color match | 6,559 lines | 6-line bridge to complete internal resource tables |
| Two largest generated sort tests | 23,473,639 bytes | 4,172 bytes of harnesses plus a small shared decoder |
| Complete packed sort resources | Duplicated as test source | 1,993,905 bytes of derived data; original JSON retained |

All 332 moved production blocks are byte-preserved apart from blank separators.
The 22,172 explicitly named source tests retain the same names and multiplicity;
that count is separate from runtime test totals, which also include other test
forms and target-specific cases. No existing public interface changed.

The final complete suite passed **22,264/22,264** on wasm, wasm-gc, and native,
and **22,271/22,271** on JS. `moon info`, `moon fmt`, and four-target check passed
with seven existing Ref deprecation warnings and no new errors. The public
consumer and isolated configuration test sets each passed 18/18 per target.
All three native plotting examples ran successfully; the preview and gallery
SVGs are byte-identical to their saved assets. The optional adapter passed 7/7
tests and 11 real-browser interaction/layout checks with no page errors. Its
UI screenshot is also byte-identical. The production JS bundle was checked to
exclude test fixture names, format magic, and encoded payload prefixes.
Detailed local evidence is in `.moonagent/checkpoints/repository-organization/`;
these ignored logs are not required to reproduce the public commands above.

### JS-only generated interfaces

The module's canonical backend is Wasm. On the current toolchain, `moon info --target js`
reports backend differences without replacing JS-only canonical interface files.
Run `python3 tools/update_interfaces.py` to run `moon info --target all`, retain the exact
compiler-generated JS interfaces for `rabbita/` and its executables, and run `moon fmt`.
Review generated diffs as usual; do not manually edit `.mbti` signatures.
