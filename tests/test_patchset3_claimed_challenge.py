#!/usr/bin/env python3
"""Synthetic authority-claim sequence tests; no real authentication or game I/O."""
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
FILE = ROOT / "tools" / "model_patchset3_evidence_challenge.py"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASE = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("claimed_challenge", FILE)
assert spec and spec.loader
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class ChallengeModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.plan = tool.planner.make_plan(
            json.loads(PROPOSAL.read_text(encoding="utf-8")),
            json.loads(RELEASE.read_text(encoding="utf-8")))

    def setUp(self):
        self.claim = {
            "schema_version": 1,
            "kind": tool.KIND,
            "plan_sha256": tool.record.fingerprint(self.plan),
            "fixture_scope": "disposable_335a_enUS_source_only",
            "authority_epoch_claim": 7,
            "events": [
                {"action": "issue", "at": 1800000000,
                 "actor": "issuer_01", "challenge_id": "fake_nonce_01",
                 "expires_at": 1800000300},
                {"action": "submit", "at": 1800000010,
                 "actor": "tester_01", "challenge_id": "fake_nonce_01",
                 "plan_sha256": tool.record.fingerprint(self.plan),
                 "bundle_claim_sha256": "c" * 64},
                {"action": "review", "at": 1800000020,
                 "actor": "reviewer_01", "challenge_id": "fake_nonce_01",
                 "verdict": "claims_consistent"},
                {"action": "consume", "at": 1800000025,
                 "actor": "issuer_01", "challenge_id": "fake_nonce_01"},
            ],
        }

    def denied(self, result):
        self.assertEqual(result["kind"], "patchset3_claimed_challenge_lifecycle_review")
        for field in (
            "claimed_authority_epoch_is_trusted", "claimed_clock_is_trusted",
            "challenge_nonce_independently_issued",
            "reviewer_or_tester_identity_authenticated",
            "signature_or_protected_key_verified",
            "external_monotonic_consumption_record_checked",
            "coherent_replay_prevented", "actual_bundle_bytes_verified",
            "actual_gameplay_or_accessibility_observed",
            "source_provenance_or_rights_cleared",
            "real_client_or_wtf_read_or_modified",
            "real_backup_or_recovery_performed", "patchset_or_manifest_written",
            "installation_authorised", "redistribution_authorised",
            "public_release_authorised", "private_actor_nonce_hash_or_time_disclosed",
        ):
            self.assertIs(result[field], False, field)
        for private in ("issuer_01", "tester_01", "reviewer_01",
                        "fake_nonce_01", "1800000000", "ccccccc", str(ROOT)):
            self.assertNotIn(private, json.dumps(result))

    def test_completed_claimed_sequence_is_never_authenticated(self):
        r = tool.simulate(self.claim, self.plan)
        self.assertEqual(r["status"], "SIMULATED_CLAIMS_CONSISTENT_NOT_AUTHENTICATED")
        self.assertEqual(r["phase"], "consumed")
        self.assertTrue(r["claimed_roles_separated_by_labels"])
        self.assertEqual(r["public_event_types"], ["issue", "submit", "review", "consume"])
        self.denied(r)

    def test_complete_coherent_replay_and_epoch_rollback_still_look_consistent(self):
        first = tool.simulate(self.claim, self.plan)
        copied = copy.deepcopy(self.claim)
        second = tool.simulate(copied, self.plan)
        self.assertEqual(second, first)
        copied["authority_epoch_claim"] = 1
        rolled_back = tool.simulate(copied, self.plan)
        self.assertEqual(rolled_back["phase"], "consumed")
        self.assertFalse(rolled_back["external_monotonic_consumption_record_checked"])
        self.assertFalse(rolled_back["coherent_replay_prevented"])
        self.denied(rolled_back)

    def test_repeated_issue_submit_review_consume_refused_within_single_timeline(self):
        for step, expected in [
            (0, "duplicate_or_replayed_challenge_issue"),
            (1, "duplicate_or_out_of_order_submission"),
            (2, "review_out_of_order_or_replayed"),
            (3, "consume_out_of_order_or_replayed"),
        ]:
            with self.subTest(step=step):
                fake = copy.deepcopy(self.claim)
                event = copy.deepcopy(fake["events"][step])
                # Replaying an event after the same step, with nondecreasing
                # claimed clock, must be refused.
                fake["events"].insert(step + 1, event)
                with self.assertRaisesRegex(tool.Refusal, expected):
                    tool.simulate(fake, self.plan)

    def test_bad_order_missing_issue_wrong_nonce_or_plan(self):
        s = copy.deepcopy(self.claim)
        s["events"].pop(0)
        with self.assertRaisesRegex(tool.Refusal, "missing_or_foreign_challenge"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][1]["challenge_id"] = "foreign_1234"
        with self.assertRaisesRegex(tool.Refusal, "missing_or_foreign_challenge"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][1]["plan_sha256"] = "d" * 64
        with self.assertRaisesRegex(tool.Refusal, "tester_separation_or_bundle_claim_invalid"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["plan_sha256"] = "e" * 64
        with self.assertRaisesRegex(tool.Refusal, "untrusted_plan_scope_or_epoch_claim"):
            tool.simulate(s, self.plan)

    def test_expiry_and_clock_rollback_refused(self):
        s = copy.deepcopy(self.claim)
        s["events"][1]["at"] = 1800000400
        s["events"][2]["at"] = 1800000410
        s["events"][3]["at"] = 1800000420
        with self.assertRaisesRegex(tool.Refusal, "expired_claimed_challenge"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][2]["at"] = 1800000001
        with self.assertRaisesRegex(tool.Refusal, "claimed_clock_rollback_or_invalid_time"):
            tool.simulate(s, self.plan)
        for expiry in (1799999999, 1800000000, 1800004000, True):
            with self.subTest(expiry=expiry):
                s = copy.deepcopy(self.claim)
                s["events"][0]["expires_at"] = expiry
                with self.assertRaisesRegex(tool.Refusal, "invalid_claimed_challenge_lifetime"):
                    tool.simulate(s, self.plan)

    def test_claimed_role_collusion_rejected_but_identity_not_authenticated(self):
        for idx, actor in ((1, "issuer_01"), (2, "issuer_01"), (2, "tester_01")):
            with self.subTest(idx=idx, actor=actor):
                s = copy.deepcopy(self.claim)
                s["events"][idx]["actor"] = actor
                label = ("tester_separation_or_bundle_claim_invalid" if idx == 1
                         else "reviewer_separation_or_claim_invalid")
                with self.assertRaisesRegex(tool.Refusal, label):
                    tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][3]["actor"] = "reviewer_01"
        with self.assertRaisesRegex(tool.Refusal, "claimed_issuer_not_consistent"):
            tool.simulate(s, self.plan)

    def test_revoked_or_disputed_claim_never_consumes(self):
        s = copy.deepcopy(self.claim)
        s["events"][2] = {"action": "revoke", "at": 1800000020,
                          "actor": "issuer_01", "challenge_id": "fake_nonce_01"}
        s["events"] = s["events"][:3]
        r = tool.simulate(s, self.plan)
        self.assertEqual(r["phase"], "revoked")
        self.denied(r)
        s["events"].append({"action": "consume", "at": 1800000025,
                            "actor": "issuer_01", "challenge_id": "fake_nonce_01"})
        with self.assertRaisesRegex(tool.Refusal, "consume_out_of_order_or_replayed"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][2]["verdict"] = "claims_disputed"
        s["events"] = s["events"][:3]
        self.assertEqual(tool.simulate(s, self.plan)["phase"], "reviewed_disputed")
        s["events"].append({"action": "consume", "at": 1800000025,
                            "actor": "issuer_01", "challenge_id": "fake_nonce_01"})
        with self.assertRaisesRegex(tool.Refusal, "consume_out_of_order_or_replayed"):
            tool.simulate(s, self.plan)

    def test_invalid_or_zero_bundle_claim_refused(self):
        for digest in ("0" * 64, "BAD", None, "a" * 65):
            with self.subTest(digest=digest):
                s = copy.deepcopy(self.claim)
                s["events"][1]["bundle_claim_sha256"] = digest
                with self.assertRaisesRegex(tool.Refusal, "tester_separation_or_bundle_claim_invalid"):
                    tool.simulate(s, self.plan)

    def test_unexpected_fields_private_paths_and_wrong_epoch_refused(self):
        s = copy.deepcopy(self.claim)
        s["user_path"] = "C:\\Users\\Private\\WoW"
        with self.assertRaisesRegex(tool.Refusal, "invalid_claimed_timeline_schema"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][0]["secret_key"] = "plaintext"
        with self.assertRaisesRegex(tool.Refusal, "unrecognised_challenge_event"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["authority_epoch_claim"] = True
        with self.assertRaisesRegex(tool.Refusal, "untrusted_plan_scope_or_epoch_claim"):
            tool.simulate(s, self.plan)
        s = copy.deepcopy(self.claim)
        s["events"][2]["actor"] = "C:\\Private\\account"
        with self.assertRaisesRegex(tool.Refusal, "unsafe_or_missing_claimed_actor_or_challenge"):
            tool.simulate(s, self.plan)

    def test_cli_stays_read_only_and_never_discloses_source_claims(self):
        before = {p: p.read_bytes() for p in (
            PROPOSAL, RELEASE,
            ROOT / "config" / "client-patches.json",
            ROOT / "config" / "patch-versions" / "patchset-0001.json",
            ROOT / "config" / "patch-versions" / "patchset-0002.json")}
        with tempfile.TemporaryDirectory(prefix="FAKE-CLAIMED-AUTHORITY-") as dirname:
            f = Path(dirname) / "timeline.json"
            f.write_text(json.dumps(self.claim), encoding="utf-8")
            args = [sys.executable, str(FILE), "--proposal", str(PROPOSAL),
                    "--release-snapshot", str(RELEASE), "--timeline", str(f)]
            good = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(good.returncode, 0, good.stderr)
            self.denied(json.loads(good.stdout))
            self.assertNotIn(str(f), good.stdout)
            self.assertNotIn("fake_nonce_01", good.stdout)
            f.write_text("{not json", encoding="utf-8")
            bad = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(bad.returncode, 2)
            self.assertTrue(bad.stderr.startswith("BLOCKED:"))
            self.assertNotIn(str(f), bad.stderr)
            f.write_text('{"schema_version":1,"schema_version":2}', encoding="utf-8")
            duplicate = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(duplicate.returncode, 2)
            self.assertNotIn(str(f), duplicate.stderr)
        for p, data in before.items():
            self.assertEqual(p.read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
