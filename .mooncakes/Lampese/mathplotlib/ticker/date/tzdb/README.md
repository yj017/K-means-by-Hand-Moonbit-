# Bundled IANA timezone names

Import `mathplotlib/mathplotlib/ticker/date/tzdb` explicitly to resolve an IANA
name to the existing `ticker/date.DateTimeZone`:

```moonbit
let zone = @tzdb.timezone("America/New_York")
let formatter = @date.date_formatter("%Y-%m-%d %H:%M %Z").with_timezone(zone)
```

`timezone(name)` raises `DateError` for unknown names. Names are exact and
case-sensitive. `version()` returns `2026e`; `available_timezones()` returns a
fresh array of all 598 names in lexical order. Compatibility names such as
`US/Eastern`, `Asia/Calcutta` and `UTC` are included. `Etc/GMT+5` follows IANA's
POSIX sign convention and is UTC minus five hours.

The returned zone works with DateTime conversion, automatic and explicit date
locators, formatters, RRule/RRuleSet, scene axes, Figure and pyplot. Historical
second offsets and POSIX footer future rules use the same D01 adapter. Aliases
share the same immutable parsed data; public transition arrays are copies.
Parsing happens on first lookup and is cached for each unique TZif.

This is an optional production data package. Base date and plotting packages do
not import it in production. It embeds 345 unique TZif files (206817 bytes),
compiled from IANA **2026e** with pinned `zic -b slim`, preserving the full
64-bit transition block and footer. It needs no runtime filesystem, network,
C library or environment `TZ` setting.

The catalogue covers the standard release sources: africa, antarctica, asia,
australasia, europe, northamerica, southamerica, etcetera, factory and backward.
The optional backzone/packrat historical supplements are not included, matching
the upstream default build. The data records the published release's historical
knowledge and future rules; later policy changes require a data update. The catalogue performs no host-local zone discovery or path loading.
Caller-supplied TZif data can still be loaded with `@date.tzif_timezone`.

The relevant IANA data are public domain; [LICENSE](LICENSE) retains the
upstream notice. [manifest.json](manifest.json) records the archive hashes,
source list, canonical/alias mapping, unique content indices and per-zone
SHA-256 values. All 598 names are checked against independently computed Python
`zoneinfo` offsets at 14 historical/future dates, through year 9999.

To reproduce, download these pinned official archives into a directory:

- [tzdata2026e.tar.gz](https://data.iana.org/time-zones/releases/tzdata2026e.tar.gz)
  SHA-256 `b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652`
- [tzcode2026e.tar.gz](https://data.iana.org/time-zones/releases/tzcode2026e.tar.gz)
  SHA-256 `cc3d27ca2a0d8399504551b920970d80af83bfb9c216e8082a15491921935d54`

From the repository root:

```sh
python3 scripts/generate_tzdb.py /path/to/archive-directory --check
```

Requires Python 3.9+, make, a C compiler and moonfmt only when regenerating.
The script verifies both archives, unpacks them in a temporary directory,
builds its own pinned zic and checks all declared Zone/Link names against the
compiled files. It generates data, index, manifest, license and independent
reference offsets. `--check` leaves the checkout unchanged; omit it to update
generated files. For a new release, update the pinned release and archive
hashes in the generator, regenerate, review the manifest and rerun the four
target checks and tests. Existing binaries retain their embedded data version.

`parser_context(name, clock?)` reuses the same bundled bytes for
`DateStringParser`, without consulting host files. The clock callback returns
signed Unix milliseconds. Base `DateParserContext` also offers explicit TZif,
POSIX and system-context constructors; the optional catalogue stays independent
of host-local discovery. See [parser references](../../../testdata/date_parser_README.md).

`register_timezone(name)` explicitly registers one bundled name for
`@date.get_timezone` and `@config.set_timezone` in hosts without zone files.
This string lookup follows dateutil's first 32-bit TZif block, which can differ
substantially from full IANA rules for slim files. For complete historical and
future rules, continue using `timezone(name)` and pass the resulting object via
`timezone=zone` or `with_timezone(zone)`. Registration does not select rc,
read the clock, lock the date epoch, or import this database into base date.
