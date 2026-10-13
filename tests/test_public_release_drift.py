#!/usr/bin/env python3
"""Purely local public metadata fixtures; no GitHub access or game files."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "review_public_release_drift.py"
FIXTURE = ROOT / "tests" / "fixtures" / "public-release-metadata-v1.json"
spec = importlib.util.spec_from_file_location("drift_review", SCRIPT)
assert spec is not None and spec.loader is not None
reviewer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reviewer)


class PublicReleaseDriftTests(unittest.TestCase):
    def setUp(self):
        self.snapshot = json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_all_real_reference_fixtures_match_without_approval(self):
        report = reviewer.review(self.snapshot)
        self.assertEqual(report["status"], "public_metadata_matches_pinned_reference_NOT_APPROVAL")
        self.assertEqual([x["id"] for x in report["items"]],
                         ["patch-v", "patch-z", "patch-j", "patch-c", "patch-u", "addon-suite"])
        self.assertTrue(all(x["status"] == "pinned_public_metadata_matches"
                            for x in report["items"]))
        for field in ("historical_pins_modified", "downloaded_binary_assets",
                      "client_files_accessed", "client_files_modified",
                      "backup_or_install_performed", "redistribution_approved",
                      "automatic_update_approved", "release_authorised"):
            self.assertFalse(report[field], field)
        self.assertNotIn("https://", json.dumps(report))

    def test_new_v_release_requires_manual_ref_review(self):
        s = copy.deepcopy(self.snapshot)
        s["patch_releases"].append({
            "tag_name": "v1.0.6.8.5", "published_at": "2026-10-13T15:00:00Z",
            "draft": False, "prerelease": False, "assets": [{
                "name": "patch-V.mpq", "size": 700000000, "digest": "sha256:" + "e" * 64}]})
        r = reviewer.review(s)
        self.assertEqual(r["status"], "manual_reference_review_required")
        self.assertEqual(r["items"][0]["observed_public_tag"], "v1.0.6.8.5")
        self.assertEqual(r["items"][1]["status"], "pinned_public_metadata_matches")
        self.assertFalse(r["automatic_update_approved"])

    def test_new_optional_c_does_not_demand_unrelated_j_u_update(self):
        s = copy.deepcopy(self.snapshot)
        s["patch_releases"].append({
            "tag_name": "optional-v2.0", "published_at": "2026-10-13T16:00:00Z",
            "draft": False, "prerelease": False, "assets": [{
                "name": "Patch-C.mpq", "size": 25000000, "digest": "sha256:" + "f" * 64}]})
        result = reviewer.review(s)
        self.assertEqual([x["id"] for x in result["items"]
                          if x["status"] == "public_reference_changed_manual_review"], ["patch-c"])
        self.assertEqual(result["items"][2]["status"], "pinned_public_metadata_matches")
        self.assertEqual(result["items"][4]["status"], "pinned_public_metadata_matches")

    def test_new_stable_addon_release_requires_manual_review(self):
        s = copy.deepcopy(self.snapshot)
        s["addon_releases"].insert(0, {
            "tag_name": "v2.1.0", "published_at": "2026-10-13T12:00:00Z",
            "draft": False, "prerelease": False, "assets": [{
                "name": "N-Addon-Collection-v2.1.0.zip",
                "size": 100000, "digest": "sha256:" + "d" * 64}]})
        r = reviewer.review(s)
        self.assertEqual(r["items"][-1]["status"], "public_reference_changed_manual_review")
        self.assertFalse(r["release_authorised"])

    def test_changed_asset_same_tag_must_not_be_silently_accepted(self):
        self.snapshot["patch_releases"][0]["assets"][0]["digest"] = "sha256:" + "a" * 64
        r = reviewer.review(self.snapshot)
        self.assertEqual(r["items"][0]["status"], "public_reference_changed_manual_review")
        self.assertFalse(r["redistribution_approved"])

    def test_prerelease_draft_and_unrelated_tags_not_used_as_stable_update(self):
        s = copy.deepcopy(self.snapshot)
        for tag, draft, prerelease in (
            ("v1.0.6.8.5-rc1", False, True),
            ("v1.0.6.8.6", True, False),
            ("optional-v3.0", True, False),
        ):
            s["patch_releases"].insert(0, {
                "tag_name": tag, "published_at": "2026-10-13T16:00:00Z",
                "draft": draft, "prerelease": prerelease,
                "assets": [{"name": "patch-V.mpq", "size": 3, "digest": "sha256:" + "0" * 64}]})
        self.assertEqual(reviewer.review(s)["status"], "public_metadata_matches_pinned_reference_NOT_APPROVAL")

    def test_lost_z_or_addon_asset_requires_manual_review(self):
        s = copy.deepcopy(self.snapshot)
        s["patch_releases"][-1]["assets"] = s["patch_releases"][-1]["assets"][:1]
        r = reviewer.review(s)
        self.assertEqual(r["items"][1]["status"], "missing_stable_published_asset")
        s = copy.deepcopy(self.snapshot)
        s["addon_releases"][0]["assets"] = []
        r = reviewer.review(s)
        self.assertEqual(r["items"][-1]["status"], "missing_stable_published_asset")

    def test_duplicate_asset_and_invalid_digest_refused(self):
        s = copy.deepcopy(self.snapshot)
        s["patch_releases"][0]["assets"].append(copy.deepcopy(s["patch_releases"][0]["assets"][0]))
        with self.assertRaisesRegex(reviewer.Refusal, "ambiguous_public_asset"):
            reviewer.review(s)
        s = copy.deepcopy(self.snapshot)
        s["patch_releases"][0]["assets"][0]["digest"] = "sha256:bad"
        with self.assertRaisesRegex(reviewer.Refusal, "missing_or_ambiguous_public_asset_digest"):
            reviewer.review(s)

    def test_truncated_or_wrongly_shaped_snapshots_refused(self):
        for change in (
            {"patch_releases": self.snapshot["patch_releases"]},
            {"patch_releases": [], "addon_releases": self.snapshot["addon_releases"]},
            {"patch_releases": self.snapshot["patch_releases"], "addon_releases": []},
        ):
            with self.assertRaises(reviewer.Refusal):
                reviewer.review(change)

    def test_no_arbitrary_external_urls(self):
        with self.assertRaisesRegex(reviewer.Refusal, "unapproved_release_endpoint"):
            reviewer._live("https://example.com/private")
        with self.assertRaisesRegex(reviewer.Refusal, "unapproved_release_endpoint"):
            reviewer._live("https://api.github.com/repos/SomeOtherOrg/repo/releases")

    def test_cli_read_only_and_no_paths_or_hashes_leaked(self):
        command = [sys.executable, str(SCRIPT), "--snapshot", str(FIXTURE)]
        p = subprocess.run(command, capture_output=True, text=True, check=True)
        report = json.loads(p.stdout)
        self.assertEqual(report["status"], "public_metadata_matches_pinned_reference_NOT_APPROVAL")
        self.assertNotIn(str(ROOT), p.stdout)
        self.assertNotIn("68ca0d260841", p.stdout)
        self.assertNotIn("CLIENT", p.stdout)
        self.assertFalse(report["client_files_modified"])
        self.assertFalse(report["release_authorised"])


if __name__ == "__main__":
    unittest.main()
