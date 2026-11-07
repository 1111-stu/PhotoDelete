#!/usr/bin/env python3
"""Validate English source keys, translations and compiler-extracted keys.

python3 scripts/check-localization.py
python3 scripts/check-localization.py --verify-migration --derived-data /path/to/DerivedData
"""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

from localization_tools import (CJK, localization_context, placeholders,
                                scan_literals)

ROOT = Path(__file__).resolve().parents[1]


def signature(text):
    arguments = {}
    for index, match in enumerate(placeholders(text), 1):
        position = int(match[1] or index)
        kind = re.search(r'(lld|llu|ld|lu|@|d|i|u|f|g|s)$', match[2])[0]
        if position in arguments and arguments[position] != kind:
            raise ValueError(f'Argument {position} has inconsistent types: {text}')
        arguments[position] = kind
    return arguments


def units(node):
    if isinstance(node, dict):
        for name, value in node.items():
            if name == 'stringUnit':
                yield value['value']
            else:
                yield from units(value)


def load_json(path):
    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'Duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique_pairs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-migration', action='store_true')
    parser.add_argument('--derived-data', type=Path)
    args = parser.parse_args()
    errors = []
    catalog = load_json(ROOT / 'ios-app/Poca/Localizable.xcstrings')
    strings = catalog['strings']
    if catalog['sourceLanguage'] != 'en':
        errors.append('Localizable sourceLanguage must be en')
    for key, entry in strings.items():
        if CJK.search(key) or re.search('[，。；：！？、（）]', key):
            errors.append(f'Non-English source key: {key}')
        expected = signature(key)
        locales = entry.get('localizations', {})
        if key != 'RTL' and re.search('[A-Za-z]', re.sub(r'%(?:\d+\$)?(?:lld|llu|ld|lu|@|d|i|u|f|g|s)', '', key)):
            for lang in ('en', 'zh-Hans', 'zh-Hant'):
                if lang not in locales:
                    errors.append(f'Missing {lang} translation: {key}')
        for lang, value in locales.items():
            for text in units(value):
                if signature(text) != expected:
                    errors.append(f'Placeholder mismatch ({lang}): {key!r} -> {text!r}')
        en = locales.get('en', {}).get('stringUnit', {}).get('value')
        if en is not None and en != key:
            errors.append(f'English source value differs from key: {key!r} -> {en!r}')

    plist = load_json(ROOT / 'ios-app/Poca/Poca-InfoPlist.xcstrings')
    if plist['sourceLanguage'] != 'en':
        errors.append('InfoPlist sourceLanguage must be en')
    if set(plist['strings']) != {'CFBundleName', 'CFBundleDisplayName', 'NSPhotoLibraryUsageDescription', 'NSPhotoLibraryAddUsageDescription'}:
        errors.append('InfoPlist system keys changed')
    with (ROOT / 'ios-app/Config/Poca-Info.plist').open('rb') as file:
        defaults = plistlib.load(file)
    for key, entry in plist['strings'].items():
        locales = entry.get('localizations', {})
        for lang in ('en', 'zh-Hans', 'zh-Hant'):
            if lang not in locales:
                errors.append(f'Missing InfoPlist {lang} translation: {key}')
        if key.startswith('NSPhotoLibrary'):
            en = locales.get('en', {}).get('stringUnit', {}).get('value')
            if defaults.get(key) != en:
                errors.append(f'Default permission description differs from English: {key}')
    project = (ROOT / 'ios-app/Poca.xcodeproj/project.pbxproj').read_text()
    if 'developmentRegion = en;' not in project and 'developmentRegion = "en";' not in project:
        errors.append('Xcode developmentRegion must be en')

    lookups = 0
    for path in (ROOT / 'ios-app/Poca').rglob('*.swift'):
        text = path.read_text()
        for literal in scan_literals(text):
            context = localization_context(text, literal)
            if path.name == 'Localization.swift' and re.search(r'\bstring\(\s*$', text[:literal.start]):
                context = 'lookup'
            if not context:
                continue
            lookups += 1
            parts = [part for part in literal.parts if isinstance(part, str)]
            label = f'{path.relative_to(ROOT)}:{text.count(chr(10), 0, literal.start) + 1}'
            if any(CJK.search(part) for part in parts):
                errors.append(f'Chinese localization lookup: {label}')
            if context in ('lookup', 'dynamic'):
                found = any(re.fullmatch(literal.pattern(), key) for key in strings) if literal.expressions else ''.join(parts) in strings
                if not found:
                    errors.append(f'Lookup absent from catalog: {label}: {text[literal.start:literal.end]}')

    if args.verify_migration:
        manifest = load_json(ROOT / 'scripts/localization/english-key-migration.json')
        for old, entry in manifest['entries'].items():
            actual = strings.get(entry['newKey'])
            if actual is None:
                errors.append(f'Migrated entry lost: {old}')
                continue
            for lang, expected in entry['translationFingerprints'].items():
                loc = actual.get('localizations', {}).get(lang)
                digest = hashlib.sha256(json.dumps(loc, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
                if digest != expected:
                    errors.append(f'Migrated translation changed ({lang}): {old}')

    extracted = 0
    if args.derived_data:
        build = args.derived_data / 'Build/Intermediates.noindex/Poca.build'
        files = list(build.glob('**/Poca.build/Objects-normal/*/*.stringsdata'))
        if not files:
            errors.append('No app compiler .stringsdata found; run build-for-testing first')
        for path in files:
            data = load_json(path)
            for entry in data.get('tables', {}).get('Localizable', []):
                extracted += 1
                key = entry['key']
                if key not in strings:
                    location = entry.get('location', {})
                    errors.append(f'Compiler key absent from catalog: {data.get("source")}:{location.get("startingLine")}: {key!r}')
                if CJK.search(key):
                    errors.append(f'Compiler extracted Chinese key: {key}')
        products = args.derived_data / 'Build/Products/Debug-iphonesimulator/Poca.app'
        for lang in ('en', 'zh-Hans', 'zh-Hant', 'ar', 'de', 'ja'):
            path = products / f'{lang}.lproj/Localizable.strings'
            if not path.exists():
                errors.append(f'Compiled localization missing: {lang}')
                continue
            compiled = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
            for key, entry in strings.items():
                value = entry.get('localizations', {}).get(lang, {}).get('stringUnit', {}).get('value')
                if value is not None and compiled.get(key) != value:
                    errors.append(f'Compiled translation differs ({lang}): {key}')
            info_path = products / f'{lang}.lproj/InfoPlist.strings'
            if not info_path.exists():
                errors.append(f'Compiled InfoPlist localization missing: {lang}')
                continue
            info = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(info_path)]))
            for key, entry in plist['strings'].items():
                value = entry.get('localizations', {}).get(lang, {}).get('stringUnit', {}).get('value')
                if value is not None and info.get(key) != value:
                    errors.append(f'Compiled InfoPlist translation differs ({lang}): {key}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        print(f'Localization check failed: {len(errors)} errors', file=sys.stderr)
        return 1
    print(f'Localization check passed: {len(strings)} English keys, {lookups} source literals, {extracted} compiler references.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
