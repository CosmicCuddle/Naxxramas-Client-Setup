#!/usr/bin/env python3
"""All generated QA plans use fake proposals and unexecuted test descriptions."""
from __future__ import annotations

import copy
import importlib.util
import itertools
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASES = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
sys.path.insert(0, str(TOOLS))
SCRIPT = TOOLS / "plan_patchset3_manual_qa.py"
spec = importlib.util.spec_from_file_location("manual_patchset3_plan", SCRIPT)
assert spec is not None and spec.loader is not None
planner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(planner)

EXPECTED_OPTIONS = [(), ("U",), ("J",), ("J", "U"), ("C",), ("C", "U")]
EXPECTED_IDS = ["base", "u", "j", "j-u", "c", "c-u"]
PATCH_NAMES = ("V", "Z", "J", "C", "U")


class Patchset3ManualPlanTests(unittest.TestCase):
    def setUp(self):
        self.base = json.loads(PROPOSAL.read_text(encoding="utf-8"))
        self.releases = json.loads(RELEASES.read_text(encoding="utf-8"))

    def with_changes(self, chosen):
        """Produce only a synthetic, strictly consistent revision-2 proposal."""
        out = copy.deepcopy(self.base)
        out["changes"] = []
        original = planner.proposal_review._check_frozen_history()["patches"]
        for i, (checked, prior) in enumerate(zip(out["files_checked"], original)):
            name = PATCH_NAMES[i]
            present = name in chosen
            checked["changed"] = present
            checked["sha256"] = (name.lower() * 64)[:64] if present else prior["sha256"]
            checked["size_bytes"] = prior["size_bytes"] + 10 + i if present else prior["size_bytes"]
            # Nonnumeric hex letter 'u', 'j', 'v', 'z' would be rejected;
            # assign deterministic syntactically valid fake 64-digit hashes.
            if present:
                checked["sha256"] = "abcde"[i] * 64
                out["changes"].append({
                    "path": prior["path"],
                    "previous_sha256": prior["sha256"],
                    "new_sha256": checked["sha256"],
                    "previous_size_bytes": prior["size_bytes"],
                    "new_size_bytes": checked["size_bytes"],
                })
        return out

    def check_never_authorised(self, plan):
        self.assertEqual(plan["status"], "MANUAL_PLAN_NO_TEST_EXECUTION_OR_APPROVAL")
        self.assertEqual(plan["candidate_patchset"], "patchset-0003_NOT_CREATED")
        for key in (
            "all_scenarios_passed", "publisher_or_source_authenticated",
            "gameplay_test_performed", "physical_accessibility_test_performed",
            "real_mpq_bytes_inspected", "player_client_or_wtf_read",
            "player_client_or_wtf_modified", "backups_created", "recovery_tested",
            "patchset_or_manifest_written", "installation_authorised",
            "redistribution_authorised", "public_release_authorised",
            "private_paths_hashes_or_user_timestamps_reported",
        ):
            self.assertIs(plan[key], False, key)
        self.assertTrue(all(x["status"] == "NOT_VERIFIED" for x in plan["required_human_evidence"]))
        self.assertTrue(all(x["human_execution_status"] == "NOT_TESTED" and
                            x["result"] == "NO_RESULT_RECORDED" for x in plan["scenarios"]))
        self.assertTrue(all(x["human_execution_status"] == "NOT_TESTED" and
                            x["result"] == "NO_RESULT_RECORDED" for x in plan["negative_selection_scenarios"]))

    def test_six_valid_option_cases_and_two_negative_mutex_attempts(self):
        plan = planner.make_plan(self.base, self.releases)
        self.assertEqual(plan["base_patchset"], "patchset-0002")
        self.assertEqual(plan["changed_patch_ids"], ["patch-v"])
        self.assertEqual(plan["valid_scenario_count"], 6)
        self.assertEqual(plan["invalid_mutex_scenario_count"], 2)
        self.assertEqual([x["case_id"] for x in plan["scenarios"]], EXPECTED_IDS)
        self.assertEqual([tuple(x["selected_optional_patches"]) for x in plan["scenarios"]], EXPECTED_OPTIONS)
        self.assertTrue(all(x["required_patches"] == ["V", "Z"] for x in plan["scenarios"]))
        self.assertEqual([tuple(x["attempted_optional_patches"]) for x in plan["negative_selection_scenarios"]],
                         [("J", "C"), ("J", "C", "U")])
        self.assertTrue(all(x["expected"] == "MUTUALLY_EXCLUSIVE_J_C_REFUSED_NO_FILE_WRITE"
                            for x in plan["negative_selection_scenarios"]))
        self.assertIn("core_v_z_dbc_spell_client_asset_and_server_compatibility", plan["manual_risk_focus"])
        j_u = next(x for x in plan["scenarios"] if x["case_id"] == "j-u")
        self.assertIn("j_u_two_overlapping_texture_paths_must_warn_and_be_checked", j_u["checks"])
        for x in plan["scenarios"]:
            self.assertIn("baseline_335a_build_12340_and_enus_compatibility", x["checks"])
            self.assertIn("no_unexpected_game_file_or_wtf_mutation", x["checks"])
        self.check_never_authorised(plan)

    def test_all_31_nonempty_synthetic_patch_change_sets(self):
        for n in range(1, 6):
            for choice in itertools.combinations(PATCH_NAMES, n):
                with self.subTest(changes=choice):
                    plan = planner.make_plan(self.with_changes(choice), self.releases)
                    self.assertEqual(plan["changed_count"] if "changed_count" in plan else
                                     len(plan["changed_patch_ids"]), n)
                    self.assertEqual(len(plan["scenarios"]), 6)
                    self.assertEqual([tuple(x["selected_optional_patches"]) for x in plan["scenarios"]],
                                     EXPECTED_OPTIONS)
                    self.assertNotIn(("J", "C"), EXPECTED_OPTIONS)
                    self.check_never_authorised(plan)

    def test_visual_and_audio_focus_only_when_corresponding_patch_changes(self):
        cases = {
            ("V",): ["core_v_z_dbc_spell_client_asset_and_server_compatibility"],
            ("C",): ["login_glue_visual_audio_assets_and_standard_screen_reversion",
                     "tbc_login_with_and_without_u"],
            ("J",): ["login_glue_visual_audio_assets_and_standard_screen_reversion",
                     "eastern_kingdoms_kalimdor_and_widescreen_loading_art"],
            ("U",): ["eastern_kingdoms_kalimdor_and_widescreen_loading_art"],
            ("Z",): ["core_v_z_dbc_spell_client_asset_and_server_compatibility"],
        }
        for changed, focus in cases.items():
            with self.subTest(changed=changed):
                plan = planner.make_plan(self.with_changes(changed), self.releases)
                self.assertEqual(plan["manual_risk_focus"], focus)

    def test_new_published_matching_hash_still_has_no_permission(self):
        releases = copy.deepcopy(self.releases)
        releases["patch_releases"].insert(0, {
            "tag_name": "v1.0.6.8.5", "published_at": "2026-10-13T16:00:00Z",
            "draft": False, "prerelease": False,
            "assets": [{"name": "patch-V.mpq", "size": 700000000,
                        "digest": "sha256:" + "e" * 64}],
        })
        plan = planner.make_plan(self.base, releases)
        self.assertEqual(plan["changed_release_metadata_classifications"]["patch-v"],
                         "changed_bytes_match_public_release_metadata_NOT_APPROVAL")
        self.check_never_authorised(plan)

    def test_stale_base_unknown_field_or_missing_required_refused_before_any_qa_plan(self):
        scenarios = (
            ("base_patch_set_revision", 1),
            ("proposed_patch_set_revision", 4),
            ("proposed_patch_set_version", "patchset-0004"),
        )
        for key, value in scenarios:
            with self.subTest(key=key):
                p = copy.deepcopy(self.base)
                p[key] = value
                with self.assertRaises(planner.proposal_review.Refusal):
                    planner.make_plan(p, self.releases)
        p = copy.deepcopy(self.base)
        p["personal_file_path"] = "/private/client"
        with self.assertRaises(planner.proposal_review.Refusal):
            planner.make_plan(p, self.releases)
        p = copy.deepcopy(self.base)
        p["files_checked"].pop(1)
        with self.assertRaises(planner.proposal_review.Refusal):
            planner.make_plan(p, self.releases)

    def test_missing_release_asset_cannot_turn_into_test_approval(self):
        broken = copy.deepcopy(self.releases)
        broken["patch_releases"][0]["assets"] = []
        plan = planner.make_plan(self.base, broken)
        self.assertEqual(plan["changed_release_metadata_classifications"]["patch-v"],
                         "new_bytes_not_in_latest_public_release_metadata")
        self.check_never_authorised(plan)

    def test_cli_discloses_no_proposed_hash_path_timestamp_and_does_not_write(self):
        before = {p: p.read_bytes() for p in (
            PROPOSAL, RELEASES, ROOT / "config" / "client-patches.json",
            ROOT / "config" / "patch-versions" / "patchset-0001.json",
            ROOT / "config" / "patch-versions" / "patchset-0002.json",
        )}
        proc = subprocess.run([
            sys.executable, str(SCRIPT),
            "--proposal", str(PROPOSAL), "--release-snapshot", str(RELEASES),
        ], capture_output=True, text=True, check=True)
        plan = json.loads(proc.stdout)
        self.check_never_authorised(plan)
        for forbidden in (str(ROOT), "e" * 64, "68ca0d260841", "2026-10-13T15:00:00Z",
                          "Data/patch-V.mpq", "Wow.exe"):
            self.assertNotIn(forbidden, proc.stdout)
        for p, data in before.items():
            self.assertEqual(p.read_bytes(), data)

    def test_cli_refuses_invalid_local_proposal_without_leaking_path(self):
        with tempfile.TemporaryDirectory(prefix="FAKE-PATCH-REVIEW-") as directory:
            bad = Path(directory) / "private-proposal.json"
            bad.write_text('{"client_path":"C:\\\\Sensitive\\\\Wow.exe"}', encoding="utf-8")
            result = subprocess.run([
                sys.executable, str(SCRIPT), "--proposal", str(bad),
                "--release-snapshot", str(RELEASES),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("BLOCKED:", result.stderr)
            self.assertNotIn(str(bad), result.stderr)
            self.assertNotIn("Sensitive", result.stderr)


if __name__ == "__main__":
    unittest.main()
