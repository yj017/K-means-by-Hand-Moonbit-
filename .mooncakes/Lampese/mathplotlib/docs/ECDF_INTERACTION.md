# ECDF interaction

`Figure::ecdf` and `Axes::ecdf` keep their existing parameters, calculation
order and SVG output. Visible solid ECDF strokes expose `HitKind::Ecdf` in
both vertical and horizontal orientations.

`point.point_index` is an index in the returned `Ecdf.values()` and
`Ecdf.probabilities()` arrays. It is not an original observation index: sorting
changes order, and `compress=true` groups equal observations. `HitInfo.value`
is the exact returned value, and `fraction` is its exact returned cumulative
probability. Complementary ECDF returns the complementary probability.

The source data coordinate is `(value, probability)`, with x/y exchanged for
horizontal ECDF. `interval` contains the outgoing plateau's returned values
`(values[i], values[i+1])`; the final slot has `None`. The inside of each jump
belongs to its incoming returned slot. `band` records the actual probability
before and after that jump, with its horizontal flag. Complementary bands
retain decreasing bounds rather than sorting them.

Exact source endpoints preserve their returned slot. Coincident endpoints,
including duplicate observations with zero weight, use a fixed later source
tie; a single screen position cannot distinguish every coincident slot.
Zero-length edges do not create stroke targets. A zero-weight endpoint can
still be selected when it lies on an actual connected visible stroke. A
wholly zero-length run has no visible target. Synthetic corners do not become
new observations or returned slots.

Capture uses the same finite runs written to SVG, respects panel clipping,
axis reversal and actual scale validity, and does not invent infinite CDF
tails. Both hit modes select the physical stroke; ECDF does not add Step's
horizontal nearest-source fallback. Input arrays and public result getters
are copied. Changed actual paths conservatively lose their ECDF semantics.
Known transparent paint produces no semantic targets.

Nonfinite probabilities caused by the existing accumulation behavior retain
their existing static behavior and are excluded from invalid semantic hits;
interaction does not recalculate, clamp or reorder the ECDF. Default Rabbita
tooltips display Value and Probability. Custom callbacks receive these same
scalar fields and the original before/after probability band.
