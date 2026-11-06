"""Run: python3 -m unittest discover -s tools/tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import gen_ui_types as gen  # noqa: E402


def schema(*lines):
    return "\n".join(["local x = 1", gen.BEGIN_MARKER, *lines, gen.END_MARKER, "---@class SBJ__Outside: table"])


class GenerateTest(unittest.TestCase):
    def test_maps_lua_types_to_typescript(self):
        output = gen.generate(schema(
            "---A row",
            "---@class SBJ__Row: table",
            "---@field count integer How many",
            "---@field pos CMO__Location",
            "---@field tags table<string, string[]>",
            "---@field points table<integer, CMO__Location[]>",
            "---@field owner {guid: string, name?: string}",
        ))

        self.assertIn("import type { Coordinate } from '@/types/geo';", output)
        self.assertIn("/** A row */\nexport interface Row {", output)
        self.assertIn("  /** How many */\n  count: number;", output)
        self.assertIn("  pos: Coordinate;", output)
        self.assertIn("  tags: Record<string, string[]>;", output)
        self.assertIn("  points: Coordinate[][];", output)
        self.assertIn("  owner: { guid: string; name?: string };", output)

    def test_marks_question_mark_and_nil_union_fields_optional(self):
        output = gen.generate(schema(
            "---@class SBJ__Row: table",
            "---@field a? string",
            "---@field b string[]|nil Maybe",
        ))

        self.assertIn("  a?: string;", output)
        self.assertIn("  /** Maybe */\n  b?: string[];", output)

    def test_extends_a_parent_only_when_it_is_in_the_block(self):
        output = gen.generate(schema(
            "---@class SBJ__Base: table",
            "---@field name string",
            "---@class SBJ__Child: SBJ__Base",
            "---@field extra boolean",
            "---@class SBJ__Panel: SBJ__Outside",
            "---@field id string",
        ))

        self.assertIn("export interface Child extends Base {", output)
        self.assertIn("export interface Panel {", output)

    def test_emits_aliases(self):
        output = gen.generate(schema("---@alias SBJ__Set table<string, SBJ__Row>", "---@class SBJ__Row: table"))

        self.assertIn("export type Set = Record<string, Row>;", output)

    def test_rejects_a_type_declared_outside_the_block(self):
        with self.assertRaisesRegex(gen.ContractError, "SBJ__Outside"):
            gen.generate(schema("---@class SBJ__Row: table", "---@field other SBJ__Outside"))

    def test_rejects_an_annotation_it_cannot_translate(self):
        with self.assertRaisesRegex(gen.ContractError, "unsupported"):
            gen.generate(schema("---@class SBJ__Row: table", "---@type string"))

    def test_requires_exactly_one_block(self):
        with self.assertRaises(gen.ContractError):
            gen.generate("---@class SBJ__Row: table")


if __name__ == "__main__":
    unittest.main()
