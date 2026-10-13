#!/usr/bin/env python3
"""Tamper/replay/escape regression tests for generated fake ASCII bundles only."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SOURCE = ROOT / "tools" / "review_synthetic_patchset3_evidence.py"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASES = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("fake_evidence", SOURCE)
assert spec and spec.loader
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class SyntheticEvidenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = checker.planner.make_plan(
            json.loads(PROPOSAL.read_text(encoding="utf-8")),
            json.loads(RELEASES.read_text(encoding="utf-8")))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="Naxx-FAKE-Evidence-")
        self.addCleanup(self.temp.cleanup)
        self.bundle = Path(self.temp.name) / "bundle"
        self.bundle.mkdir()
        self.record = checker.records.template(self.plan)
        self.record.update({
            "reported_utc_date": "2026-10-13",
            "observed_client_build": 12340,
            "observed_locale": "enUS",
            "reported_disposable_test_environment": True,
            "reported_human_observation": True,
        })
        base = self.record["valid_scenarios"][0]
        base["outcome"] = "PASS"
        for item in base["checks"]:
            item["status"] = "PASS"
        negative = self.record["negative_selection_scenarios"][0]
        negative["outcome"] = "PASS"
        (self.bundle / checker.MARKER).write_bytes(checker.MARKER_BYTES)
        (self.bundle / "evidence").mkdir()
        self.rebuild_fixture()

    def rebuild_fixture(self):
        """TEST ONLY: create fake plain-text bytes, never any game asset."""
        folder = self.bundle / "evidence"
        for f in folder.iterdir():
            if f.is_file() or f.is_symlink():
                f.unlink()
        (self.bundle / "report.json").write_text(json.dumps(self.record, sort_keys=True),
                                                   encoding="utf-8")
        entries = []
        for ident, check_id, status in checker.expected_artifacts(self.record, self.plan):
            payload = checker.fake_payload(ident, check_id, status)
            name = f"{ident}--{check_id}.txt"
            (folder / name).write_bytes(payload)
            entries.append({
                "case_id": ident, "check_id": check_id, "status": status,
                "file": "evidence/" + name,
                "size_bytes": len(payload),
                "sha256": hashlib.sha256(payload).hexdigest(),
            })
        index = {
            "schema_version": 1, "kind": checker.KIND,
            "plan_sha256": checker.records.fingerprint(self.plan),
            "report_sha256": hashlib.sha256(checker.records._json_bytes(self.record)).hexdigest(),
            "artifacts": entries,
        }
        (self.bundle / "index.json").write_text(json.dumps(index, sort_keys=True),
                                                 encoding="utf-8")

    def check_denied(self, outcome):
        self.assertEqual(outcome["status"], "SYNTHETIC_BYTES_CONSISTENT_NOT_GAME_EVIDENCE")
        self.assertEqual(outcome["scenario_count"], 8)
        for key in (
            "independent_custody_verified", "publisher_or_test_operator_authenticated",
            "physical_gameplay_or_accessibility_observed",
            "real_mpq_image_or_player_files_read", "real_mpq_image_or_player_files_modified",
            "protection_against_coherent_replay", "true_source_rights_established",
            "backup_or_recovery_performed", "patchset_or_manifest_written",
            "installation_authorised", "redistribution_authorised",
            "public_release_authorised", "private_paths_hashes_report_dates_or_identities_emitted",
        ):
            self.assertIs(outcome[key], False, key)

    def test_synthetic_byte_integrity_and_case_binding_without_claims_of_verification(self):
        report = checker.review(self.bundle, self.plan)
        self.assertEqual(report["synthetic_artifact_count"],
                         len(self.record["valid_scenarios"][0]["checks"]) + 1)
        self.assertEqual(report["self_reported_counts"]["pass"], 2)
        self.assertTrue(report["fixture_only"])
        self.assertTrue(report["marker_not_a_trusted_authority"])
        self.assertTrue(report["bundle_hashes_not_an_independent_trust_root"])
        self.check_denied(report)

    def test_missing_marker_bad_marker_and_unmarked_directory_are_refused(self):
        path = self.bundle / checker.MARKER
        original = path.read_bytes()
        path.unlink()
        with self.assertRaises(checker.Refusal):
            checker.review(self.bundle, self.plan)
        path.write_bytes(b"WRONG MARKER\n")
        with self.assertRaisesRegex(checker.Refusal, "synthetic_fixture_marker_mismatch"):
            checker.review(self.bundle, self.plan)
        path.write_bytes(original)
        self.check_denied(checker.review(self.bundle, self.plan))

    def test_missing_modified_and_trailing_fake_payloads_fail_closed(self):
        first = next((self.bundle / "evidence").iterdir())
        pristine = first.read_bytes()
        first.write_bytes(pristine + b"TAMPER")
        with self.assertRaisesRegex(checker.Refusal, "modified_or_replaced_synthetic_artifact_bytes"):
            checker.review(self.bundle, self.plan)
        first.write_bytes(pristine)
        first.unlink()
        with self.assertRaises(checker.Refusal):
            checker.review(self.bundle, self.plan)

    def test_missing_and_extra_index_entries_are_refused(self):
        index_path = self.bundle / "index.json"
        index = json.loads(index_path.read_text(encoding="utf-8"))
        index["artifacts"].pop()
        index_path.write_text(json.dumps(index), encoding="utf-8")
        with self.assertRaisesRegex(checker.Refusal, "incomplete_or_excess_synthetic_artifacts"):
            checker.review(self.bundle, self.plan)
        self.rebuild_fixture()
        (self.bundle / "evidence" / "unindexed.txt").write_text(
            "SYNTHETIC PATCHSET3 EVIDENCE ONLY", encoding="ascii")
        with self.assertRaisesRegex(checker.Refusal, "unindexed_or_missing_synthetic_artifact"):
            checker.review(self.bundle, self.plan)

    def test_reused_digest_for_different_case_or_check_is_refused(self):
        p = self.bundle / "index.json"
        index = json.loads(p.read_text(encoding="utf-8"))
        index["artifacts"][1]["sha256"] = index["artifacts"][0]["sha256"]
        p.write_text(json.dumps(index), encoding="utf-8")
        with self.assertRaisesRegex(checker.Refusal, "incorrect_or_reused_synthetic_artifact_binding"):
            checker.review(self.bundle, self.plan)
        self.rebuild_fixture()
        index = json.loads(p.read_text(encoding="utf-8"))
        index["artifacts"][0]["file"] = "evidence/../other.txt"
        p.write_text(json.dumps(index), encoding="utf-8")
        with self.assertRaisesRegex(checker.Refusal, "incorrect_or_reused_synthetic_artifact_binding"):
            checker.review(self.bundle, self.plan)

    def test_swapped_order_and_forged_case_bindings_are_refused(self):
        p = self.bundle / "index.json"
        index = json.loads(p.read_text(encoding="utf-8"))
        index["artifacts"][0], index["artifacts"][1] = index["artifacts"][1], index["artifacts"][0]
        p.write_text(json.dumps(index), encoding="utf-8")
        with self.assertRaisesRegex(checker.Refusal, "incorrect_or_reused_synthetic_artifact_binding"):
            checker.review(self.bundle, self.plan)

    def test_changed_self_report_requires_new_matching_evidence_inventory(self):
        p = self.bundle / "report.json"
        record = json.loads(p.read_text(encoding="utf-8"))
        # Deliberately correct a valid PASS back to all NOT_TESTED to
        # illustrate stale binding even when the change is internally valid.
        record["valid_scenarios"][0]["outcome"] = "NOT_TESTED"
        for check in record["valid_scenarios"][0]["checks"]:
            check["status"] = "NOT_TESTED"
        p.write_text(json.dumps(record), encoding="utf-8")
        with self.assertRaisesRegex(checker.Refusal, "stale_or_coherently_unproven_bundle_binding"):
            checker.review(self.bundle, self.plan)

    def test_unknown_fields_and_duplicate_json_keys_are_refused(self):
        p = self.bundle / "index.json"
        doc = json.loads(p.read_text(encoding="utf-8"))
        doc["client_path"] = "C:\\Private\\Game"
        p.write_text(json.dumps(doc), encoding="utf-8")
        with self.assertRaisesRegex(checker.Refusal, "invalid_synthetic_evidence_index"):
            checker.review(self.bundle, self.plan)
        p.write_text('{"schema_version":1,"schema_version":2}', encoding="utf-8")
        with self.assertRaises(checker.drift.Refusal):
            checker.review(self.bundle, self.plan)

    def test_symlink_or_unexpected_file_does_not_escape_disposable_folder(self):
        outside = Path(self.temp.name) / "outside.txt"
        outside.write_text("OUTSIDE FAKE ONLY", encoding="ascii")
        target = self.bundle / "evidence" / "extra-link.txt"
        try:
            target.symlink_to(outside)
        except (OSError, NotImplementedError):
            self.skipTest("This Windows runner cannot create unprivileged symlinks")
        with self.assertRaisesRegex(checker.Refusal, "unindexed_or_missing_synthetic_artifact"):
            checker.review(self.bundle, self.plan)
        self.assertEqual(outside.read_text(encoding="ascii"), "OUTSIDE FAKE ONLY")

    def test_coherent_replay_passes_byte_checks_but_still_cannot_authenticate(self):
        first = checker.review(self.bundle, self.plan)
        # A malicious caller can reproduce everything in a second disposable
        # root, including marker/report/index and the complete fake evidence.
        duplicate = Path(self.temp.name) / "replayed"
        duplicate.mkdir()
        (duplicate / "evidence").mkdir()
        for entry in (self.bundle / checker.MARKER, self.bundle / "index.json",
                      self.bundle / "report.json"):
            (duplicate / entry.name).write_bytes(entry.read_bytes())
        for entry in (self.bundle / "evidence").iterdir():
            (duplicate / "evidence" / entry.name).write_bytes(entry.read_bytes())
        replay = checker.review(duplicate, self.plan)
        self.assertEqual(replay, first)
        self.assertFalse(replay["protection_against_coherent_replay"])
        self.assertFalse(replay["independent_custody_verified"])

    def test_cli_is_read_only_private_and_fixture_only(self):
        before = {p: p.read_bytes() for p in (
            PROPOSAL, RELEASES, ROOT / "config" / "client-patches.json",
            ROOT / "config" / "patch-versions" / "patchset-0001.json",
            ROOT / "config" / "patch-versions" / "patchset-0002.json",
        )}
        cli = [sys.executable, str(SOURCE), "--proposal", str(PROPOSAL),
               "--release-snapshot", str(RELEASES),
               "--synthetic-bundle", str(self.bundle)]
        result = subprocess.run(cli, capture_output=True, text=True, check=True)
        doc = json.loads(result.stdout)
        self.check_denied(doc)
        for secret in (str(self.bundle), str(ROOT), "2026-10-13",
                       "68ca0d260841", "Data/patch-V.mpq", "C:\\Private"):
            self.assertNotIn(secret, result.stdout)
        (self.bundle / checker.MARKER).unlink()
        blocked = subprocess.run(cli, capture_output=True, text=True)
        self.assertEqual(blocked.returncode, 2)
        self.assertTrue(blocked.stderr.startswith("BLOCKED:"))
        self.assertNotIn(str(self.bundle), blocked.stderr)
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)

    def test_an_unperformed_report_can_have_zero_fake_artifacts_and_not_prove_anything(self):
        self.record = checker.records.template(self.plan)
        self.rebuild_fixture()
        outcome = checker.review(self.bundle, self.plan)
        self.assertEqual(outcome["synthetic_artifact_count"], 0)
        self.assertEqual(outcome["self_reported_counts"]["not_tested"], 8)
        self.check_denied(outcome)


if __name__ == "__main__":
    unittest.main()
