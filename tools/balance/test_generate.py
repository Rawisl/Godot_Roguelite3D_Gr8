import contextlib
import copy
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import MagicMock, patch

import openpyxl

import generate


class WaveValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables, errors = generate.read_tables()
        assert not errors, errors

    def setUp(self):
        self.tables = copy.deepcopy(type(self).tables)

    def assert_invalid(self, sheet, row, column, value, message):
        table = self.tables[sheet]
        table.rows[row][column] = value
        coordinate = table.cells[row][column]
        with self.assertRaises(generate.BalanceError) as caught:
            generate.validate_waves(self.tables)
        self.assertIn(f"{sheet}!{coordinate}: {message}", str(caught.exception))

    def test_standard_workbook(self):
        generate.validate_waves(self.tables)

    def test_unknown_enemy(self):
        self.assert_invalid("waves", 0, "enemy_id", "unknown", "unknown enemy_id")

    def test_zero_count(self):
        self.assert_invalid("waves", 0, "count", 0, "count must be at least 1")

    def test_fractional_count(self):
        self.assert_invalid("waves", 0, "count", 1.5, "expected a whole number")

    def test_invalid_escort(self):
        self.assert_invalid("waves", 0, "is_escort", 1, "expected TRUE or FALSE")

    def test_conflicting_coefficients(self):
        for column in generate.WAVE_FIELDS:
            with self.subTest(column=column):
                self.setUp()
                self.assert_invalid("waves", 3, column, 20, f"{column} differs within wave 3")

    def test_short_spawn_duration(self):
        self.assert_invalid("waves", 0, "spawn_duration", 12, "spawn_duration must be at least 15")

    def test_missing_wave(self):
        self.assert_invalid("waves", 0, "wave", 2, "missing waves [1]")

    def test_missing_reward(self):
        self.tables["wave_rewards"].rows[0]["wave"] = 2
        with self.assertRaisesRegex(generate.BalanceError, "wave_rewards!A3: duplicate reward for wave 2"):
            generate.validate_waves(self.tables)
        with self.assertRaisesRegex(generate.BalanceError, r"wave_rewards!A2: missing waves \[1\]"):
            generate.validate_waves(self.tables)

    def test_missing_escort(self):
        table = self.tables["waves"]
        index = next(i for i, row in enumerate(table.rows) if row["wave"] == 5 and row["is_escort"])
        table.rows[index]["is_escort"] = False
        with self.assertRaisesRegex(generate.BalanceError, r"waves!B8: boss wave 5 must have an escort"):
            generate.validate_waves(self.tables)

    def test_multiple_bosses(self):
        self.assert_invalid("waves", 8, "count", 2, "boss wave 5 must contain exactly one boss")

    def test_too_many_types(self):
        table = self.tables["waves"]
        ids = ["grunt", "archer", "brute", "bulwark", "sniper", "rider"]
        self.tables["enemies"].rows.extend({"enemy_id": enemy} for enemy in ids[4:])
        for enemy in ids[1:]:
            row = dict(table.rows[0], enemy_id=enemy)
            table.rows.append(row)
            table.cells.append(dict(table.cells[0]))
        with self.assertRaisesRegex(generate.BalanceError, r"waves!B2: wave 1 has more than 5 enemy types"):
            generate.validate_waves(self.tables)

    def test_missing_enemy_id_header(self):
        table = self.tables["enemies"]
        table.header[0] = "renamed_id"
        for row in table.rows:
            row["renamed_id"] = row.pop("enemy_id")
        with self.assertRaisesRegex(generate.BalanceError, "enemies!A1: missing columns: enemy_id"):
            generate.validate_waves(self.tables)

    def test_equivalent_formula_results(self):
        self.tables["waves"].rows[2]["hp_mult"] = 0.3
        self.tables["waves"].rows[3]["hp_mult"] = 0.1 + 0.2
        generate.validate_waves(self.tables)

    def test_reward_types_and_bounds(self):
        for column, value, message in (
            ("wave", 31, "wave must be in 1..30"),
            ("wave", 1.5, "expected a whole number"),
            ("gold_mult", "invalid", "expected a finite number"),
            ("xp_mult", -1, "negative number"),
            ("mithril_reward", 0.5, "expected a whole number"),
            ("mithril_reward", True, "expected a whole number"),
        ):
            with self.subTest(column=column, value=value):
                self.setUp()
                self.assert_invalid("wave_rewards", 0, column, value, message)

    def test_nonfinite_and_negative_coefficients(self):
        for sheet, columns in (("waves", generate.WAVE_FIELDS),
                               ("wave_rewards", ("gold_mult", "xp_mult", "mithril_reward"))):
            for column in columns:
                for value in (-1, float("nan"), float("inf")):
                    with self.subTest(sheet=sheet, column=column, value=value):
                        self.setUp()
                        self.tables[sheet].rows[0][column] = value
                        with self.assertRaises(generate.BalanceError) as caught:
                            generate.validate_waves(self.tables)
                        self.assertIn(f"{sheet}!{self.tables[sheet].cells[0][column]}:", str(caught.exception))

    def test_configured_limits_are_used(self):
        config = generate.WaveConfig(30, 5, 1, 16.0)
        with patch.object(generate, "wave_config", return_value=config):
            with self.assertRaises(generate.BalanceError) as caught:
                generate.validate_waves(self.tables)
        self.assertIn("spawn_duration must be at least 16 seconds", str(caught.exception))
        self.assertIn("has more than 1 enemy types", str(caught.exception))

    def test_invalid_first_coefficient_does_not_repeat_or_hide_later_errors(self):
        table = self.tables["waves"]
        table.rows[2]["hp_mult"] = "invalid"
        table.rows[3]["count"] = 0
        table.rows[3]["speed_mult"] = "invalid"
        with self.assertRaises(generate.BalanceError) as caught:
            generate.validate_waves(self.tables)
        messages = str(caught.exception).splitlines()
        self.assertEqual(sum(message.startswith("waves!F4:") for message in messages), 1)
        self.assertTrue(any(message.startswith("waves!C5:") for message in messages))
        self.assertTrue(any(message.startswith("waves!H5:") for message in messages))

    def test_duration_and_unknown_enemy_do_not_hide_boss_or_escort_errors(self):
        for invalid_column, invalid_value in (("spawn_duration", 12), ("enemy_id", "unknown")):
            with self.subTest(column=invalid_column):
                self.setUp()
                entries = [row for row in self.tables["waves"].rows if row["wave"] == 5]
                entries[0][invalid_column] = invalid_value
                for row in entries:
                    if row["enemy_id"] == "bulwark":
                        row["count"] = 2
                    row["is_escort"] = False
                with self.assertRaises(generate.BalanceError) as caught:
                    generate.validate_waves(self.tables)
                messages = str(caught.exception)
                self.assertIn("must contain exactly one boss", messages)
                self.assertIn("must have an escort", messages)

    def test_boss_identity_comes_from_resource_id(self):
        for table_name in ("enemies", "waves"):
            for row in self.tables[table_name].rows:
                if row["enemy_id"] == "bulwark":
                    row["enemy_id"] = "sentinel"
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            folder = root / "data" / "bosses"
            folder.mkdir(parents=True)
            (folder / "unrelated_filename.tres").write_text(
                '[gd_resource type="Resource" script_class="BossData" format=3]\n'
                '[resource]\nid = &"sentinel"\n', encoding="utf-8")
            config = generate.wave_config()
            with patch.object(generate, "ROOT", root), patch.object(generate, "wave_config", return_value=config):
                self.assertEqual(generate.boss_ids(), {"sentinel"})
                generate.validate_waves(self.tables)


class WorkbookValidationTests(unittest.TestCase):
    def read_edited_workbook(self, edit):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "balance.xlsx"
            book = openpyxl.load_workbook(generate.XLSX)
            try:
                edit(book)
                book.save(path)
            finally:
                book.close()
            with patch.object(generate, "XLSX", path):
                return generate.read_tables()

    def test_duplicate_header(self):
        def edit(book):
            book["towers"]["B1"] = "tower_id"
        _, errors = self.read_edited_workbook(edit)
        self.assertIn("towers!B1: duplicate header (tower_id)", errors)

    def test_whitespace_header_uses_placeholder_column(self):
        def edit(book):
            book["towers"]["D1"] = "   "
        tables, errors = self.read_edited_workbook(edit)
        self.assertIn("towers!D1: empty header", errors)
        self.assertEqual(tables["towers"].header[3], "column_4")
        self.assertNotIn("", tables["towers"].rows[0])

    def test_trailing_formatted_empty_row_is_an_error(self):
        def edit(book):
            sheet = book["waves"]
            sheet.cell(sheet.max_row + 1, 1).number_format = "0.00"
        _, errors = self.read_edited_workbook(edit)
        self.assertIn("waves!A97: empty cell (wave)", errors)

    def test_missing_sheet(self):
        def edit(book):
            del book["waves"]
        _, errors = self.read_edited_workbook(edit)
        self.assertIn("waves: sheet is missing", errors)

    def test_empty_sheet(self):
        def edit(book):
            del book["waves"]
            book.create_sheet("waves")
        _, errors = self.read_edited_workbook(edit)
        self.assertTrue(any(error.startswith("waves!A1:") for error in errors))

    def test_header_only_sheet(self):
        def edit(book):
            book["waves"].delete_rows(2, book["waves"].max_row)
        _, errors = self.read_edited_workbook(edit)
        self.assertIn("waves!A2: sheet has no data rows", errors)

    def test_renamed_enemy_header_reports_error_without_writing(self):
        def edit(book):
            book["enemies"]["A1"] = "renamed_id"
        tables, errors = self.read_edited_workbook(edit)
        self.assertFalse(errors)
        output = io.StringIO()
        with patch.object(generate, "read_tables", return_value=(tables, errors)), \
             patch.object(generate, "write_plan") as write, contextlib.redirect_stderr(output):
            self.assertEqual(generate.main([]), 1)
        write.assert_not_called()
        self.assertIn("enemies!A1: missing columns: enemy_id", output.getvalue())

    def test_workbook_closes_on_read_failure(self):
        book = MagicMock()
        book.sheetnames = ["character"]
        book.__getitem__.return_value.iter_rows.side_effect = RuntimeError("read failure")
        with patch.object(generate.openpyxl, "load_workbook", return_value=book):
            with self.assertRaisesRegex(RuntimeError, "read failure"):
                generate.read_tables()
        book.close.assert_called_once()

    def test_invalid_cells_write_nothing(self):
        for coordinate, value, message in (
            ("D5", None, "empty cell (max_hp)"),
            ("D5", -3, "negative number -3 (max_hp)"),
            ("D1", None, "empty header"),
        ):
            with self.subTest(coordinate=coordinate, value=value), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "balance.xlsx"
                book = openpyxl.load_workbook(generate.XLSX)
                book["towers"][coordinate] = value
                book.save(path)
                book.close()
                output = io.StringIO()
                with patch.object(generate, "XLSX", path), patch.object(generate, "build_plan") as build:
                    with contextlib.redirect_stderr(output):
                        self.assertEqual(generate.main([]), 1)
                    build.assert_not_called()
                self.assertIn(f"towers!{coordinate}: {message}", output.getvalue())

    def test_completely_empty_row_reports_coordinates(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "balance.xlsx"
            book = openpyxl.load_workbook(generate.XLSX)
            for cell in book["towers"][5]:
                cell.value = None
            book.save(path)
            book.close()
            with patch.object(generate, "XLSX", path):
                _, errors = generate.read_tables()
            self.assertIn("towers!D5: empty cell (max_hp)", errors)


class CliAndRenderingTests(unittest.TestCase):
    def test_unknown_option_does_not_read_or_write(self):
        for option in ("--chek", "--chec", "--check=yes", "unexpected"):
            with self.subTest(option=option), patch.object(generate, "read_tables") as read, \
                 patch.object(generate, "write_plan") as write, contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(generate.main([option]), 2)
                read.assert_not_called()
                write.assert_not_called()

    def test_check_reports_changes_without_writing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "generated.tres"
            plan = generate.Plan()
            plan.add(path, "new\n")
            for current, expected in ((None, 1), ("old\n", 1), ("new\n", 0)):
                with self.subTest(current=current):
                    if current is not None:
                        path.write_text(current, encoding="utf-8")
                    output = io.StringIO()
                    with patch.object(generate, "ROOT", Path(directory)), \
                         patch.object(generate, "read_tables", return_value=({}, [])), \
                         patch.object(generate, "build_plan", return_value=plan), \
                         patch.object(generate, "write_plan") as write, contextlib.redirect_stdout(output):
                        self.assertEqual(generate.main(["--check"]), expected)
                    write.assert_not_called()
                    self.assertEqual(path.read_text(encoding="utf-8") if path.exists() else None, current)
                    self.assertIn(f"{expected} files would change", output.getvalue())

    def test_string_escaping(self):
        value = 'quote" backslash\\ newline\n carriage\r tab\t'
        for kind in ("String", "StringName"):
            with self.subTest(kind=kind):
                result = generate.format_value(value, kind, "test!A1")
                literal = result[1:] if kind == "StringName" else result
                self.assertEqual(json.loads(literal), value)
                self.assertNotIn("\n", result)
                self.assertNotIn("\r", result)

    def test_gen_waves_sorts_flat_arrays_and_coefficients(self):
        table = generate.Table("waves", [], rows=[
            {"wave": 2, "enemy_id": 'quoted"enemy\\name', "count": 10, "is_escort": False,
             "spawn_duration": 15.5, "hp_mult": 1.104, "dmg_mult": 1.062, "speed_mult": 1.005},
            {"wave": 1, "enemy_id": "grunt", "count": 8, "is_escort": False,
             "spawn_duration": 15, "hp_mult": 1, "dmg_mult": 1, "speed_mult": 1},
        ])
        plan = generate.Plan()
        generate.gen_waves(table, plan)
        text = plan.files[generate.ROOT / "data/waves/wave_script.tres"]
        self.assertIn(generate.HEADER_COMMENT, text)
        self.assertNotIn("[sub_resource", text)
        self.assertIn("wave_of_entry = PackedInt32Array(1, 2)", text)
        self.assertIn('enemy_ids = Array[StringName]([&"grunt", &"quoted\\"enemy\\\\name"])', text)
        self.assertIn("counts = PackedInt32Array(8, 10)", text)
        self.assertIn("escorts = PackedByteArray(0, 0)", text)
        self.assertIn("spawn_duration = PackedFloat32Array(15, 15.5)", text)
        self.assertIn("hp_mult = PackedFloat32Array(1, 1.104)", text)
        self.assertIn("dmg_mult = PackedFloat32Array(1, 1.062)", text)
        self.assertIn("speed_mult = PackedFloat32Array(1, 1.005)", text)

    def test_gen_rewards_sorts_and_preserves_uid(self):
        table = generate.Table("wave_rewards", [], rows=[
            {"wave": 2, "gold_mult": 1.04, "xp_mult": 1, "mithril_reward": 1},
            {"wave": 1, "gold_mult": 1, "xp_mult": 1, "mithril_reward": 1},
        ])
        plan = generate.Plan()
        path = generate.ROOT / "data/waves/wave_rewards.tres"
        old = generate.parse_tres(path)
        generate.gen_wave_rewards(table, plan)
        text = plan.files[path]
        self.assertIn(f'uid="{old.uid}"', text)
        self.assertIn(generate.HEADER_COMMENT, text)
        self.assertIn("gold_mult = PackedFloat32Array(1, 1.04)", text)
        self.assertIn("xp_mult = PackedFloat32Array(1, 1)", text)
        self.assertIn("mithril_reward = PackedInt32Array(1, 1)", text)

    def test_enemy_traits_follow_exported_schema(self):
        tables, errors = generate.read_tables()
        self.assertFalse(errors)
        plan = generate.Plan()
        generate.gen_enemies(tables["enemies"], plan)
        self.assertFalse(plan.warnings)
        trait_columns = tables["enemies"].header[17:]
        declared = generate.parse_script(generate.ROOT / "common/enemy_data.gd")
        self.assertEqual(len(trait_columns), 15)
        for column in trait_columns:
            self.assertIn(column, declared)
        for text in plan.files.values():
            for column in trait_columns:
                self.assertIn(f"{column} = ", text)


class GeneratorContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables, errors = generate.read_tables()
        assert not errors, errors

    def make_table(self, name, rows):
        header = list(rows[0])
        cells = [{key: f"{openpyxl.utils.get_column_letter(index + 1)}{number}"
                  for index, key in enumerate(header)} for number in range(2, len(rows) + 2)]
        return generate.Table(name, header, rows, cells)

    def test_required_generator_columns(self):
        required = {
            "character": ("key", "value"),
            "skills": ("skill_id", "key", "level", "value"),
            "towers": ("tower_id", "level", "max_hp"),
            "enemies": ("enemy_id",),
            "weapons": ("weapon_id", "key", "value", "effect_id"),
        }
        for name, columns in required.items():
            for column in columns:
                with self.subTest(sheet=name, column=column):
                    table = copy.deepcopy(self.tables[name])
                    table.header.remove(column)
                    for row in table.rows:
                        row.pop(column)
                    plan = generate.Plan()
                    with self.assertRaisesRegex(generate.BalanceError, f"{name}!A1: missing columns: {column}"):
                        getattr(generate, f"gen_{name}")(table, plan)
                    self.assertFalse(plan.files)

    def test_duplicate_row_keys_are_rejected_before_generation(self):
        for name in ("character", "skills", "towers", "enemies", "weapons"):
            with self.subTest(sheet=name):
                table = copy.deepcopy(self.tables[name])
                table.rows.append(dict(table.rows[0]))
                table.cells.append({key: f"{openpyxl.utils.get_column_letter(index + 1)}9999"
                                    for index, key in enumerate(table.header)})
                plan = generate.Plan()
                with self.assertRaisesRegex(generate.BalanceError, f"{name}!A9999: duplicate row key"):
                    getattr(generate, f"gen_{name}")(table, plan)
                self.assertFalse(plan.files)

    def test_unknown_character_field(self):
        table = self.make_table("character", [{"key": "unknown_balance_stat", "value": 1}])
        with self.assertRaisesRegex(generate.BalanceError, "character!A2: CharacterStats has no field"):
            generate.gen_character(table, generate.Plan())

    def test_skill_level_gaps_and_mismatched_counts(self):
        for levels, message in (([("damage", 1), ("damage", 3)], "has gaps in its levels"),
                                ([("damage", 1), ("damage", 2), ("radius", 1)], "different number of levels")):
            with self.subTest(levels=levels):
                table = self.make_table("skills", [{"skill_id": "whirlwind", "key": key, "level": level, "value": 1}
                                                    for key, level in levels])
                with self.assertRaisesRegex(generate.BalanceError, f"skills!C2: .*{message}"):
                    generate.gen_skills(table, generate.Plan())

    def test_tower_levels_must_reach_configured_maximum(self):
        maximum = generate.config_number("tower_max_level", "int")
        for missing in (2, maximum):
            with self.subTest(level=missing):
                table = copy.deepcopy(self.tables["towers"])
                tower = table.rows[0]["tower_id"]
                index = next(index for index, row in enumerate(table.rows)
                             if row["tower_id"] == tower and row["level"] == missing)
                table.rows.pop(index)
                table.cells.pop(index)
                plan = generate.Plan()
                with self.assertRaisesRegex(generate.BalanceError, f"towers!B2: .*every level in 1..{maximum}"):
                    generate.gen_towers(table, plan)
                self.assertFalse(plan.files)

    def test_weapon_effect_must_be_consistent(self):
        table = self.make_table("weapons", [
            {"weapon_id": "test_weapon", "key": "first", "value": 1, "effect_id": "slow"},
            {"weapon_id": "test_weapon", "key": "second", "value": 2, "effect_id": "burn"},
        ])
        with self.assertRaisesRegex(generate.BalanceError, "weapons!D3: .*more than one effect_id"):
            generate.gen_weapons(table, generate.Plan())

    def test_weapon_effect_key_cannot_override_column(self):
        table = self.make_table("weapons", [
            {"weapon_id": "test_weapon", "key": "effect_id", "value": "burn", "effect_id": "slow"},
        ])
        with self.assertRaisesRegex(generate.BalanceError, "weapons!B2: .*effect_id column"):
            generate.gen_weapons(table, generate.Plan())

    def test_build_plan_collects_errors_across_independent_sheets(self):
        tables = copy.deepcopy(self.tables)
        tables["character"].rows[0]["key"] = "unknown_balance_stat"
        tables["waves"].rows[0]["spawn_duration"] = 12
        with self.assertRaises(generate.BalanceError) as caught:
            generate.build_plan(tables)
        message = str(caught.exception)
        self.assertIn("character!A2: CharacterStats has no field", message)
        self.assertIn("waves!E2: spawn_duration must be at least", message)

    def test_normalized_alias_collisions_are_rejected(self):
        skills = self.make_table("skills", [
            {"skill_id": "heal_station", "key": "heal_rate_base", "level": 1, "value": 1},
            {"skill_id": "heal_station", "key": "heal_rate_add", "level": 1, "value": 2},
        ])
        weapons = self.make_table("weapons", [
            {"weapon_id": "sword", "key": "range_mult", "value": 1, "effect_id": "none"},
            {"weapon_id": "sword_base", "key": "range_mult", "value": 2, "effect_id": "none"},
        ])
        for table in (skills, weapons):
            with self.subTest(sheet=table.name):
                with self.assertRaisesRegex(generate.BalanceError, "duplicate normalized"):
                    getattr(generate, f"gen_{table.name}")(table, generate.Plan())

    def test_numeric_enums_require_valid_integer_members(self):
        for invalid in (True, False, 1.5, -1, 999, float("nan"), float("inf"), None, "unknown"):
            with self.subTest(value=invalid):
                with self.assertRaisesRegex(generate.BalanceError, "enemies!G2:"):
                    generate.format_value(invalid, "Enums.DamageType", "enemies!G2")
        self.assertEqual(generate.format_value(2.0, "Enums.DamageType", "enemies!G2"), "2")
        self.assertEqual(generate.format_value("slash", "Enums.DamageType", "enemies!G2"), "2")

    def test_invalid_alias_configuration_is_reported(self):
        for text in ("invalid json", "{}", "[]", '{"weapon_ids": [], "skill_keys": {}}',
                     '{"weapon_ids": {}, "skill_keys": {"skill": null}}'):
            with self.subTest(text=text), patch.object(Path, "read_text", return_value=text):
                with self.assertRaisesRegex(generate.BalanceError, "aliases.json: invalid balance aliases"):
                    generate.balance_aliases()

    def test_export_comments_annotations_and_literal_inference(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "schema.gd"
            path.write_text('@export var count := 3 # count\n'
                            '@export_range(0, 1)\nvar ratio: float = 0.5 # ratio\n'
                            '@export var label := "hash#inside" # outside\n'
                            '@export var ids := PackedInt32Array()\n', encoding="utf-8")
            self.assertEqual(generate.parse_script(path), {
                "count": "int", "ratio": "float", "label": "String", "ids": "PackedInt32Array",
            })
            path.write_text('@export var object := preload("res://unknown.tres")\n', encoding="utf-8")
            with self.assertRaisesRegex(generate.BalanceError, "cannot infer an exported type"):
                generate.parse_script(path)

    def test_config_literals_allow_inference_and_trailing_comments(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "autoload").mkdir()
            path = root / "autoload" / "game_config.gd"
            path.write_text('@export var tower_max_level := 12 # test\n', encoding="utf-8")
            with patch.object(generate, "ROOT", root):
                self.assertEqual(generate.config_number("tower_max_level", "int"), 12)
                path.write_text('@export var tower_max_level: int = 6 * 2\n', encoding="utf-8")
                with self.assertRaisesRegex(generate.BalanceError, "numeric literal"):
                    generate.config_number("tower_max_level", "int")

    def test_enums_are_loaded_lazily_and_increment_explicit_values(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "common").mkdir()
            path = root / "common" / "enums.gd"
            path.write_text('enum Test { FIRST = 4, SECOND, THIRD = 9, FOURTH } # test\n', encoding="utf-8")
            with patch.object(generate, "ROOT", root):
                self.assertEqual(generate.parse_enums()["Test"], {"FIRST": 4, "SECOND": 5, "THIRD": 9, "FOURTH": 10})
                self.assertEqual(generate.format_value(5, "Enums.Test", "test!A2"), "5")
                path.write_text('enum Test { FIRST = 6 }\n', encoding="utf-8")
                with self.assertRaisesRegex(generate.BalanceError, "not a member"):
                    generate.format_value(5, "Enums.Test", "test!A2")

    def test_main_writes_real_files_and_then_checks_idempotently(self):
        source = generate.ROOT
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(source / "common", root / "common")
            (root / "autoload").mkdir()
            shutil.copy2(source / "autoload/game_config.gd", root / "autoload/game_config.gd")
            for path in (source / "data").rglob("*.tres"):
                target = root / path.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
            (root / "balance").mkdir()
            workbook = root / "balance/balance.xlsx"
            book = openpyxl.load_workbook(generate.XLSX)
            try:
                book["character"]["B2"] = 123
                book.save(workbook)
            finally:
                book.close()
            wave_path = root / "data/waves/wave_script.tres"
            wave_path.unlink()
            output = io.StringIO()
            with patch.object(generate, "ROOT", root), patch.object(generate, "XLSX", workbook), \
                 contextlib.redirect_stdout(output):
                self.assertEqual(generate.main([]), 0)
                self.assertEqual(generate.main(["--check"]), 0)
            self.assertIn("commander_max_hp = 123", (root / "data/config/commander_stats.tres").read_text(encoding="utf-8"))
            self.assertIn(generate.HEADER_COMMENT, wave_path.read_text(encoding="utf-8"))
            self.assertIn("0 files would change", output.getvalue())
            self.assertFalse(list(root.rglob("*.tmp")))


class WritePlanTests(unittest.TestCase):
    def test_failed_install_rolls_back_existing_and_new_files(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / f"{index}.tres" for index in range(3)]
            paths[0].write_bytes(b"original\r\n")
            paths[2].write_bytes(b"last\n")
            plan = generate.Plan()
            for path in paths:
                plan.add(path, "updated\n")
            replace = generate.os.replace
            calls = 0

            def fail_third(source, destination):
                nonlocal calls
                calls += 1
                if calls == 3:
                    raise OSError("injected install failure")
                return replace(source, destination)

            with patch.object(generate.os, "replace", side_effect=fail_third):
                with self.assertRaisesRegex(OSError, "injected install failure"):
                    generate.write_plan(plan, paths)
            self.assertEqual(paths[0].read_bytes(), b"original\r\n")
            self.assertFalse(paths[1].exists())
            self.assertEqual(paths[2].read_bytes(), b"last\n")
            self.assertFalse(list(Path(directory).glob("*.tmp")))

    def test_failed_staging_does_not_install_any_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "data.tres"
            path.write_bytes(b"original\n")
            plan = generate.Plan()
            plan.add(path, "updated\n")
            with patch.object(generate.os, "fsync", side_effect=OSError("injected staging failure")):
                with self.assertRaisesRegex(OSError, "injected staging failure"):
                    generate.write_plan(plan, [path])
            self.assertEqual(path.read_bytes(), b"original\n")
            self.assertFalse(list(Path(directory).glob("*.tmp")))

    def test_failed_rollback_retains_original_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / f"{index}.tres" for index in range(2)]
            plan = generate.Plan()
            for path in paths:
                path.write_bytes(b"original\n")
                plan.add(path, "updated\n")
            replace = generate.os.replace
            calls = 0

            def fail_after_first(source, destination):
                nonlocal calls
                calls += 1
                if calls > 1:
                    raise OSError("injected persistent failure")
                return replace(source, destination)

            with patch.object(generate.os, "replace", side_effect=fail_after_first):
                with self.assertRaisesRegex(OSError, "rollback incomplete"):
                    generate.write_plan(plan, paths)
            backups = list(Path(directory).glob("*.tmp"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_bytes(), b"original\n")
            self.assertEqual(paths[1].read_bytes(), b"original\n")


if __name__ == "__main__":
    unittest.main()
