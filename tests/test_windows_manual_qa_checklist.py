#!/usr/bin/env python3
"""Synthetic-only test of printable human QA worksheet; no real client test."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SOURCE = ROOT / "tools" / "print_windows_manual_qa_checklist.py"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASES = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("human_windows_qa", SOURCE)
assert spec and spec.loader
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class WindowsWorksheetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = tool.qa.make_plan(
            json.loads(PROPOSAL.read_text(encoding="utf-8")),
            json.loads(RELEASES.read_text(encoding="utf-8")))

    def test_six_valid_cases_exactly_match_preflight_options_and_required_patches(self):
        doc = tool.render(self.plan)
        for case, options in tool.preflight.OPTIONS.items():
            self.assertEqual(doc.count("### " + chr(96) + case + chr(96) + " — "), 1)
            command = " --selection " + case + "\n"
            self.assertEqual(doc.count(command), 1)
            self.assertIn("V + Z" + (" + " + " + ".join(options) if options else ""), doc)
        self.assertNotIn(" --selection j-c\n", doc)
        self.assertNotIn(" --selection j-c-u\n", doc)

    def test_both_illegal_mutex_attempts_are_negative_selection_only(self):
        doc = tool.render(self.plan)
        self.assertEqual(doc.count("### " + chr(96) + "j-c" + chr(96) + " — "), 1)
        self.assertEqual(doc.count("### " + chr(96) + "j-c-u" + chr(96) + " — "), 1)
        self.assertIn("rejected BEFORE any file write", doc)
        self.assertIn("do NOT install both patches", doc)
        self.assertIn("mutex_did_not_reject", doc)

    def test_every_check_is_rendered_in_its_actual_plan_case_and_never_auto_checked(self):
        doc = tool.render(self.plan)
        for case in self.plan["scenarios"]:
            expected_count = sum(x in case["checks"] for x in tool.CHECK_LABELS)
            self.assertEqual(expected_count, len(case["checks"]))
            for check in case["checks"]:
                self.assertEqual(doc.count(chr(96) + check + chr(96) + " — "),
                                 sum(check in c["checks"] for c in self.plan["scenarios"]))
        self.assertIn("J/U overlapping loading texture paths", doc)
        self.assertIn("Dark Portal", doc)
        self.assertNotIn("- [x]", doc)
        self.assertNotIn("- [X]", doc)

    def test_accessibility_acceptance_scales_and_assistive_technology_unperformed(self):
        doc = tool.render(self.plan)
        for scale in ("100%", "125%", "150%", "200%", "300%"):
            self.assertIn("### Display scaling " + scale + " — NOT TESTED", doc)
        for required in ("High Contrast", "Narrator", "Keyboard", "Shift+Tab"):
            self.assertIn(required.lower(), doc.lower())
        self.assertIn("hands-on acceptance", doc)

    def test_baseline_provenance_cannot_be_inferred_from_wow_exe_metadata(self):
        doc = tool.render(self.plan)
        for expected in ("12340", "enUS", "File version", "NOT independent evidence",
                         "patchset-0002", "patchset-0003", "source", "not prove"):
            self.assertIn(expected.lower(), doc.lower())
        self.assertIn("v2 pins do not prove changed hypothetical v3 files", doc)

    def test_no_private_hash_path_or_personal_data_appears(self):
        doc = tool.render(self.plan)
        for forbidden in (
            "68ca0d260841", "5eb17ce5dc7b", "e" * 64,
            "2026-10-13T15:00:00", str(ROOT),
            "SUPER-PRIVATE", "SavedVariables.lua",
        ):
            self.assertNotIn(forbidden, doc)
        self.assertIn("D:\\SeparateTestCopy", doc)
        self.assertIn("never the sole working client", doc)

    def test_missing_changed_cases_and_pretend_performed_are_rejected(self):
        for edit in ("missing", "duplicate", "passed", "changed_extra"):
            with self.subTest(edit=edit):
                p = copy.deepcopy(self.plan)
                if edit == "missing":
                    p["scenarios"].pop()
                elif edit == "duplicate":
                    p["scenarios"][1]["case_id"] = p["scenarios"][0]["case_id"]
                elif edit == "passed":
                    p["scenarios"][0]["human_execution_status"] = "PASS"
                else:
                    p["scenarios"][1]["selected_optional_patches"] = ["J", "C"]
                with self.assertRaises(tool.Refusal):
                    tool.render(p)

    def test_missing_or_forged_subchecks_or_mutex_rejection_are_rejected(self):
        for edit in ("omit", "inject", "mutex"):
            with self.subTest(edit=edit):
                p = copy.deepcopy(self.plan)
                if edit == "omit":
                    p["scenarios"][0]["checks"].pop()
                elif edit == "inject":
                    p["scenarios"][0]["checks"].append("disable_backups")
                else:
                    p["negative_selection_scenarios"][0]["expected"] = "ACCEPT_BOTH_PATCHES"
                with self.assertRaises(tool.Refusal):
                    tool.render(p)

    def test_invalid_source_plan_result_cannot_be_printed_as_worksheet(self):
        p = copy.deepcopy(self.plan)
        p["status"] = "ALL_TESTS_PASS"
        with self.assertRaisesRegex(tool.Refusal, "invalid_qa_plan_state"):
            tool.render(p)

    def test_j_u_warning_without_hiding_c_absence(self):
        doc = tool.render(self.plan)
        j_u = doc.split("### " + chr(96) + "j-u" + chr(96) + " — ")[1].split("### ")[0]
        self.assertIn("J/U overlapping", j_u)
        self.assertIn(" --selection j-u", j_u)
        self.assertIn("Unselected optional MPQs", doc)
        self.assertIn("C", j_u)

    def test_cli_prints_no_private_input_or_modifies_checked_in_files(self):
        important = [
            PROPOSAL, RELEASES, ROOT / "config" / "client-patches.json",
            ROOT / "config" / "patch-versions" / "patchset-0001.json",
            ROOT / "config" / "patch-versions" / "patchset-0002.json",
        ]
        original = {p: p.read_bytes() for p in important}
        command = [
            sys.executable, str(SOURCE), "--proposal", str(PROPOSAL),
            "--release-snapshot", str(RELEASES)
        ]
        run = subprocess.run(command, capture_output=True, text=True, check=True)
        self.assertTrue(run.stdout.startswith("# Naxxramas"))
        self.assertIn("NO TESTS EXECUTED", run.stdout)
        self.assertIn("NO BACKUP, RESTORE, INSTALLATION OR PUBLIC RELEASE AUTHORISED", run.stdout)
        self.assertNotIn(str(ROOT), run.stdout)
        for p, data in original.items():
            self.assertEqual(p.read_bytes(), data)

    def test_unknown_or_stale_proposal_fails_closed_without_leaking_path(self):
        import tempfile
        with tempfile.TemporaryDirectory(prefix="fake-checklist-source-") as folder:
            bad = Path(folder) / "private.json"
            bad.write_text('{"client_path":"C:\\\\private\\\\user"}', encoding="utf-8")
            result = subprocess.run([
                sys.executable, str(SOURCE), "--proposal", str(bad),
                "--release-snapshot", str(RELEASES)
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertTrue(result.stderr.startswith("BLOCKED:"))
            self.assertNotIn(str(bad), result.stderr)
            self.assertNotIn("private", result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
