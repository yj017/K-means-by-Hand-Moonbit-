# Packed numerical reference fixtures

These files are derived test resources, not plotting runtime data.
The authoritative, independent upstream observations remain in
[`logit_object_sort_reference.json`](../logit_object_sort_reference.json) and
[`logit_sort_reference.json`](../logit_sort_reference.json).
Their source provenance and supported behavior are described in
[`logit_formatter_README.md`](../logit_formatter_README.md).

| Resource | Original cases | Registered test groups |
| --- | --- | --- |
| `logit_object_sort.base64` | 220 NumPy object quicksort/heapsort cases | 7 |
| `logit_sort.base64` | 248 CPython tuple-key sorting cases | 8 |

Every scalar origin, floating-point bit, integer/boolean value, error string,
input element, and complete expected permutation is retained. Large cases are
not reduced to prefixes or expected values reconstructed by the sorting code.
The JSON remains unchanged by packing.

## Rebuild or verify

The saved-oracle path needs Python's standard library and `moonfmt`:

```sh
python3 scripts/generate_logit_object_sort_reference.py --from-fixture --check
python3 scripts/generate_logit_sort_reference.py --from-fixture --check
```

Omit `--check` to rebuild the derived resources and small test harnesses.
Without `--from-fixture`, the original generators still execute their pinned
upstream oracles and retain their documented Python/NumPy/source requirements.

The shared [`scripts/logit_sort_fixture.py`](../../scripts/logit_sort_fixture.py)
packs the saved observations, independently decodes each record, and compares
every value to the JSON before writing an output. It never sorts data or calls
the MoonBit implementation to obtain expected values.

## Storage and loading

The resources are 96-column base64 text encoding a small binary format. Moon's
built-in `:embed --text` step emits ignored `*_fixture.generated_wbtest.mbt`
loaders in `ticker/`. The whitebox tests decode base64 once. The suffix and
test-only base64 import keep these resources out of production bundles.
No runtime file API is required on Wasm, JS, or native targets.

The decoded stream has an eight-byte format magic (`MPLTOB01` / `MPLTUP01`),
a little-endian UInt32 case count, a case-offset table, and records retaining
their original IDs. Words are exact UInt64 payloads. Vector encoding chooses
literal words, constant-difference runs modulo 2^64, or exact repeated blocks;
the choice is lossless and independent of sorting behavior. Mixed scalar
arrays retain tags for Number, NumpyFloat64, Integer, NumpyInt64, Boolean, and
NumpyBool. Integer/error strings use length-prefixed ASCII.

The MoonBit decoder checks magic, counts, IDs, individual record bounds, and
complete vector/record consumption. Generated payloads are trusted test inputs;
this format is not exposed as an application data parser.

The relevant existing tests run with:

```sh
moon test ticker/logit_object_sort_reference_wbtest.mbt \
  ticker/logit_sort_reference_wbtest.mbt --target all
```
