# English source localization

`Localizable.xcstrings` uses English source copy as its key, with `en` as the
source language and Xcode development region. Keep UI lookups behind `L10n`.
For example: `L10n.string("Keep First")` or `L10n.string("\(count) photos")`.
Add Simplified Chinese, Traditional Chinese and English translations when adding
UI copy. Preserve placeholder types; positional placeholders belong in
translations when their argument order differs from English.

Run from the repository root:

```sh
python3 scripts/check-localization.py
python3 -m unittest discover -s scripts/tests -v
# After build-for-testing:
python3 scripts/check-localization.py --derived-data ios-app/DerivedData
```

The source check rejects duplicate keys, Chinese source keys, missing lookup
entries and mismatched placeholders. The build check compares the compiler's
actual extracted keys and all six compiled language tables with the catalog.
CI runs both. The scanner supports ordinary Swift literals and rejects raw or
multiline syntax until explicitly supported. Compiler validation currently
targets Debug simulator output and plain string units; extend it before adding
plural variations.

`english-key-overrides.json` records reviewed English copy for missing translations
and collisions. `english-key-migration.json` maps all 1,350 original entries to
unique English keys and records references and translation fingerprints.
`migration-report.json` summarizes the migration audit. All 494 stale entries
were retained. Chinese persisted business identifiers, native language names,
album names and brand constants remain unchanged.

The one-time migrator defaults to dry-run. On the original Chinese-source tree,
`python3 scripts/migrate-localization-keys.py --apply` performs the migration.
After migration, regenerate the audit from its original Git revision with
`--from-ref <baselineRevision>` (see the report). This rewrites audit JSON only;
it cannot be combined with `--apply`. Additional runtime cleanup removed
redundant `.appLocalized` lookups, localized the Favorites category consistently,
and updated test assertions that compare source keys.

`python3 scripts/check-localization.py --verify-migration` checks translation
fingerprints against the migration baseline. Use it to review this migration;
it is deliberately excluded from ongoing CI so intentional translation edits
remain possible. When English copy changes later, rename its key and call sites
together and retain the other language translations.
