#!/usr/bin/env python3
"""Disposable fake-client storage fixtures only; production reviewer never writes."""
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

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS))
SCRIPT = TOOLS / "review_synthetic_addon_backup_storage.py"
spec = importlib.util.spec_from_file_location("synthetic_storage", SCRIPT)
assert spec and spec.loader
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
import review_synthetic_addon_recovery as integrity


class SyntheticBackupStorageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="NaxxBackupStorage-FAKE-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / integrity.MARKER).write_bytes(integrity.MARKER_BYTES)
        (self.root / tool.MARKER).write_bytes(tool.MARKER_BYTES)
        for area in integrity.SNAPSHOTS:
            (self.root / area).mkdir()
            for name, raw in {
                "Interface/AddOns/NCore/NCore.toc": b"## Interface: 30300\n",
                "Interface/AddOns/NCore/Custom.lua": b"DO NOT DELETE PLAYER LUA",
                "Interface/AddOns/MultiBot/CustomSettings.dat": b"UNTRACKED CUSTOM MOD",
                "Interface/AddOns/NClassicBattlegrounds/Old.lua": b"LEGACY ADDON",
                "WTF/Config.wtf": b"FAKE USER CONFIG",
                "WTF/Account/ACCT_ONE/Realm1/A/SavedVariables/MultiBot.lua": b"CHARACTER1 SETTINGS",
                "WTF/Account/ACCT_TWO/Realm2/B/SavedVariables/Other.lua": b"CHARACTER2 SETTINGS",
                "Interface/AddOns/OtherPersonalAddon/Private.lua": b"UNRELATED ADDON",
            }.items():
                self.write(area, name, raw)
        (self.root / "outside-client-sentinel.txt").write_bytes(b"KEEP ME")
        self.claim()

    def write(self, area, path, data):
        item = self.root / area / path
        item.parent.mkdir(parents=True, exist_ok=True)
        item.write_bytes(data)
        return item

    def claim(self, **overrides):
        obj = {
            "schema_version": 1,
            "original_volume_label": "FAKE_VOLUME_ORIGINAL",
            "backup_volume_label": "FAKE_VOLUME_BACKUP",
            "physical_independence_claim": True,
            "different_failure_domain_claim": True,
            "backup_retained_claim": True,
            "restore_rehearsed_claim": True,
        }
        obj.update(overrides)
        (self.root / tool.CLAIM).write_text(json.dumps(obj, separators=(",", ":")), encoding="utf-8")

    def sha_tree(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob("*") if p.is_file() and not p.is_symlink()}

    def test_matching_synthetic_copies_still_same_volume_and_never_approved(self):
        before = self.sha_tree()
        r = tool.review(self.root)
        self.assertEqual(r["status"], "manual_review_required")
        self.assertEqual(r["backup_copy_observation"], "scope_bytes_match_untrusted")
        self.assertEqual(r["scope_count"], 8)
        self.assertTrue(r["all_fake_wtf_accounts_and_characters_included"])
        self.assertEqual(r["observed_logical_volume_relation"], "same_logical_volume_not_independent")
        self.assertIn("claimed_different_volume_but_observed_same_logical_volume", r["blockers"])
        for field in ("different_physical_storage_verified", "independent_power_failure_domain_verified",
                      "durable_backup_bytes_verified", "authenticated_backup_ownership_verified",
                      "independent_original_backup_or_restore_verified", "restoration_rehearsal_verified",
                      "storage_claim_authenticated", "game_client_file_read_or_write_performed",
                      "backup_created_or_deleted", "restore_or_install_authorised",
                      "public_release_authorised", "private_paths_names_hashes_or_claimed_labels_reported"):
            self.assertFalse(r[field], field)
        text = json.dumps(r)
        for token in ("ACCT_ONE", "Realm2", "Other.lua", "FAKE_VOLUME_ORIGINAL", str(self.root), "CustomSettings.dat"):
            self.assertNotIn(token, text)
        self.assertEqual(before, self.sha_tree())

    def test_even_consistent_same_volume_label_is_not_backup_independence(self):
        self.claim(backup_volume_label="FAKE_VOLUME_ORIGINAL")
        r = tool.review(self.root)
        self.assertIn("same_logical_volume_observed_not_independent_disaster_recovery", r["blockers"])
        self.assertNotIn("claimed_different_volume_but_observed_same_logical_volume", r["blockers"])
        self.assertFalse(r["independent_power_failure_domain_verified"])

    def test_missing_backup_original_copy_and_changed_wtf(self):
        (self.root / "backup/Interface/AddOns/NCore/Custom.lua").unlink()
        self.write("current", "WTF/Account/ACCT_TWO/Realm2/B/SavedVariables/Other.lua", b"PLAYER CHANGED")
        r = tool.review(self.root)
        self.assertEqual(r["backup_copy_observation"], "unusable_or_incomplete_original_copy")
        self.assertEqual(r["copy_mismatch_scope_count"], 1)
        self.assertEqual(r["player_change_scope_count"], 1)
        self.assertIn("mismatched_or_missing_original_copy_preserve", r["blockers"])
        self.assertIn("changed_current_addon_or_character_settings_preserve", r["blockers"])

    def test_both_original_and_backup_changed_coherently_not_trusted(self):
        # Deliberate attack: identical mutable copies can't prove what existed before.
        self.write("original", "Interface/AddOns/NCore/Custom.lua", b"ATTACKER NEW BYTES")
        self.write("backup", "Interface/AddOns/NCore/Custom.lua", b"ATTACKER NEW BYTES")
        r = tool.review(self.root)
        self.assertEqual(r["backup_copy_observation"], "scope_bytes_match_untrusted")
        self.assertFalse(r["authenticated_backup_ownership_verified"])
        self.assertFalse(r["restore_or_install_authorised"])

    def test_all_negative_caller_claims_block(self):
        for key, expected in (
            ("physical_independence_claim", "physical_storage_independence_not_even_claimed"),
            ("different_failure_domain_claim", "independent_failure_domain_not_even_claimed"),
            ("backup_retained_claim", "backup_retention_not_even_claimed"),
            ("restore_rehearsed_claim", "restore_rehearsal_not_even_claimed"),
        ):
            with self.subTest(key=key):
                self.claim(**{key: False})
                r = tool.review(self.root)
                self.assertIn(expected, r["blockers"])
                self.assertFalse(r["restore_or_install_authorised"])

    def test_malformed_duplicate_key_missing_and_oversized_claims(self):
        item = self.root / tool.CLAIM
        item.write_text('{"schema_version":1,"schema_version":1}', encoding="utf-8")
        with self.assertRaisesRegex(tool.Refusal, "invalid_or_unsafe_local_storage_claim"):
            tool.review(self.root)
        self.claim(schema_version=2)
        with self.assertRaisesRegex(tool.Refusal, "invalid_storage_schema"):
            tool.review(self.root)
        self.claim(backup_retained_claim=1)
        with self.assertRaisesRegex(tool.Refusal, "invalid_storage_boolean_claim"):
            tool.review(self.root)
        self.claim(original_volume_label="not a safe label!")
        with self.assertRaisesRegex(tool.Refusal, "invalid_storage_volume_label"):
            tool.review(self.root)
        item.write_bytes(b"x" * (tool.MAX_CLAIM + 1))
        with self.assertRaisesRegex(tool.Refusal, "invalid_or_unsafe_local_storage_claim"):
            tool.review(self.root)
        item.unlink()
        with self.assertRaisesRegex(tool.Refusal, "invalid_or_unsafe_local_storage_claim"):
            tool.review(self.root)

    def test_linked_or_hardlinked_copy_rejected(self):
        target = self.root / "backup/WTF/Config.wtf"
        original = self.root / "original/WTF/Config.wtf"
        target.unlink()
        try:
            os.link(original, target)
        except (OSError, NotImplementedError):
            self.skipTest("synthetic filesystem does not support hardlinks")
        r = tool.review(self.root)
        self.assertIn("unsafe_original_or_backup_tree_preserve", r["blockers"])
        self.assertEqual(r["backup_copy_observation"], "unusable_or_incomplete_original_copy")

    def test_symlinked_claim_refused(self):
        item = self.root / tool.CLAIM
        raw = item.read_bytes()
        item.unlink()
        try:
            item.symlink_to(self.root / tool.MARKER)
        except (OSError, NotImplementedError):
            item.write_bytes(raw)
            self.skipTest("synthetic filesystem does not support symlinks")
        with self.assertRaisesRegex(tool.Refusal, "invalid_or_unsafe_local_storage_claim"):
            tool.review(self.root)

    def test_missing_synthetic_marker_refused(self):
        (self.root / tool.MARKER).unlink()
        with self.assertRaisesRegex(tool.Refusal, "not_disposable_synthetic_storage_fixture"):
            tool.review(self.root)

    def test_claim_drift_between_readings_refused(self):
        def update_claim():
            self.claim(backup_retained_claim=False)
        with self.assertRaisesRegex(tool.Refusal, "storage_claim_changed_during_review"):
            tool.review(self.root, between_observations=update_claim)

    def test_directory_replacement_between_scans_refused(self):
        def rename_backup():
            (self.root / "backup").rename(self.root / "backup-moved")
            (self.root / "backup").mkdir()
        # Missing backup is observed as scopes absent and later different ID.
        with self.assertRaisesRegex(tool.Refusal, "snapshot_directory_identity_changed"):
            tool.review(self.root, between_observations=rename_backup)

    def test_cli_is_safe_and_read_only(self):
        before = self.sha_tree()
        res = subprocess.run([sys.executable, str(SCRIPT), "--synthetic-fixture-root", str(self.root)],
                             capture_output=True, text=True, check=True)
        obj = json.loads(res.stdout)
        self.assertEqual(obj["kind"], "naxxramas_synthetic_addon_backup_storage_review")
        self.assertFalse(obj["public_release_authorised"])
        self.assertNotIn(str(self.root), res.stdout)
        self.assertEqual(before, self.sha_tree())


if __name__ == "__main__":
    unittest.main()
