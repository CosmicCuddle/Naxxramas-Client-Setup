#!/usr/bin/env python3
"""Disposable FAKE Data files only. Never scans actual WoW installations."""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
SCRIPT = ROOT / "tools" / "review_disposable_test_client.py"
spec = importlib.util.spec_from_file_location("client_preflight", SCRIPT)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

FAKE_PAYLOAD = {
    "V": b"FAKE V PATCH ONLY\n" * 3,
    "Z": b"FAKE Z PATCH ONLY\n" * 3,
    "J": b"FAKE J PATCH ONLY\n" * 3,
    "C": b"FAKE C PATCH ONLY\n" * 3,
    "U": b"FAKE U PATCH ONLY\n" * 3,
}
PATHS = [("V", "patch-V.mpq", True), ("Z", "patch-Z.mpq", True),
         ("J", "Patch-J.mpq", False), ("C", "Patch-C.mpq", False),
         ("U", "Patch-U.mpq", False)]
FAKE_POLICY = [
    {"path": "Data/" + name, "required": required,
     "sha256": hashlib.sha256(FAKE_PAYLOAD[code]).hexdigest(),
     "size_bytes": len(FAKE_PAYLOAD[code])}
    for code, name, required in PATHS
]
UNTRUSTED_FLAGS = (
    "independently_proven_separate_test_client",
    "wow_335a_build_12340_authenticated",
    "source_publisher_or_actual_gameplay_verified",
    "independent_original_client_baseline_verified",
    "physical_windows_accessibility_tested",
    "privacy_safe_gameplay_evidence_captured",
    "client_or_wtf_modified", "installer_or_backup_or_restore_performed",
    "patchset_or_manifest_written", "installation_authorised",
    "redistribution_authorised", "public_release_authorised",
    "private_paths_player_data_or_raw_hashes_emitted",
)


class ClientPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="FAKE-WOW-CLIENT-PREFLIGHT-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "disposable"
        self.root.mkdir()
        (self.root / mod.MARKER).write_bytes(mod.MARKER_CONTENT)
        (self.root / "Wow.exe").write_bytes(b"FAKE EXE not a game\n")
        (self.root / "Data" / "enUS").mkdir(parents=True)
        self.data = self.root / "Data"
        self.private = self.root / "WTF" / "Account" / "SUPER-PRIVATE"
        self.private.mkdir(parents=True)
        self.secret = self.private / "SavedVariables.lua"
        self.secret.write_bytes(b"NEVER READ PRIVATE SETTINGS\n")
        self.snap_secret = self.secret.read_bytes()

    def install_fake(self, *codes):
        for code, filename, _ in PATHS:
            file = self.data / filename
            if code in codes:
                file.write_bytes(FAKE_PAYLOAD[code])
            elif file.exists() or file.is_symlink():
                file.unlink()

    def assert_denied(self, result):
        self.assertTrue(result["marker_claims_disposable_not_authenticated"])
        self.assertTrue(result["fixture_policy_used_for_test_only"])
        for key in UNTRUSTED_FLAGS:
            self.assertFalse(result[key], key)
        self.assertNotIn(str(self.root), json.dumps(result))
        self.assertNotIn("SUPER-PRIVATE", json.dumps(result))
        self.assertNotIn("SavedVariables", json.dumps(result))
        self.assertNotIn(FAKE_POLICY[0]["sha256"], json.dumps(result))
        self.assertEqual(self.secret.read_bytes(), self.snap_secret)

    def test_all_six_valid_combinations_match_fake_reference_without_game_approval(self):
        self.assertEqual(len(mod.OPTIONS), 6)
        for case_id, optional in mod.OPTIONS.items():
            with self.subTest(case=case_id):
                self.install_fake("V", "Z", *optional)
                result = mod.inspect(self.root, FAKE_POLICY, case_id, fixture_policy=True)
                self.assertEqual(result["status"],
                                 "LOCAL_SELECTED_PATCH_BYTES_MATCH_REFERENCE_NOT_GAME_VERIFICATION")
                self.assertEqual(result["declared_optional_selection"], case_id)
                self.assertEqual(result["unknown_patch_mpq_count"], 0)
                self.assertTrue(result["selected_patch_metadata_consistent"])
                self.assertTrue(result["optional_selection_physically_clean"])
                self.assertEqual([x["patch_id"] for x in result["patch_results"]],
                                 ["V", "Z", "J", "C", "U"])
                for row in result["patch_results"]:
                    if row["selected_in_claimed_scenario"]:
                        self.assertEqual(row["local_metadata"],
                                         "MATCHES_PINNED_SHA256_AND_SIZE_NOT_PROVENANCE")
                    else:
                        self.assertEqual(row["local_metadata"], "NOT_PRESENT")
                self.assert_denied(result)

    def test_j_u_has_explicit_loading_art_overlap_warning(self):
        self.install_fake("V", "Z", "J", "U")
        result = mod.inspect(self.root, FAKE_POLICY, "j-u", fixture_policy=True)
        self.assertIn("j_u_loading_texture_overlap_requires_in_game_review",
                      result["warning_codes"])
        self.assert_denied(result)

    def test_missing_required_v_z_and_selected_optional_fails(self):
        for case_id, installed in (
            ("base", ("Z",)),
            ("base", ("V",)),
            ("j", ("V", "Z")),
            ("c", ("V", "Z")),
            ("u", ("V", "Z")),
        ):
            with self.subTest(case=case_id, installed=installed):
                self.install_fake(*installed)
                result = mod.inspect(self.root, FAKE_POLICY, case_id, fixture_policy=True)
                self.assertEqual(result["status"], "MANUAL_TEST_CLIENT_REVIEW_REQUIRED")
                self.assertFalse(result["selected_patch_metadata_consistent"])
                self.assertIn("selected_patch_missing_or_metadata_mismatch", result["warning_codes"])
                self.assert_denied(result)

    def test_unselected_present_optional_is_never_a_clean_scenario(self):
        for requested, extras in (
            ("base", ("J",)),
            ("base", ("C",)),
            ("u", ("J",)),
            ("j", ("C",)),
            ("c", ("J",)),
            ("c", ("U",)),
        ):
            with self.subTest(requested=requested, extras=extras):
                self.install_fake("V", "Z", *mod.OPTIONS[requested], *extras)
                result = mod.inspect(self.root, FAKE_POLICY, requested, fixture_policy=True)
                self.assertEqual(result["status"], "MANUAL_TEST_CLIENT_REVIEW_REQUIRED")
                self.assertTrue(result["selected_patch_metadata_consistent"])
                self.assertFalse(result["optional_selection_physically_clean"])
                self.assertIn("unselected_optional_patch_physically_present", result["warning_codes"])
                self.assert_denied(result)

    def test_same_size_changed_bytes_still_fail_sha256(self):
        self.install_fake("V", "Z")
        (self.data / "patch-V.mpq").write_bytes(b"x" * len(FAKE_PAYLOAD["V"]))
        result = mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        self.assertEqual(result["patch_results"][0]["local_metadata"], "SHA256_MISMATCH")
        self.assertEqual(result["status"], "MANUAL_TEST_CLIENT_REVIEW_REQUIRED")
        self.assert_denied(result)

    def test_wrong_size_and_unrecognised_patch_file(self):
        self.install_fake("V", "Z")
        (self.data / "patch-V.mpq").write_bytes(b"wrong size")
        (self.data / "patch-X.mpq").write_bytes(b"Unknown fake patch bytes")
        result = mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        self.assertEqual(result["patch_results"][0]["local_metadata"], "SIZE_MISMATCH")
        self.assertEqual(result["unknown_patch_mpq_count"], 1)
        self.assertIn("unrecognised_patch_mpq_in_Data", result["warning_codes"])
        self.assert_denied(result)

    def test_game_executable_and_locale_presence_do_not_prove_build(self):
        self.install_fake("V", "Z")
        (self.root / "Wow.exe").unlink()
        (self.data / "enUS").rmdir()
        result = mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        self.assertEqual(result["status"], "MANUAL_TEST_CLIENT_REVIEW_REQUIRED")
        self.assertFalse(result["wow_exe_present_not_build_verified"])
        self.assertFalse(result["enUS_folder_present_not_locale_verified"])
        self.assertFalse(result["wow_335a_build_12340_authenticated"])
        self.assert_denied(result)

    def test_missing_or_forged_marker_is_refused(self):
        self.install_fake("V", "Z")
        marker = self.root / mod.MARKER
        marker.unlink()
        with self.assertRaisesRegex(mod.Refusal, "missing_or_unsafe_disposable_marker"):
            mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        marker.write_bytes(b"NOT AN AUTHORITY")
        with self.assertRaisesRegex(mod.Refusal, "missing_or_unsafe_disposable_marker|disposable_marker_content_not_trusted"):
            mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)

    def test_symlinked_data_patch_or_locale_is_rejected(self):
        self.install_fake("V", "Z")
        original = self.data / "patch-Z.mpq"
        external = Path(self.temp.name) / "external-FAKE.txt"
        external.write_bytes(FAKE_PAYLOAD["Z"])
        original.unlink()
        try:
            original.symlink_to(external)
        except (OSError, NotImplementedError):
            self.skipTest("Symlink privilege unavailable on this Windows runner")
        with self.assertRaisesRegex(mod.Refusal, "linked_disposable_client_path"):
            mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        self.assertEqual(external.read_bytes(), FAKE_PAYLOAD["Z"])

    def test_hardlinked_patch_is_not_allowed(self):
        self.install_fake("V", "Z")
        existing = self.data / "patch-V.mpq"
        ext = Path(self.temp.name) / "other-hardlinked-fake.txt"
        try:
            os.link(existing, ext)
        except (OSError, NotImplementedError):
            self.skipTest("Hard links unavailable on this CI filesystem")
        result = mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        self.assertEqual(result["patch_results"][0]["local_metadata"], "UNSAFE_FILE_TYPE_OR_LINK")
        self.assert_denied(result)

    def test_colliding_filename_case_or_malformed_policy_refused(self):
        self.install_fake("V", "Z")
        (self.data / "PATCH-J.MPQ").write_bytes(FAKE_PAYLOAD["J"])
        with self.assertRaisesRegex(mod.Refusal, "unexpected_patch_filename_case"):
            mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        (self.data / "PATCH-J.MPQ").unlink()
        altered = [dict(row) for row in FAKE_POLICY]
        altered[0]["sha256"] = "NOT-A-HASH"
        with self.assertRaisesRegex(mod.Refusal, "invalid_expected_patch_policy"):
            mod.inspect(self.root, altered, "base", fixture_policy=True)

    def test_unknown_selection_c_j_simultaneously_cannot_be_expressed(self):
        self.install_fake("V", "Z", "J", "C")
        self.assertNotIn("j-c", mod.OPTIONS)
        self.assertNotIn("j-c-u", mod.OPTIONS)
        with self.assertRaisesRegex(mod.Refusal, "unknown_optional_patch_selection"):
            mod.inspect(self.root, FAKE_POLICY, "j-c", fixture_policy=True)
        result = mod.inspect(self.root, FAKE_POLICY, "j", fixture_policy=True)
        self.assertEqual(result["status"], "MANUAL_TEST_CLIENT_REVIEW_REQUIRED")
        self.assert_denied(result)

    def test_wtf_directory_contents_are_not_enumerated_or_opened(self):
        self.install_fake("V", "Z")
        real_scandir = os.scandir
        def guard(path):
            if "WTF" in str(path) or "Account" in str(path):
                raise AssertionError("NEVER scan private WTF")
            return real_scandir(path)
        with mock.patch.object(mod.os, "scandir", side_effect=guard):
            result = mod.inspect(self.root, FAKE_POLICY, "base", fixture_policy=True)
        self.assert_denied(result)

    def test_cli_only_reads_marker_and_real_pinned_policy_without_mutating_fixture(self):
        self.install_fake("V", "Z")
        before = {p: p.read_bytes() for p in [
            self.root / mod.MARKER, self.root / "Wow.exe",
            self.data / "patch-V.mpq", self.data / "patch-Z.mpq",
            self.secret, ROOT / "config" / "client-patches.json",
            ROOT / "config" / "patch-versions" / "patchset-0001.json",
            ROOT / "config" / "patch-versions" / "patchset-0002.json"]}
        cli = [sys.executable, str(SCRIPT),
               "--test-root", str(self.root), "--selection", "base"]
        output = subprocess.run(cli, capture_output=True, text=True)
        self.assertEqual(output.returncode, 3, output.stderr)
        result = json.loads(output.stdout)
        self.assertEqual(result["status"], "MANUAL_TEST_CLIENT_REVIEW_REQUIRED")
        self.assertFalse(result["fixture_policy_used_for_test_only"])
        self.assertNotIn(str(self.root), output.stdout)
        self.assertNotIn("SUPER-PRIVATE", output.stdout)
        self.assertNotIn("68ca0d260841", output.stdout)
        self.assertFalse(result["installation_authorised"])
        for p, val in before.items():
            self.assertEqual(p.read_bytes(), val)
        (self.root / mod.MARKER).unlink()
        fail = subprocess.run(cli, capture_output=True, text=True)
        self.assertEqual(fail.returncode, 2)
        self.assertTrue(fail.stderr.startswith("BLOCKED:"))
        self.assertNotIn(str(self.root), fail.stderr)


if __name__ == "__main__":
    unittest.main()
