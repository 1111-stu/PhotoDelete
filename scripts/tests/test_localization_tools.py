"""Regression checks for the localization migration's parsing boundaries."""
import importlib.util
from pathlib import Path
import re
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS))

from localization_tools import (interpolated_quote, localization_context,
                                placeholders, remap_format, scan_literals,
                                source_format, swift_quote)

spec = importlib.util.spec_from_file_location(
    "check_localization", SCRIPTS / "check-localization.py"
)
check_localization = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_localization)


class SwiftScannerTests(unittest.TestCase):
    def test_comments_are_not_treated_as_source_strings(self):
        source = '''
// L10n.string("Not a key")
/* "Also not a key" /* nested "comment" */ */
L10n.string("Actual key") // "Another comment"
'''
        literals = scan_literals(source)
        self.assertEqual([literal.parts for literal in literals], [["Actual key"]])
        self.assertEqual(localization_context(source, literals[0]), "lookup")

    def test_quotes_backslashes_and_unicode_are_decoded(self):
        source = r'L10n.string("Quote \" and slash \\ and \u{4E2D}\nline")'
        literal = scan_literals(source)[0]
        expected = 'Quote " and slash \\ and 中\nline'
        self.assertEqual(literal.parts, [expected])
        self.assertEqual(scan_literals(swift_quote(expected))[0].parts, [expected])

    def test_nested_interpolation_preserves_expression_and_offsets(self):
        source = r'L10n.string("Result \(format("value \(count)", suffix: ")")) end")'
        literals = scan_literals(source)
        self.assertEqual(len(literals), 3)
        self.assertEqual(
            literals[0].expressions,
            [r'format("value \(count)", suffix: ")")'],
        )
        self.assertEqual(literals[1].parts, ["value ", ("count",), ""])
        self.assertEqual(literals[2].parts, [")"])
        self.assertEqual(
            source[literals[1].start:literals[1].end], r'"value \(count)"'
        )
        self.assertEqual(source[literals[2].start:literals[2].end], '")"')

    def test_percent_in_interpolation_matches_escaped_catalog_percent(self):
        literal = scan_literals(r'"\(count)% reviewed"')[0]
        self.assertIsNotNone(re.fullmatch(literal.pattern(), "%lld%% reviewed"))
        self.assertIsNone(re.fullmatch(literal.pattern(), "%lld% reviewed"))
        ordinary = scan_literals('"100% free"')[0]
        self.assertIsNotNone(re.fullmatch(ordinary.pattern(), "100% free"))

    def test_unsupported_literals_fail_explicitly(self):
        for source in ['#"raw"#', '"""multiline"""']:
            with self.subTest(source=source):
                with self.assertRaisesRegex(ValueError, "Raw/multiline"):
                    scan_literals(source)


class FormatMigrationTests(unittest.TestCase):
    def test_literal_percent_is_not_counted_as_an_argument(self):
        value = "%%1$lld · %2$lld%% · %@ · %%%lld"
        self.assertEqual(
            [match.group() for match in placeholders(value)],
            ["%2$lld", "%@", "%lld"],
        )

    def test_english_week_order_remaps_chinese_arguments(self):
        new_key, order = source_format("Week %2$lld of %1$lld")
        self.assertEqual(new_key, "Week %lld of %lld")
        self.assertEqual(order, [2, 1])
        self.assertEqual(
            remap_format("%lld 年第 %lld 周", order),
            "%2$lld 年第 %1$lld 周",
        )
        self.assertEqual(
            remap_format("%1$lld 年第 %2$lld 周", order),
            "%2$lld 年第 %1$lld 周",
        )

    def test_reordering_preserves_each_argument_type(self):
        new_key, order = source_format("%2$@ saved after %1$lld photos")
        self.assertEqual(new_key, "%@ saved after %lld photos")
        translated = remap_format("删除 %lld 张，节省 %@", order)
        self.assertEqual(translated, "删除 %2$lld 张，节省 %1$@")
        self.assertEqual(
            check_localization.signature(new_key),
            check_localization.signature(translated),
        )

    def test_source_format_preserves_escaped_positional_text(self):
        self.assertEqual(
            source_format("Literal %%1$lld; value %2$lld"),
            ("Literal %%1$lld; value %lld", [2]),
        )

    def test_interpolated_quote_round_trips_percent(self):
        generated = interpolated_quote("%lld%% reviewed", ["count"])
        self.assertEqual(generated, r'"\(count)% reviewed"')
        literal = scan_literals(generated)[0]
        self.assertIsNotNone(re.fullmatch(literal.pattern(), "%lld%% reviewed"))


class CatalogValidationTests(unittest.TestCase):
    def test_duplicate_json_keys_are_rejected_at_any_depth(self):
        for content in [
            '{"strings": {}, "strings": {}}',
            '{"strings": {"Keep": {"value": "A", "value": "B"}}}',
        ]:
            with self.subTest(content=content), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "catalog.json"
                path.write_text(content)
                with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
                    check_localization.load_json(path)

    def test_signatures_validate_argument_types_independent_of_order(self):
        source = "%lld photos · %@ · %lld%%"
        translated = "%3$lld%% · %2$@ · %1$lld 张"
        self.assertEqual(
            check_localization.signature(source),
            check_localization.signature(translated),
        )
        self.assertNotEqual(
            check_localization.signature(source),
            check_localization.signature("%@ photos · %@ · %lld%%"),
        )
        self.assertNotEqual(
            check_localization.signature(source),
            check_localization.signature("%lld photos · %@"),
        )

    def test_conflicting_types_for_reused_argument_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "Argument 1 has inconsistent types"):
            check_localization.signature("%1$lld photos · %1$@")


if __name__ == "__main__":
    unittest.main()
