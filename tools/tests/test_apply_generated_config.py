"""Run: python3 -m unittest discover -s tools/tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import apply_generated_config as gen  # noqa: E402


class ParseSectionsTest(unittest.TestCase):
    def test_returns_each_section_body(self):
        log = "noise\n@@GEN_BEGIN A\nline1\nline2\n@@GEN_END A\n@@GEN_BEGIN CONFIG_B\nx\n@@GEN_END CONFIG_B\n"
        self.assertEqual(gen.parse_sections(log), {"A": "line1\nline2", "CONFIG_B": "x"})

    def test_last_section_with_same_name_wins(self):
        log = "@@GEN_BEGIN A\nold\n@@GEN_END A\n@@GEN_BEGIN A\nnew\n@@GEN_END A\n"
        self.assertEqual(gen.parse_sections(log), {"A": "new"})

    def test_ignores_begin_without_matching_end(self):
        self.assertEqual(gen.parse_sections("@@GEN_BEGIN A\nbody\n@@GEN_END B\n"), {})


class ReplaceMarkedTest(unittest.TestCase):
    TEXT = "a\n  -- START: X\nold\n  -- END: X\nz"

    def test_replaces_lines_between_markers(self):
        self.assertEqual(gen.replace_marked(self.TEXT, "X", "n1\nn2"), "a\n  -- START: X\nn1\nn2\n  -- END: X\nz")

    def test_empty_body_clears_the_range(self):
        self.assertEqual(gen.replace_marked(self.TEXT, "X", ""), "a\n  -- START: X\n  -- END: X\nz")

    def test_returns_none_when_markers_are_missing(self):
        self.assertIsNone(gen.replace_marked(self.TEXT, "Y", "n"))

    def test_returns_none_when_end_comes_before_start(self):
        self.assertIsNone(gen.replace_marked("-- END: X\n-- START: X", "X", "n"))


class BlockTest(unittest.TestCase):
    def test_split_blocks_ends_at_first_closing_brace_line(self):
        code = "config.a.b = {\n  inner = {\n  },\n}\nconfig.c = {\n}\n"
        blocks = gen.split_blocks(code)
        self.assertEqual([h for h, _ in blocks], ["config.a.b = {", "config.c = {"])
        self.assertEqual(blocks[0][1], ["config.a.b = {", "  inner = {", "  },", "}"])

    def test_split_blocks_skips_lines_outside_blocks(self):
        self.assertEqual(gen.split_blocks("-- comment\nlocal x = 1\n"), [])

    def test_replace_block_swaps_the_block_with_the_same_header(self):
        text = "head\nconfig.a = {\n  old = 1,\n}\ntail"
        self.assertEqual(
            gen.replace_block(text, "config.a = {", ["config.a = {", "  new = 2,", "}"]),
            "head\nconfig.a = {\n  new = 2,\n}\ntail",
        )

    def test_replace_block_returns_none_when_header_is_missing(self):
        self.assertIsNone(gen.replace_block("x", "config.a = {", ["config.a = {", "}"]))

    def test_replace_block_returns_none_when_block_never_closes(self):
        self.assertIsNone(gen.replace_block("config.a = {\n  x = 1", "config.a = {", ["config.a = {", "}"]))


if __name__ == "__main__":
    unittest.main()
