#!/usr/bin/env python3
"""One-time English-source migration. Dry-run by default; --apply writes changes.

Run on the Chinese-source catalog to generate the reviewable manifest/report.
The checked-in manifest also records translation fingerprints for later checks.
"""
import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path

from localization_tools import (CJK, FORMAT, interpolated_quote, localization_context,
                                placeholders, remap_format, scan_literals,
                                source_format, swift_quote)

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'ios-app/Poca/Localizable.xcstrings'
DATA = ROOT / 'scripts/localization'
FIXED_COUNTS = {
    '删除 (selectedIDs.count) 项': ('删除 %lld 项', ['selectedIDs.count']),
    '已选 (selectedIDs.count) / (assets.count)': ('已选 %lld / %lld', ['selectedIDs.count', 'assets.count']),
    '本次预计删除 (assets.count) 项': ('本次预计删除 %lld 项', ['assets.count']),
}


def dump(path, value):
    if path.name == 'english-key-migration.json':
        rows = [json.dumps(key, ensure_ascii=False) + ': ' + json.dumps(entry, ensure_ascii=False)
                for key, entry in value['entries'].items()]
        path.write_text('{\n  "version": 1,\n  "sourceLanguage": "en",\n  "entries": {\n    ' + ',\n    '.join(rows) + '\n  }\n}\n')
        return
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2,
                               separators=(',', ' : ') if path.suffix == '.xcstrings' else (',', ': ')) + '\n')


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def translate_units(node, order):
    if isinstance(node, dict):
        for name, value in node.items():
            if name == 'stringUnit':
                value['value'] = remap_format(value['value'], order)
            else:
                translate_units(value, order)


def find_key(literal, strings):
    if not literal.expressions:
        value = ''.join(literal.parts)
        return value if value in strings else None
    matches = [key for key in strings if re.fullmatch(literal.pattern(), key)]
    if len(matches) > 1:
        # These two existing templates share punctuation. Their expression types
        # are explicit here; the build still verifies the compiler's actual key.
        types = ['@' if 'CleanupStatsFormatter.space(' in expr else 'lld'
                 for expr in literal.expressions]
        matches = [key for key in matches if [m[2] for m in placeholders(key)] == types]
        if len(matches) != 1:
            raise ValueError(f'Ambiguous interpolation keys: {matches}')
    return matches[0] if matches else None


def test_key_context(path, text, literal):
    # Keys in the existing cross-language fixture dictionaries are lookup inputs;
    # expected localized outputs and persisted legacy values must remain untouched.
    if path.name != 'PocaTests.swift':
        return False
    begin = text.find('let localizedExpectations:')
    end = text.find('for (language, expectations)', begin)
    return begin <= literal.start < end and bool(re.match(r'\s*:', text[literal.end:]))


def migrate_source(path, strings, entries, text=None):
    text = path.read_text() if text is None else text
    references, unresolved = [], []
    # Outer interpolations can contain additional localization calls. Migrate an
    # outer literal first, then rescan so nested calls retain correct offsets.
    for _ in range(10):
        edits = []
        for literal in scan_literals(text):
            context = localization_context(text, literal)
            if path.name == 'Localization.swift' and re.search(r'\bstring\(\s*$', text[:literal.start]):
                context = 'lookup'
            if not context and not test_key_context(path, text, literal):
                continue
            old = find_key(literal, strings)
            if old is None:
                if context in ('lookup', 'dynamic') and any(CJK.search(p) for p in literal.parts if isinstance(p, str)):
                    unresolved.append({'file': str(path.relative_to(ROOT)), 'line': text.count('\n', 0, literal.start) + 1, 'literal': text[literal.start:literal.end]})
                continue
            entry = entries[old]
            expressions = literal.expressions or FIXED_COUNTS.get(old, ('', []))[1]
            if expressions:
                expressions = [expressions[i - 1] for i in entry['argumentOrder']]
                replacement = interpolated_quote(entry['newKey'], expressions)
            else:
                replacement = swift_quote(entry['newKey'])
            if replacement == text[literal.start:literal.end]:
                continue
            ref = {'oldKey': old, 'file': str(path.relative_to(ROOT)), 'line': text.count('\n', 0, literal.start) + 1, 'kind': context or 'test-fixture'}
            edits.append((literal.start, literal.end, replacement, ref))
        selected, boundary = [], -1
        for edit in sorted(edits):
            if edit[0] >= boundary:
                selected.append(edit)
                boundary = edit[1]
        if not selected:
            break
        for start, end, replacement, ref in reversed(selected):
            references.append(ref)
            text = text[:start] + replacement + text[end:]
    else:
        raise ValueError(f'Nested migration did not converge: {path}')
    return text, references, unresolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--from-ref', help='Regenerate the audit from a Git revision; cannot be combined with --apply')
    args = parser.parse_args()
    if args.from_ref and args.apply:
        parser.error('--from-ref is read-only and cannot be combined with --apply')
    def read(path):
        if args.from_ref:
            return subprocess.check_output(['git', 'show', f'{args.from_ref}:{path.relative_to(ROOT)}'], cwd=ROOT, stderr=subprocess.PIPE).decode()
        return path.read_text()
    catalog = json.loads(read(CATALOG))
    if catalog['sourceLanguage'] != 'zh-Hans':
        parser.error('Migration already applied; run scripts/check-localization.py instead.')
    overrides = json.loads((DATA / 'english-key-overrides.json').read_text())
    strings, migrated, entries = catalog['strings'], {}, {}
    for old, original in strings.items():
        value = copy.deepcopy(original)
        en = overrides['english'].get(old, value.get('localizations', {}).get('en', {}).get('stringUnit', {}).get('value'))
        if en is None:
            if CJK.search(old):
                raise ValueError(f'Missing English: {old}')
            en = old
        new, order = source_format(en)
        if new in migrated:
            raise ValueError(f'English key collision: {old} -> {new}')
        if sorted(order) != list(range(1, len(order) + 1)):
            raise ValueError(f'Unsupported repeated/missing English argument: {old}')
        localizations = value.setdefault('localizations', {})
        if CJK.search(old) or localizations:
            if 'zh-Hans' not in localizations:
                localizations['zh-Hans'] = {'stringUnit': {'state': 'translated', 'value': FIXED_COUNTS.get(old, (old, []))[0]}}
            if old in overrides['zh-Hant']:
                localizations['zh-Hant'] = {'stringUnit': {'state': 'translated', 'value': overrides['zh-Hant'][old]}}
            localizations['en'] = {'stringUnit': {'state': 'translated', 'value': en}}
            translate_units(localizations, order)
            # The English development value is the canonical source template.
            localizations['en']['stringUnit']['value'] = new
            if old == '%@ v%@' and 'zh-Hant' not in localizations:
                localizations['zh-Hant'] = {'stringUnit': {'state': 'translated', 'value': new}}
        elif not localizations:
            value.pop('localizations')
        migrated[new] = value
        if new == 'Favorites':
            value['extractionState'] = 'manual'
        entries[old] = {
            'newKey': new, 'argumentOrder': order,
            'extractionState': original.get('extractionState', 'automatic'),
            'englishOverride': old in overrides['english'],
            'englishWasMissing': 'en' not in original.get('localizations', {}),
            'translationFingerprints': {lang: fingerprint(loc) for lang, loc in localizations.items()},
        }
    changes, references, unresolved = {}, [], []
    for folder in ['ios-app/Poca', 'ios-app/PocaTests']:
        for path in sorted((ROOT / folder).rglob('*.swift')):
            try:
                original_source = read(path)
            except subprocess.CalledProcessError:
                continue  # A new test file did not exist in the original revision.
            updated, refs, unknown = migrate_source(path, strings, entries, original_source)
            if updated != original_source:
                changes[path] = updated
            references.extend(refs)
            unresolved.extend(unknown)
    # Only this format's English changes argument order in the original catalog.
    # Its callers use String(format:) rather than Swift interpolation.
    reordered = 0
    for path, text in list(changes.items()):
        pattern = r'(L10n\.string\("Week %lld of %lld"\),\s*)(Int64\([^\n,]+\)),(\s*)(Int64\([^\n,]+\))'
        text, count = re.subn(pattern, lambda m: m[1] + m[4] + ',' + m[3] + m[2], text)
        changes[path] = text
        reordered += count
    if unresolved:
        dump(DATA / 'unresolved.json', unresolved)
        raise ValueError(f'{len(unresolved)} unresolved localized literals; see scripts/localization/unresolved.json')
    localization = ROOT / 'ios-app/Poca/Services/Localization.swift'
    changes[localization] = changes.get(localization, read(localization)).replace(
        'AppLanguage.current.usesChineseText ? string("Favorite") : "Favorites"', 'string("Favorites")')
    for ref in references:
        entries[ref.pop('oldKey')].setdefault('references', []).append(ref)
    manifest = {'version': 1, 'sourceLanguage': 'en', 'entries': entries}
    dump(DATA / 'english-key-migration.json', manifest)
    summary = {
        'catalogEntriesBefore': len(strings), 'catalogEntriesAfter': len(migrated),
        'chineseKeysBefore': sum(bool(CJK.search(k)) for k in strings),
        'chineseKeysAfter': sum(bool(CJK.search(k)) for k in migrated),
        'swiftFilesChanged': len(changes), 'sourceReferencesChanged': len(references),
        'formatArgumentListsReordered': reordered, 'unresolved': unresolved,
        'staleEntriesRetained': sum(v.get('extractionState') == 'stale' for v in strings.values()),
        'mode': 'applied' if args.apply else 'dry-run',
        'baselineRevision': subprocess.check_output(['git', 'rev-parse', args.from_ref or 'HEAD'], cwd=ROOT).decode().strip(),
    }
    dump(DATA / 'migration-report.json', summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if args.apply:
        for path, text in changes.items():
            path.write_text(text)
        catalog['sourceLanguage'] = 'en'
        catalog['strings'] = dict(sorted(migrated.items()))
        dump(CATALOG, catalog)


if __name__ == '__main__':
    main()
