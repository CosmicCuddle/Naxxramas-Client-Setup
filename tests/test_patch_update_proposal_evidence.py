#!/usr/bin/env python3
"""Only fake proposal/release metadata; no real WoW or MPQ access."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))
SOURCE = TOOLS / "review_patch_update_proposal.py"
PROPOSAL = ROOT / "tests" / "fixtures" / "synthetic-patch-proposal-v3.json"
RELEASES = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("patch_proposal_review", SOURCE)
assert spec is not None and spec.loader is not None
reviewer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reviewer)


class PatchProposalEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.proposal = json.loads(PROPOSAL.read_text(encoding="utf-8"))
        self.releases = json.loads(RELEASES.read_text(encoding="utf-8"))

    def synthetic_new_published_v(self):
        value = copy.deepcopy(self.releases)
        value["patch_releases"].insert(0, {
            "tag_name": "v1.0.6.8.5",
            "published_at": "2026-10-13T16:00:00Z",
            "draft": False, "prerelease": False,
            "assets": [{
                "name": "patch-V.mpq", "size": 700000000,
                "digest": "sha256:" + "e" * 64
            }],
        })
        return value

    def test_matching_hypothetical_new_public_release_still_never_authorises(self):
        result = reviewer.review(self.proposal, self.synthetic_new_published_v())
        self.assertEqual(result["status"], "manual_review_required_NO_INSTALL_AUTHORITY")
        self.assertEqual(result["base_patchset"], "patchset-0002")
        self.assertEqual(result["hypothetical_next_patchset"], "patchset-0003_NOT_CREATED")
        self.assertEqual(result["checked_count"], 5)
        self.assertEqual(result["changed_count"], 1)
        self.assertEqual(result["items"][0]["status"], "changed_bytes_match_public_release_metadata_NOT_APPROVAL")
        self.assertEqual(result["items"][1]["status"], "matches_current_pinned_bytes_only")
        self.assertIn("optional_c_j_both_present_login_mutex_requires_review", result["warnings"])
        self.assertIn("optional_j_u_loading_texture_overlap_requires_review", result["warnings"])
        for name in (
            "proposal_content_authenticated", "publisher_authenticated",
            "published_digest_independently_rehashed", "immutable_history_independently_protected",
            "original_client_or_settings_read", "original_client_or_settings_modified",
            "manifest_or_patchset_modified", "new_patchset_created",
            "gameplay_compatibility_verified", "backup_or_restore_performed",
            "installation_authorised", "redistribution_authorised", "public_release_authorised",
            "private_paths_hashes_or_timestamps_reported",
        ):
            self.assertFalse(result[name], name)
        content = json.dumps(result)
        for forbidden in ("e" * 64, "5eb17ce5dc7b", "2026-10-13T15:", "Wow.exe"):
            self.assertNotIn(forbidden, content)

    def test_unknown_hash_never_treated_as_a_release_reference(self):
        result = reviewer.review(self.proposal, self.releases)
        self.assertEqual(result["items"][0]["status"], "new_bytes_not_in_latest_public_release_metadata")
        self.assertEqual(result["status"], "manual_review_required_NO_INSTALL_AUTHORITY")
        self.assertFalse(result["installation_authorised"])

    def test_old_base_and_wrong_future_version_refuse(self):
        for key, value in (
            ("base_patch_set_revision", 1),
            ("base_patch_set_revision", True),
            ("proposed_patch_set_revision", 4),
            ("proposed_patch_set_version", "patchset-0004"),
            ("created_utc", "not a date"),
            ("proposal_schema_version", 2),
            ("kind", "approved"),
        ):
            with self.subTest(key=key):
                p = copy.deepcopy(self.proposal)
                p[key] = value
                with self.assertRaisesRegex(reviewer.Refusal, "stale_or_untrusted_proposal_base"):
                    reviewer.review(p, self.releases)

    def test_missing_z_or_duplicate_casefold_path_refuses(self):
        p = copy.deepcopy(self.proposal)
        p["files_checked"].pop(1)
        with self.assertRaisesRegex(reviewer.Refusal, "required_patch_not_checked"):
            reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["files_checked"].append(copy.deepcopy(p["files_checked"][-1]))
        with self.assertRaisesRegex(reviewer.Refusal, "ambiguous_or_untrusted_checked_file"):
            reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["files_checked"][1]["path"] = "data/PATCH-z.mpq"
        with self.assertRaisesRegex(reviewer.Refusal, "ambiguous_or_untrusted_checked_file"):
            reviewer.review(p, self.releases)

    def test_changed_claim_contradicting_actual_bytes_refuses(self):
        p = copy.deepcopy(self.proposal)
        p["files_checked"][0]["changed"] = False
        with self.assertRaisesRegex(reviewer.Refusal, "proposal_change_flag_contradicts_pinned_bytes"):
            reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["files_checked"][1]["sha256"] = "a" * 64
        with self.assertRaisesRegex(reviewer.Refusal, "proposal_change_flag_contradicts_pinned_bytes"):
            reviewer.review(p, self.releases)

    def test_before_after_and_missing_change_claims_refused(self):
        for key, value in (
            ("previous_sha256", "0" * 64),
            ("previous_size_bytes", 23),
            ("new_sha256", "0" * 64),
            ("new_size_bytes", 42),
        ):
            with self.subTest(key=key):
                p = copy.deepcopy(self.proposal)
                p["changes"][0][key] = value
                with self.assertRaisesRegex(reviewer.Refusal, "proposal_before_after_evidence_inconsistent"):
                    reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["changes"] = []
        with self.assertRaisesRegex(reviewer.Refusal, "missing_or_unbounded_proposal_files"):
            reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["changes"].append(copy.deepcopy(p["changes"][0]))
        with self.assertRaisesRegex(reviewer.Refusal, "duplicate_or_unobserved_change"):
            reviewer.review(p, self.releases)

    def test_unknown_fields_and_private_paths_refused(self):
        p = copy.deepcopy(self.proposal)
        p["client_path"] = "C:\\Users\\Something\\World of Warcraft"
        with self.assertRaisesRegex(reviewer.Refusal, "unrecognised_proposal_schema"):
            reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["files_checked"][0]["path"] = "../Data/private.mpq"
        with self.assertRaisesRegex(reviewer.Refusal, "ambiguous_or_untrusted_checked_file"):
            reviewer.review(p, self.releases)
        p = copy.deepcopy(self.proposal)
        p["files_checked"][0]["account"] = "private-name"
        with self.assertRaisesRegex(reviewer.Refusal, "unexpected_checked_file_fields"):
            reviewer.review(p, self.releases)

    def test_optional_patch_absence_is_not_a_required_file_failure(self):
        p = copy.deepcopy(self.proposal)
        p["files_checked"] = p["files_checked"][:2]
        result = reviewer.review(p, self.synthetic_new_published_v())
        self.assertEqual(result["checked_count"], 2)
        self.assertEqual(result["warnings"], [])
        self.assertFalse(result["new_patchset_created"])

    def test_either_optional_c_or_j_with_u_does_not_claim_login_mutex_violation(self):
        for absent in ("Data/Patch-C.mpq", "Data/Patch-J.mpq"):
            with self.subTest(absent=absent):
                p = copy.deepcopy(self.proposal)
                p["files_checked"] = [x for x in p["files_checked"] if x["path"] != absent]
                result = reviewer.review(p, self.synthetic_new_published_v())
                self.assertNotIn("optional_c_j_both_present_login_mutex_requires_review",
                                 result["warnings"])

    def test_stale_or_forged_historical_patch_record_detected_in_disposable_copy(self):
        with tempfile.TemporaryDirectory(prefix="FAKE-Historical-") as folder:
            dest = Path(folder)
            for version in (1, 2):
                name = "patchset-%04d.json" % version
                (dest / name).write_bytes((reviewer.HISTORY_DIR / name).read_bytes())
            original = (dest / "patchset-0001.json").read_bytes()
            (dest / "patchset-0001.json").write_bytes(original + b"\n")
            with mock.patch.object(reviewer, "HISTORY_DIR", dest):
                with self.assertRaisesRegex(reviewer.Refusal, "historical_patchset_changed_from_reviewed_baseline"):
                    reviewer.review(self.proposal, self.releases)
            # Source history remains untouched.
            self.assertEqual((reviewer.HISTORY_DIR / "patchset-0001.json").read_bytes(), original)

    def test_source_manifest_drift_detected_against_disposable_copy(self):
        with tempfile.TemporaryDirectory(prefix="FAKE-Manifest-") as folder:
            fake = Path(folder) / "client-patches.json"
            c = json.loads(reviewer.CURRENT.read_text(encoding="utf-8"))
            c["patches"][0]["sha256"] = "b" * 64
            fake.write_text(json.dumps(c), encoding="utf-8")
            with mock.patch.object(reviewer, "CURRENT", fake):
                with self.assertRaisesRegex(reviewer.Refusal, "current_manifest_does_not_match_frozen_base"):
                    reviewer.review(self.proposal, self.releases)

    def test_duplicate_json_keys_and_malformed_length_refuse_without_path_leak(self):
        with tempfile.TemporaryDirectory(prefix="FAKE-Proposal-") as folder:
            p = Path(folder) / "proposal.json"
            p.write_text('{"kind":"review_only_not_published","kind":"approved"}')
            with self.assertRaisesRegex(reviewer.drift.Refusal, "duplicate_json_key"):
                reviewer._load(p)
            p.write_bytes(b"x" * (reviewer.MAX_PROPOSAL + 1))
            with self.assertRaisesRegex(reviewer.Refusal, "unsafe_or_oversized_local_json"):
                reviewer._load(p)

    def test_cli_reports_only_public_identifiers_not_proposed_hashes_or_paths(self):
        before = PROPOSAL.read_bytes()
        result = subprocess.run(
            [sys.executable, str(SOURCE), "--proposal", str(PROPOSAL),
             "--release-snapshot", str(RELEASES)],
            text=True, capture_output=True, check=True,
        )
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "manual_review_required_NO_INSTALL_AUTHORITY")
        self.assertNotIn(str(ROOT), result.stdout)
        self.assertNotIn("e" * 64, result.stdout)
        self.assertEqual(before, PROPOSAL.read_bytes())


if __name__ == "__main__":
    unittest.main()
