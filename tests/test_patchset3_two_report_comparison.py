#!/usr/bin/env python3
"""Synthetic local report comparisons only, never a genuine human QA record."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SCRIPT = ROOT / "tools" / "compare_patchset3_human_reports.py"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASES = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("two_untrusted_reports", SCRIPT)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TwoReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = module.planner.make_plan(
            json.loads(PROPOSAL.read_text(encoding="utf-8")),
            json.loads(RELEASES.read_text(encoding="utf-8")))

    def setUp(self):
        self.a = module.records.template(self.plan)
        self.b = copy.deepcopy(self.a)

    def observed(self, record, day="2026-10-13"):
        record.update({
            "reported_utc_date": day,
            "observed_client_build": 12340,
            "observed_locale": "enUS",
            "reported_disposable_test_environment": True,
            "reported_human_observation": True,
        })

    def pass_case(self, record, index=0):
        target = record["valid_scenarios"][index]
        target["outcome"] = "PASS"
        for check in target["checks"]:
            check["status"] = "PASS"

    def deny(self, result):
        self.assertEqual(result["scenario_count"], 8)
        for name in (
            "reporter_identity_authentication_performed",
            "independent_test_custody_verified",
            "physical_client_or_mpq_evidence_examined",
            "release_asset_rights_cleared",
            "discrepancies_adjudicated",
            "all_game_tests_independently_verified",
            "trusted_independent_observer_present",
            "tamper_or_replay_proof_established",
            "patchset_or_manifest_written",
            "client_or_wtf_read_or_modified",
            "backup_or_recovery_executed",
            "installation_authorised",
            "redistribution_authorised",
            "public_release_authorised",
            "private_report_dates_paths_hashes_or_identity_emitted",
        ):
            self.assertIs(result[name], False, name)
        self.assertIs(result["both_reports_may_have_same_author"], True)

    def test_identical_blank_documents_cannot_be_called_independent(self):
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["status"], "IDENTICAL_RECORD_CONTENT_NOT_INDEPENDENT_EVIDENCE")
        self.assertEqual(result["matching_case_ids"],
                         ["base", "u", "j", "j-u", "c", "c-u", "j-c", "j-c-u"])
        self.assertEqual(result["discrepant_case_ids"], [])
        self.assertTrue(result["identical_record_content"])
        self.deny(result)

    def test_identical_all_pass_documents_do_not_mean_verified(self):
        for record in (self.a, self.b):
            self.observed(record)
            for i in range(6):
                self.pass_case(record, i)
            for item in record["negative_selection_scenarios"]:
                item["outcome"] = "PASS"
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["status"], "IDENTICAL_RECORD_CONTENT_NOT_INDEPENDENT_EVIDENCE")
        self.assertEqual(result["report_a_self_reported_counts"]["pass"], 8)
        self.assertFalse(result["all_game_tests_independently_verified"])
        self.deny(result)

    def test_different_dates_do_not_establish_two_independent_observers(self):
        self.observed(self.a, "2026-10-12")
        self.observed(self.b, "2026-10-13")
        self.pass_case(self.a)
        self.pass_case(self.b)
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["status"], "MATCHING_UNTRUSTED_REPORTS_NOT_INDEPENDENTLY_VERIFIED")
        self.assertFalse(result["identical_record_content"])
        self.assertEqual(result["matching_case_ids"], [
            "base", "u", "j", "j-u", "c", "c-u", "j-c", "j-c-u"])
        self.deny(result)
        self.assertNotIn("2026-10-12", json.dumps(result))
        self.assertNotIn("2026-10-13", json.dumps(result))

    def test_unobserved_input_cannot_be_taken_as_game_testing(self):
        self.b["plan_sha256"] = self.a["plan_sha256"]
        # Differing *serialization* alone doesn't change JSON dict identity;
        # use two actual, allowed, self-reported statuses and compare semantics.
        self.observed(self.a)
        self.pass_case(self.a)
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["status"], "UNTRUSTED_REPORT_DISCREPANCIES_REQUIRE_MANUAL_REVIEW")
        self.assertEqual(result["discrepant_case_ids"], ["base"])
        self.assertFalse(result["all_game_tests_independently_verified"])

    def test_different_failed_check_with_same_overall_failure_detected(self):
        for record in (self.a, self.b):
            self.observed(record)
            row = record["valid_scenarios"][0]
            row["outcome"] = "FAIL"
            row["issue_codes"] = ["client_startup_failure"]
        self.a["valid_scenarios"][0]["checks"][0]["status"] = "FAIL"
        self.b["valid_scenarios"][0]["checks"][1]["status"] = "FAIL"
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["status"], "UNTRUSTED_REPORT_DISCREPANCIES_REQUIRE_MANUAL_REVIEW")
        self.assertEqual(result["discrepant_case_ids"], ["base"])
        self.assertEqual(result["discrepant_check_count"], 2)
        self.assertFalse(result["public_discrepancies"][0]["outcomes_disagree"])
        self.assertEqual(result["public_discrepancies"][0]["discrepant_check_ids"],
                         [self.plan["scenarios"][0]["checks"][0],
                          self.plan["scenarios"][0]["checks"][1]])
        self.deny(result)

    def test_different_issue_codes_are_not_silently_suppressed(self):
        for record in (self.a, self.b):
            self.observed(record)
            item = record["negative_selection_scenarios"][0]
            item["outcome"] = "BLOCKED"
        self.a["negative_selection_scenarios"][0]["issue_codes"] = ["no_test_environment"]
        self.b["negative_selection_scenarios"][0]["issue_codes"] = ["rights_unresolved"]
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["discrepant_case_ids"], ["j-c"])
        self.assertEqual(result["issue_classification_disagreement_count"], 1)
        self.assertTrue(result["public_discrepancies"][0]["issue_classifications_disagree"])
        self.deny(result)

    def test_two_records_with_different_failed_and_passed_mutex_reports(self):
        self.observed(self.a)
        self.observed(self.b, "2026-10-12")
        self.a["negative_selection_scenarios"][1]["outcome"] = "PASS"
        self.b["negative_selection_scenarios"][1]["outcome"] = "FAIL"
        self.b["negative_selection_scenarios"][1]["issue_codes"] = ["mutex_did_not_reject"]
        result = module.review(self.a, self.b, self.plan)
        self.assertEqual(result["discrepant_case_ids"], ["j-c-u"])
        self.assertTrue(result["public_discrepancies"][0]["outcomes_disagree"])
        self.deny(result)

    def test_bad_record_or_plan_binding_refused_before_comparison(self):
        self.b["plan_sha256"] = "0" * 64
        with self.assertRaisesRegex(module.records.Refusal, "record_plan_binding_invalid_or_stale"):
            module.review(self.a, self.b, self.plan)
        self.b = module.records.template(self.plan)
        self.b["valid_scenarios"][0]["checks"].pop()
        with self.assertRaisesRegex(module.records.Refusal, "incomplete_scenario_checks"):
            module.review(self.a, self.b, self.plan)

    def test_private_field_and_claimed_observer_id_are_not_accepted(self):
        self.b["observer_name"] = "Private Name"
        with self.assertRaisesRegex(module.records.Refusal, "unrecognised_record_schema"):
            module.review(self.a, self.b, self.plan)
        self.b = module.records.template(self.plan)
        self.b["valid_scenarios"][0]["screenshot_path"] = "C:\\Users\\Private\\file.png"
        with self.assertRaisesRegex(module.records.Refusal, "unrecognised_scenario_schema"):
            module.review(self.a, self.b, self.plan)

    def test_cli_exit_codes_only_two_untrusted_local_fixtures(self):
        before = {
            p: p.read_bytes() for p in (
                PROPOSAL, RELEASES,
                ROOT / "config" / "client-patches.json",
                ROOT / "config" / "patch-versions" / "patchset-0001.json",
                ROOT / "config" / "patch-versions" / "patchset-0002.json",
            )
        }
        with tempfile.TemporaryDirectory(prefix="FAKE-Observer-Reports-") as d:
            a, b = Path(d) / "a.json", Path(d) / "b.json"
            base = [sys.executable, str(SCRIPT),
                    "--proposal", str(PROPOSAL), "--release-snapshot", str(RELEASES),
                    "--report-a", str(a), "--report-b", str(b)]
            a.write_text(json.dumps(self.a), encoding="utf-8")
            b.write_text(json.dumps(self.b), encoding="utf-8")
            identical = subprocess.run(base, capture_output=True, text=True)
            self.assertEqual(identical.returncode, 3)
            self.assertEqual(json.loads(identical.stdout)["status"],
                             "IDENTICAL_RECORD_CONTENT_NOT_INDEPENDENT_EVIDENCE")
            self.observed(self.a, "2026-10-12")
            self.observed(self.b, "2026-10-13")
            self.pass_case(self.a)
            self.pass_case(self.b)
            a.write_text(json.dumps(self.a), encoding="utf-8")
            b.write_text(json.dumps(self.b), encoding="utf-8")
            compatible = subprocess.run(base, capture_output=True, text=True)
            self.assertEqual(compatible.returncode, 0)
            self.assertEqual(json.loads(compatible.stdout)["status"],
                             "MATCHING_UNTRUSTED_REPORTS_NOT_INDEPENDENTLY_VERIFIED")
            self.b["valid_scenarios"][0]["outcome"] = "NOT_TESTED"
            for check in self.b["valid_scenarios"][0]["checks"]:
                check["status"] = "NOT_TESTED"
            b.write_text(json.dumps(self.b), encoding="utf-8")
            conflict = subprocess.run(base, capture_output=True, text=True)
            self.assertEqual(conflict.returncode, 3)
            self.assertEqual(json.loads(conflict.stdout)["discrepant_case_ids"], ["base"])
            for out in (identical.stdout, compatible.stdout, conflict.stdout):
                for private in (str(ROOT), str(a), str(b), "2026-10-12", "2026-10-13",
                                "Data/patch-V.mpq", "68ca0d260841"):
                    self.assertNotIn(private, out)
            b.write_text("{bad json", encoding="utf-8")
            refused = subprocess.run(base, capture_output=True, text=True)
            self.assertEqual(refused.returncode, 2)
            self.assertTrue(refused.stderr.startswith("BLOCKED:"))
            self.assertNotIn(str(b), refused.stderr)
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
