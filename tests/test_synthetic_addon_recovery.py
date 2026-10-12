#!/usr/bin/env python3
"""Disposable fake trees only. Tests may create/modify fake fixture bytes."""
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

TOOL = Path(__file__).resolve().parents[1] / 'tools' / 'review_synthetic_addon_recovery.py'
spec = importlib.util.spec_from_file_location('fake_recovery', TOOL)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class RecoveryFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='NaxxRecovery-FAKE-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / mod.MARKER).write_bytes(mod.MARKER_BYTES)
        for part in mod.SNAPSHOTS:
            (self.root / part).mkdir()
        base = {
            'Interface/AddOns/NCore/NCore.toc': b'## Version: 9\n',
            'Interface/AddOns/NCore/MissingFromNewRelease.lua': b'CUSTOM_PLAYER_LUA',
            'Interface/AddOns/MultiBot/subfolder/Profile.dat': b'CUSTOM_ADDON_FILE',
            'Interface/AddOns/NClassicBattlegrounds/Legacy.lua': b'legacy',
            'WTF/Config.wtf': b'PRIVATE CONFIG',
            'WTF/Account/ONE/SavedVariables/MultiBot.lua': b'ONE GLOBAL',
            'WTF/Account/ONE/RealmAlpha/CharA/SavedVariables/MultiBot.lua': b'CHARACTER_A',
            'WTF/Account/TWO/RealmBeta/CharB/SavedVariables/Unknown.lua': b'UNKNOWN ACCOUNT',
            'WTF/Account/TWO/RealmBeta/CharB/extra/private.dat': b'ALL UNKNOWN FILES',
        }
        for part in mod.SNAPSHOTS:
            for path, value in base.items():
                self.write(part, path, value)
            self.write(part, 'Interface/AddOns/UnrelatedPersonalAddon/DoNotRead.lua', b'THIRD PARTY')

    def write(self, area, path, contents):
        dest = self.root / area / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(contents)
        return dest

    def fingerprints(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file() and not p.is_symlink()}

    def row(self, result, name):
        return next(r for r in result['scopes'] if r['scope'] == name)

    def test_exact_synthetic_original_backup_and_all_settings(self):
        prior = self.fingerprints()
        result = mod.review(self.root)
        self.assertEqual(result['status'], 'observations_only_no_approval')
        self.assertEqual(result['scopes_checked'], 8)
        self.assertEqual(result['backup_mismatch_scopes'], 0)
        self.assertEqual(self.row(result, 'WTF (every account/realm/character)')['original_file_count'], 5)
        self.assertEqual(self.row(result, 'NCore')['original_file_count'], 2)
        self.assertEqual(self.row(result, 'NCore')['current_comparison'], 'already_original_preserve')
        self.assertFalse(result['original_backup_authenticated_or_durable'])
        for k in ('backup_created', 'restore_or_delete_performed', 'automatic_recovery_authorised',
                  'installation_or_backup_authorised', 'journal_authenticity_verified', 'client_updated',
                  'private_filenames_or_hashes_exposed', 'public_release_authorised'):
            self.assertFalse(result[k], k)
        output = json.dumps(result)
        for private in ('Account/ONE', 'RealmBeta', 'CharB', 'Unknown.lua', 'PRIVATE CONFIG',
                        'UnrelatedPersonalAddon', 'MissingFromNewRelease.lua'):
            self.assertNotIn(private, output)
        self.assertEqual(prior, self.fingerprints())

    def test_synthetic_backup_missing_and_extra_files(self):
        (self.root / 'backup/Interface/AddOns/NCore/MissingFromNewRelease.lua').unlink()
        self.write('backup', 'Interface/AddOns/NCore/stray.lua', b'unexpected copy')
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'NCore')['backup_comparison'], 'missing_or_extra_entries_preserve')
        self.assertEqual(result['status'], 'manual_review_required')

    def test_corrupt_backup_and_replacement_with_claimed_after(self):
        self.write('backup', 'Interface/AddOns/MultiBot/subfolder/Profile.dat', b'ALTERED_ADDON_FIL')
        self.write('claimed_after', 'Interface/AddOns/NCore/NCore.toc', b'## Version: 10\n')
        self.write('current', 'Interface/AddOns/NCore/NCore.toc', b'## Version: 10\n')
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'MultiBot')['backup_comparison'], 'changed_bytes_preserve')
        self.assertEqual(self.row(result, 'NCore')['current_comparison'],
                         'matches_untrusted_after_claim_not_recovery_permission')
        self.assertFalse(result['automatic_recovery_authorised'])

    def test_modified_addon_after_update_is_conflict(self):
        self.write('claimed_after', 'Interface/AddOns/NCore/NCore.toc', b'## Version: 10\n')
        self.write('current', 'Interface/AddOns/NCore/NCore.toc', b'CUSTOM PLAYER VERSION')
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'NCore')['current_comparison'], 'player_or_unknown_changes_preserve')
        self.assertEqual(result['current_conflict_scopes'], 1)

    def test_all_character_settings_always_preserved_if_different(self):
        self.write('claimed_after', 'WTF/Account/TWO/RealmBeta/CharB/SavedVariables/Unknown.lua', b'AFTER')
        self.write('current', 'WTF/Account/TWO/RealmBeta/CharB/SavedVariables/Unknown.lua', b'AFTER')
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'WTF (every account/realm/character)')['current_comparison'],
                         'settings_changed_preserve_manual_review')
        self.assertEqual(result['status'], 'manual_review_required')

    def test_missing_empty_directory_in_backup(self):
        (self.root / 'original/Interface/AddOns/NCore/EmptyFolder').mkdir()
        (self.root / 'claimed_after/Interface/AddOns/NCore/EmptyFolder').mkdir()
        (self.root / 'current/Interface/AddOns/NCore/EmptyFolder').mkdir()
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'NCore')['backup_comparison'], 'missing_or_extra_entries_preserve')

    def test_linked_backup_refuses_scope_without_leaking_paths(self):
        replacement = self.root / 'backup/WTF/Account/TWO/Link'
        try:
            replacement.symlink_to(self.root, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest('symlink not permitted on test OS')
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'WTF (every account/realm/character)')['reason'], 'linked_or_reparse_entry')
        self.assertEqual(self.row(result, 'WTF (every account/realm/character)')['backup_comparison'], 'unavailable_preserve')
        self.assertNotIn(str(self.root), json.dumps(result))

    def test_hardlink_alias_refused(self):
        path = self.root / 'original/Interface/AddOns/NCore/NCore.toc'
        duplicate = self.root / 'backup/Interface/AddOns/NCore/Duplicate.toc'
        try:
            os.link(path, duplicate)
        except (OSError, NotImplementedError):
            self.skipTest('hardlink unavailable')
        result = mod.review(self.root)
        self.assertEqual(self.row(result, 'NCore')['reason'], 'hardlinked_file')

    def test_intra_scan_file_change_refuses(self):
        def mutate(scope):
            if scope == 'NCore':
                self.write('current', 'Interface/AddOns/NCore/NCore.toc', b'RACED')
        result = mod.review(self.root, between_passes=mutate)
        self.assertEqual(self.row(result, 'NCore')['reason'], 'observations_changed_between_passes')
        self.assertFalse(result['automatic_recovery_authorised'])

    def test_missing_marker_refused(self):
        (self.root / mod.MARKER).unlink()
        with self.assertRaisesRegex(mod.Refusal, 'unavailable_entry'):
            mod.review(self.root)
        proc = subprocess.run([sys.executable, str(TOOL), '--synthetic-fixture-root', str(self.root)],
                              capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertNotIn(str(self.root), proc.stderr)

    def test_valid_cli_output(self):
        proc = subprocess.run([sys.executable, str(TOOL), '--synthetic-fixture-root', str(self.root)],
                              capture_output=True, text=True, check=True)
        result = json.loads(proc.stdout)
        self.assertTrue(result['synthetic_fixture_only'])
        self.assertNotIn(str(self.root), proc.stdout)

    def test_missing_backup_root_fails_before_scans(self):
        root = self.root / 'backup'
        rename = self.root / 'backup-away'
        root.rename(rename)
        with self.assertRaisesRegex(mod.Refusal, 'unavailable_entry'):
            mod.review(self.root)


if __name__ == '__main__':
    unittest.main()
