#!/usr/bin/env python3
"""No real game files or genuine player results: all observations synthetic."""
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
SCRIPT = ROOT / "tools" / "review_patchset3_manual_record.py"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASES = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("manual_record_review", SCRIPT)
assert spec and spec.loader
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class ManualRecordTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        proposal = json.loads(PROPOSAL.read_text(encoding="utf-8"))
        releases = json.loads(RELEASES.read_text(encoding="utf-8"))
        cls.plan = tool.planner.make_plan(proposal, releases)

    def setUp(self):
        self.record = tool.template(self.plan)

    def observed(self):
        self.record.update({
            "reported_utc_date": "2026-10-13",
            "observed_client_build": 12340, "observed_locale": "enUS",
            "reported_disposable_test_environment": True,
            "reported_human_observation": True,
        })

    def mark_pass(self, idx=0):
        row = self.record["valid_scenarios"][idx]
        row["outcome"] = "PASS"
        for check in row["checks"]:
            check["status"] = "PASS"

    def verify_denial(self, result):
        self.assertEqual(result["status"], "UNTRUSTED_SELF_REPORT_ONLY_MANUAL_VERIFICATION_REQUIRED")
        self.assertEqual(result["case_count"], 8)
        for key in ("all_cases_independently_verified", "human_identity_or_consent_authenticated",
                    "game_or_mpq_files_read", "game_or_mpq_files_written",
                    "case_claims_independently_corroborated", "backup_or_recovery_executed",
                    "manifest_or_patchset_written", "installation_authorised",
                    "redistribution_authorised", "public_release_authorised",
                    "private_notes_identifiers_paths_hashes_and_dates_emitted"):
            self.assertIs(result[key], False, key)

    def test_blank_template_exactly_matches_six_plus_two_with_no_claims(self):
        result = tool.review_record(self.record, self.plan)
        self.assertEqual(result["self_reported_counts"], {
            "pass": 0, "fail": 0, "blocked": 0, "not_tested": 8,
        })
        self.assertEqual([r["case_id"] for r in result["valid_scenarios"]],
                         ["base", "u", "j", "j-u", "c", "c-u"])
        self.assertEqual([r["case_id"] for r in result["negative_selection_scenarios"]],
                         ["j-c", "j-c-u"])
        self.assertEqual(self.record["observed_client_build"], None)
        self.verify_denial(result)

    def test_one_self_reported_pass_requires_explicit_disposable_context(self):
        self.mark_pass()
        with self.assertRaisesRegex(tool.Refusal, "observation_requires_explicit_disposable_335a_context"):
            tool.review_record(self.record, self.plan)
        self.observed()
        result = tool.review_record(self.record, self.plan)
        self.assertEqual(result["self_reported_counts"]["pass"], 1)
        self.assertEqual(result["self_reported_counts"]["not_tested"], 7)
        self.verify_denial(result)

    def test_all_eight_self_reported_pass_still_never_verifies_or_authorises(self):
        self.observed()
        for idx in range(6):
            self.mark_pass(idx)
        for row in self.record["negative_selection_scenarios"]:
            row["outcome"] = "PASS"
        result = tool.review_record(self.record, self.plan)
        self.assertEqual(result["self_reported_counts"]["pass"], 8)
        self.verify_denial(result)
        self.assertFalse(result["all_cases_independently_verified"])

    def test_failed_and_blocked_scenarios_are_distinct(self):
        self.observed()
        fail = self.record["valid_scenarios"][0]
        fail["outcome"] = "FAIL"
        fail["checks"][1]["status"] = "FAIL"
        fail["issue_codes"] = ["unexpected_file_change"]
        block = self.record["valid_scenarios"][1]
        block["outcome"] = "BLOCKED"
        block["issue_codes"] = ["no_protected_backup"]
        neg = self.record["negative_selection_scenarios"][0]
        neg["outcome"] = "FAIL"
        neg["issue_codes"] = ["mutex_did_not_reject"]
        result = tool.review_record(self.record, self.plan)
        self.assertEqual(result["self_reported_counts"]["fail"], 2)
        self.assertEqual(result["self_reported_counts"]["blocked"], 1)
        self.verify_denial(result)

    def test_pass_requires_every_check_pass_and_no_issue(self):
        self.observed()
        self.record["valid_scenarios"][0]["outcome"] = "PASS"
        with self.assertRaisesRegex(tool.Refusal, "pass_requires_every_check_pass"):
            tool.review_record(self.record, self.plan)
        self.mark_pass()
        self.record["valid_scenarios"][0]["issue_codes"] = ["other_observed_failure"]
        with self.assertRaisesRegex(tool.Refusal, "issue_codes_contradict_outcome"):
            tool.review_record(self.record, self.plan)

    def test_not_tested_must_not_contain_observed_check(self):
        self.record["valid_scenarios"][2]["checks"][0]["status"] = "PASS"
        with self.assertRaisesRegex(tool.Refusal, "not_tested_contains_observation"):
            tool.review_record(self.record, self.plan)

    def test_fail_needs_failed_check_and_classified_failure(self):
        self.observed()
        row = self.record["valid_scenarios"][0]
        row["outcome"] = "FAIL"
        row["issue_codes"] = ["client_startup_failure"]
        with self.assertRaisesRegex(tool.Refusal, "fail_requires_failed_check"):
            tool.review_record(self.record, self.plan)
        row["checks"][0]["status"] = "FAIL"
        row["issue_codes"] = ["no_protected_backup"]
        with self.assertRaisesRegex(tool.Refusal, "fail_requires_failure_issue_code"):
            tool.review_record(self.record, self.plan)

    def test_blocked_cannot_hide_failed_check(self):
        self.observed()
        row = self.record["valid_scenarios"][0]
        row["outcome"] = "BLOCKED"
        row["issue_codes"] = ["incomplete_checks"]
        row["checks"][0]["status"] = "FAIL"
        with self.assertRaisesRegex(tool.Refusal, "blocked_requires_incomplete_or_blocked_check"):
            tool.review_record(self.record, self.plan)

    def test_invalid_issue_codes_free_text_unknown_fields_or_duplicates_refused(self):
        self.observed()
        self.record["negative_selection_scenarios"][0].update({
            "outcome": "FAIL", "issue_codes": ["my secret account"],
        })
        with self.assertRaisesRegex(tool.Refusal, "unknown_or_ambiguous_issue_codes"):
            tool.review_record(self.record, self.plan)
        record = tool.template(self.plan)
        record["operator_name"] = "private player"
        with self.assertRaisesRegex(tool.Refusal, "unrecognised_record_schema"):
            tool.review_record(record, self.plan)
        record = tool.template(self.plan)
        record["valid_scenarios"][0]["free_text"] = "C:\\private\\client"
        with self.assertRaisesRegex(tool.Refusal, "unrecognised_scenario_schema"):
            tool.review_record(record, self.plan)
        record = tool.template(self.plan)
        record["valid_scenarios"][0]["checks"][0]["check_id"] = "secret-check"
        with self.assertRaisesRegex(tool.Refusal, "unexpected_scenario_check"):
            tool.review_record(record, self.plan)

    def test_missed_reordered_or_duplicate_cases_refused(self):
        for mutate in ("missing", "swapped", "duplicate"):
            with self.subTest(mutate=mutate):
                record = tool.template(self.plan)
                cases = record["valid_scenarios"]
                if mutate == "missing":
                    cases.pop()
                elif mutate == "swapped":
                    cases[0], cases[1] = cases[1], cases[0]
                else:
                    cases[1] = copy.deepcopy(cases[0])
                with self.assertRaises(tool.Refusal):
                    tool.review_record(record, self.plan)

    def test_binding_fails_after_plan_changes_or_corrupt_hash(self):
        record = tool.template(self.plan)
        record["plan_sha256"] = "0" * 64
        with self.assertRaisesRegex(tool.Refusal, "record_plan_binding_invalid_or_stale"):
            tool.review_record(record, self.plan)
        record = tool.template(self.plan)
        different = copy.deepcopy(self.plan)
        different["changed_patch_ids"].append("patch-z")
        with self.assertRaisesRegex(tool.Refusal, "record_plan_binding_invalid_or_stale"):
            tool.review_record(record, different)

    def test_invalid_claimed_build_date_and_boolean_type(self):
        for field, bad in (("observed_client_build", True), ("observed_client_build", 12341),
                           ("observed_locale", "deDE"), ("reported_utc_date", "2026-02-30"),
                           ("reported_disposable_test_environment", False),
                           ("reported_human_observation", False)):
            with self.subTest(field=field, bad=bad):
                record = tool.template(self.plan)
                record.update({
                    "reported_utc_date": "2026-10-13",
                    "observed_client_build": 12340,
                    "observed_locale": "enUS",
                    "reported_disposable_test_environment": True,
                    "reported_human_observation": True,
                })
                record["valid_scenarios"][0]["outcome"] = "PASS"
                for check in record["valid_scenarios"][0]["checks"]:
                    check["status"] = "PASS"
                record[field] = bad
                with self.assertRaisesRegex(tool.Refusal, "observation_requires_explicit_disposable_335a_context"):
                    tool.review_record(record, self.plan)

    def test_blank_record_cannot_claim_date_or_human_attestation(self):
        self.record["reported_human_observation"] = True
        with self.assertRaisesRegex(tool.Refusal, "blank_record_must_not_claim_observation"):
            tool.review_record(self.record, self.plan)

    def test_cli_print_template_then_review_without_writing_client_files(self):
        snapshots = {p: p.read_bytes() for p in (
            PROPOSAL, RELEASES,
            ROOT / "config" / "client-patches.json",
            ROOT / "config" / "patch-versions" / "patchset-0001.json",
            ROOT / "config" / "patch-versions" / "patchset-0002.json",
        )}
        base = [sys.executable, str(SCRIPT), "--proposal", str(PROPOSAL),
                "--release-snapshot", str(RELEASES)]
        produced = subprocess.run(base + ["--print-template"],
                                  capture_output=True, text=True, check=True)
        record = json.loads(produced.stdout)
        self.assertEqual(record["plan_sha256"], tool.fingerprint(self.plan))
        with tempfile.TemporaryDirectory(prefix="fake-human-record-") as folder:
            path = Path(folder) / "local-self-report.json"
            path.write_text(json.dumps(record), encoding="utf-8")
            reviewed = subprocess.run(base + ["--record", str(path)],
                                      capture_output=True, text=True, check=True)
            report = json.loads(reviewed.stdout)
            self.assertEqual(report["self_reported_counts"]["not_tested"], 8)
            self.verify_denial(report)
            for forbidden in (str(ROOT), str(path), "2026-10-13", "68ca0d260841",
                              "e" * 64, "Data/patch-V.mpq"):
                self.assertNotIn(forbidden, reviewed.stdout)
        for p, previous in snapshots.items():
            self.assertEqual(p.read_bytes(), previous)

    def test_oversized_malformed_duplicate_json_key_and_links_refused(self):
        with tempfile.TemporaryDirectory(prefix="fake-human-record-") as folder:
            p = Path(folder) / "record.json"
            p.write_bytes(b"x" * (tool.MAX_RECORD + 1))
            with self.assertRaises(tool.proposals.Refusal):
                tool._read_record(p)
            p.write_text('{"schema_version":1,"schema_version":2}', encoding="utf-8")
            with self.assertRaises(tool.drift.Refusal):
                tool._read_record(p)
            p.write_text("{bad json", encoding="utf-8")
            with self.assertRaises(tool.drift.Refusal):
                tool._read_record(p)


if __name__ == "__main__":
    unittest.main()
