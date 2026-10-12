#!/usr/bin/env python3
"""SYNTHETIC ONLY read-only preservation scope Windows and local regression."""
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

SRC = Path(__file__).resolve().parents[1] / "tools" / "review_synthetic_addon_original_scope.py"
spec = importlib.util.spec_from_file_location("synthetic_scope", SRC)
assert spec is not None and spec.loader is not None
scanner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scanner)


class SyntheticAddonOriginalScope(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory(prefix="NaxxScope-FAKE-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.client = self.root / "fake-client"
        self.client.mkdir()
        (self.client / scanner.MARKER).write_bytes(scanner.MARKER_BYTES)
        self.addons = self.client / "Interface" / "AddOns"
        self.addons.mkdir(parents=True)
        self._save("Interface/AddOns/NCore/NCore.toc", b"## Interface: 30300\n## Version: 2.0\n")
        self._save("Interface/AddOns/NCore/SomeLua.lua", b"-- fake 123")
        self._save("Interface/AddOns/IndividualProgressionAddon/UnknownConfig.dat", b"PLAYER_CUSTOM_BYTES")
        self._save("Interface/AddOns/NClassicBattlegrounds/Legacy.lua", b"-- legacy")
        self._save("Interface/AddOns/SomeThirdParty/Keep.lua", b"UNRELATED_PLAYER_ADDON")
        self._save("WTF/Config.wtf", b"private config data")
        self._save("WTF/Account/FAKE_ACCOUNT_ONE/SavedVariables/MultiBot.lua", b"account one")
        self._save("WTF/Account/FAKE_ACCOUNT_ONE/RealmOne/CharacterOne/SavedVariables/MultiBot.lua",
                   b"character one")
        self._save("WTF/Account/FAKE_ACCOUNT_ONE/RealmTwo/CharacterTwo/SavedVariables/ExtraAddon.lua",
                   b"unknown character settings")
        self._save("WTF/Account/FAKE_ACCOUNT_TWO/RealmThree/CharacterThree/SavedVariables/NewAddon.lua",
                   b"another account")
        (self.root / "outside-client-sentinel.txt").write_bytes(b"NEVER_TOUCH_OUTSIDE")

    def _save(self, relative: str, value: bytes) -> Path:
        dest = self.client / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(value)
        return dest

    def fingerprint(self) -> dict[str, str]:
        result = {}
        for path in sorted(self.root.rglob("*")):
            if path.is_file() and not path.is_symlink():
                result[str(path.relative_to(self.root))] = hashlib.sha256(path.read_bytes()).hexdigest()
        return result

    def test_complete_multi_account_scope_no_settings_content_read(self) -> None:
        before = self.fingerprint()
        report = scanner.review(self.client)
        self.assertEqual(report["status"], "scope_observation_only_not_backup")
        self.assertEqual(len(report["scopes"]), 8)
        self.assertEqual(report["suite_folder_count"], 5)
        self.assertEqual(report["legacy_folder_count"], 2)
        wtf = report["scopes"][-1]
        self.assertEqual(wtf["scope"], "WTF (all profiles)")
        self.assertEqual(wtf["files_observed"], 5)
        self.assertEqual(wtf["original_bytes_observed"],
                         sum(len((self.client / name).read_bytes()) for name in (
                             "WTF/Config.wtf",
                             "WTF/Account/FAKE_ACCOUNT_ONE/SavedVariables/MultiBot.lua",
                             "WTF/Account/FAKE_ACCOUNT_ONE/RealmOne/CharacterOne/SavedVariables/MultiBot.lua",
                             "WTF/Account/FAKE_ACCOUNT_ONE/RealmTwo/CharacterTwo/SavedVariables/ExtraAddon.lua",
                             "WTF/Account/FAKE_ACCOUNT_TWO/RealmThree/CharacterThree/SavedVariables/NewAddon.lua",
                         )))
        core = report["scopes"][0]
        self.assertEqual(core["files_observed"], 2)
        self.assertEqual(report["scopes"][1]["files_observed"], 1)
        self.assertEqual(report["scopes"][5]["kind"], "legacy")
        self.assertFalse(report["exact_verified_original_inventory"])
        for denial in ("backup_created", "backup_verified", "restoration_tested",
                       "installation_update_or_recovery_authorised", "public_release_authorised",
                       "private_settings_contents_read", "unrelated_addon_contents_read",
                       "user_paths_or_filenames_reported", "atomic_snapshot", "any_client_file_modified"):
            self.assertFalse(report[denial], denial)
        output = json.dumps(report)
        self.assertNotIn("FAKE_ACCOUNT", output)
        self.assertNotIn("CharacterOne", output)
        self.assertNotIn("SomeThirdParty", output)
        self.assertNotIn("ExtraAddon.lua", output)
        self.assertEqual(self.fingerprint(), before)

    def test_cli_json_and_no_private_paths(self) -> None:
        result = subprocess.run([sys.executable, str(SRC), "--synthetic-fixture-client", str(self.client)],
                                check=True, capture_output=True, text=True)
        info = json.loads(result.stdout)
        self.assertEqual(info["kind"], "naxxramas_synthetic_addon_original_scope_review")
        self.assertNotIn(str(self.root), result.stdout)
        self.assertEqual(info["status"], "scope_observation_only_not_backup")

    def test_missing_marker_refuses_without_reading_wtf(self) -> None:
        (self.client / scanner.MARKER).unlink()
        with self.assertRaisesRegex(scanner.ReviewError, "unreadable_or_disappeared_entry"):
            scanner.review(self.client)
        cli = subprocess.run([sys.executable, str(SRC), "--synthetic-fixture-client", str(self.client)],
                             capture_output=True, text=True)
        self.assertEqual(cli.returncode, 2)
        self.assertNotIn(str(self.client), cli.stderr)

    def test_tampered_marker_rejected(self) -> None:
        (self.client / scanner.MARKER).write_bytes(b"NOT_A_FAKE_CLIENT")
        with self.assertRaisesRegex(scanner.ReviewError, "not_a_disposable_synthetic_fixture"):
            scanner.review(self.client)

    def test_synthetic_linked_wtf_blocked_without_traversal(self) -> None:
        self.client.joinpath("WTF", "Account", "FAKE_ACCOUNT_ONE", "LinkedSettings").parent.mkdir(parents=True, exist_ok=True)
        linked = self.client / "WTF/Account/FAKE_ACCOUNT_ONE/LinkedSettings"
        try:
            linked.symlink_to(self.root, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("OS does not permit disposable symlink creation")
        before = self.fingerprint()
        report = scanner.review(self.client)
        self.assertEqual(report["status"], "unsafe_scope_manual_review")
        self.assertEqual(report["scopes"][-1]["unsafe_reason"], "linked_or_reparse_entry")
        self.assertEqual(report["scopes"][-1]["files_observed"], 0)
        self.assertEqual(self.fingerprint(), before)

    def test_hardlink_to_settings_blocks_scope(self) -> None:
        source = self.client / "WTF/Config.wtf"
        target = self.client / "WTF/CopyOfConfig.wtf"
        try:
            os.link(source, target)
        except (OSError, NotImplementedError):
            self.skipTest("Hardlink unavailable on this synthetic filesystem")
        report = scanner.review(self.client)
        self.assertEqual(report["scopes"][-1]["state"], "unsafe_preserve_manual_review")
        self.assertEqual(report["scopes"][-1]["unsafe_reason"], "hardlinked_file")
        self.assertFalse(report["installation_update_or_recovery_authorised"])

    def test_nested_unknown_addon_file_does_not_escape_scope(self) -> None:
        self._save("Interface/AddOns/NCore/SomeNestedFolder/CustomPatch.txt", b"CUSTOM_NEVER_OVERWRITE")
        before = self.fingerprint()
        report = scanner.review(self.client)
        self.assertEqual(report["scopes"][0]["files_observed"], 3)
        self.assertFalse(report["scopes"][0]["backup_created"])
        self.assertEqual(before, self.fingerprint())

    def test_missing_wtf_is_reported_not_created(self) -> None:
        # Use an otherwise empty *separate* synthetic client. Never remove
        # the real test fixture's WTF tree in order to simulate absence.
        other = self.root / "other-fake-client"
        other.mkdir()
        (other / scanner.MARKER).write_bytes(scanner.MARKER_BYTES)
        report = scanner.review(other)
        self.assertEqual(report["scopes"][-1]["state"], "absent")
        self.assertTrue(report["whole_wtf_tree_in_scope"])
        self.assertFalse((other / "WTF").exists())

    def test_mismatched_folder_case_requires_manual_review(self) -> None:
        # A case-only alternate path is not a canonical owned addon root.
        source = self.addons / "NCore"
        renamed = self.addons / "ncore"
        try:
            source.rename(renamed)
        except OSError:
            self.skipTest("Case-only rename unavailable on this filesystem")
        before = self.fingerprint()
        result = scanner.review(self.client)
        self.assertEqual(result["scopes"][0]["unsafe_reason"], "case_mismatched_folder")
        self.assertEqual(result["scopes"][0]["state"], "unsafe_preserve_manual_review")
        self.assertEqual(before, self.fingerprint())

    def test_entry_budget_fails_closed(self) -> None:
        original = scanner.MAX_ENTRIES
        scanner.MAX_ENTRIES = 1
        try:
            info = scanner.review(self.client)
        finally:
            scanner.MAX_ENTRIES = original
        self.assertEqual(info["scopes"][0]["unsafe_reason"], "entry_limit")
        self.assertFalse(info["exact_verified_original_inventory"])


if __name__ == "__main__":
    unittest.main()
