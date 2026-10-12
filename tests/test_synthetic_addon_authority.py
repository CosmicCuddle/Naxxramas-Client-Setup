#!/usr/bin/env python3
"""Only generated disposable fake data; reader must never write user files."""
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
SRC = TOOLS / "review_synthetic_addon_authority.py"
spec = importlib.util.spec_from_file_location("fake_authority", SRC)
assert spec is not None and spec.loader is not None
reviewer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reviewer)
import review_synthetic_addon_journal as journal
import review_synthetic_addon_recovery as integrity


class AuthorityCrashFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="NaxxAuthority-SYNTHETIC-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        for marker, value in (
            (integrity.MARKER, integrity.MARKER_BYTES),
            (journal.MARKER, journal.MARKER_BYTES),
            (reviewer.MARKER, reviewer.MARKER_BYTES),
        ):
            (self.root / marker).write_bytes(value)
        for folder in integrity.SNAPSHOTS:
            (self.root / folder).mkdir()
            self.write(folder, "Interface/AddOns/NCore/NCore.toc", b"## Interface: 30300\n")
            self.write(folder, "Interface/AddOns/NCore/player-custom.lua", b"CUSTOM ROOT")
            self.write(folder, "Interface/AddOns/MultiBot/Settings.lua", b"CUSTOM BOT")
            self.write(folder, "Interface/AddOns/NClassicBattlegrounds/Legacy.lua", b"LEGACY")
            self.write(folder, "WTF/Config.wtf", b"FAKE PRIVATE CONFIG")
            self.write(folder, "WTF/Account/ACCT1/RealmA/Char1/SavedVariables/MultiBot.lua", b"SAVED A")
            self.write(folder, "WTF/Account/ACCT2/RealmB/Char2/SavedVariables/Unknown.lua", b"SAVED B")
            self.write(folder, "Interface/AddOns/OutsideTheKnownSeven/DontTouch.lua", b"THIRD PARTY")
        (self.root / "outside-fixture-sentinel.txt").write_bytes(b"NEVER_MODIFY")
        self.txn = "synthetic-authority-20261012"
        self.scope = "d" * 64
        self.write_claims()

    def write(self, folder: str, relative: str, data: bytes):
        path = self.root / folder / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def write_claims(self, phases=None, fault="none", authority_changes=None, crash_changes=None):
        phases = ["plan_frozen"] if phases is None else phases
        previous = journal.ZERO
        events = []
        for seq, phase in enumerate(phases, 1):
            checksum = journal.event_digest(self.txn, self.scope, seq, phase, previous)
            events.append([seq, phase, previous, checksum])
            previous = checksum
        claim_journal = {
            "schema_version": 1, "transaction_id": self.txn, "scope_digest": self.scope,
            "events": events,
        }
        latest = {
            "schema_version": 1, "transaction_id": self.txn, "scope_digest": self.scope,
            "latest_sequence": len(phases), "latest_event_hash": previous,
            "state": "claimed_current",
        }
        authority = {
            "schema_version": 1, "transaction_id": self.txn, "scope_digest": self.scope,
            "latest_sequence": len(phases), "latest_event_hash": previous,
            "epoch_claim": 5, "consent_claim": "claimed_granted",
            "consumed_through_sequence": 0, "revoked_through_sequence": 0,
            "authority_claim_state": "claimed_current",
        }
        crash = {
            "schema_version": 1, "transaction_id": self.txn, "scope_digest": self.scope,
            "phase": phases[-1], "fault_window": fault,
            "same_volume_staging_claimed": True,
            "originals_independently_held_claimed": True,
            "checkpoint_flush_claimed": True,
            "parent_metadata_durable_claimed": True,
        }
        if authority_changes:
            authority.update(authority_changes)
        if crash_changes:
            crash.update(crash_changes)
        for name, data in (
            (journal.JOURNAL, claim_journal),
            (journal.LATEST, latest),
            (reviewer.AUTHORITY, authority),
            (reviewer.CRASH, crash),
        ):
            (self.root / name).write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")

    def snapshots(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob("*") if p.is_file() and not p.is_symlink()}

    def test_favourable_claims_still_deny_all_operations_and_do_not_write(self):
        before = self.snapshots()
        report = reviewer.review(self.root)
        self.assertEqual(report["status"], "claims_consistent_but_NOT_AUTHENTICATED")
        self.assertEqual(report["blockers"], [])
        self.assertTrue(report["full_addon_and_whole_wtf_preservation_reviewed"])
        self.assertFalse(report["existing_journal_manual_review"])
        for denied in (
            "local_claims_are_independent_authority", "coherent_rollback_of_all_local_claims_detectable",
            "user_or_owner_authenticated", "protected_monotonic_counter_verified",
            "one_use_consent_verified", "write_ahead_durable_checkpoint_verified",
            "independent_backup_durability_verified", "power_loss_recovery_tested",
            "real_client_files_read", "real_client_files_modified",
            "backup_copy_or_restore_performed", "automatic_resume_install_or_recovery_allowed",
            "deletion_allowed", "public_release_authorised",
            "private_paths_hashes_or_contents_reported",
        ):
            self.assertFalse(report[denied], denied)
        dumped = json.dumps(report)
        for private in ("ACCT1", "Char1", "Unknown.lua", "NCore.toc", self.txn, self.scope, str(self.root)):
            self.assertNotIn(private, dumped)
        self.assertEqual(self.snapshots(), before)

    def test_every_crash_window_fails_closed_at_realistic_cutpoint(self):
        lookup = {
            "backup_copy_torn": "backup_started",
            "backup_claim_before_validation": "backup_copied",
            "staged_file_torn": "stage_started",
            "rename_done_commit_missing": "replace_started",
            "commit_record_file_missing": "replace_finished",
            "recovery_copy_torn": "recovery_started",
            "power_loss_metadata_ambiguous": "closed",
        }
        for fault, phase in lookup.items():
            with self.subTest(fault=fault):
                chain = list(journal.PHASES[:journal.PHASES.index(phase) + 1])
                self.write_claims(chain, fault=fault)
                result = reviewer.review(self.root)
                self.assertEqual(result["status"], "manual_review_required")
                self.assertIn("interrupted_or_powerloss_boundary_preserve", result["blockers"])
                self.assertFalse(result["automatic_resume_install_or_recovery_allowed"])

    def test_inconsistent_fault_phase_is_an_additional_blocker(self):
        self.write_claims(["plan_frozen"], fault="rename_done_commit_missing")
        report = reviewer.review(self.root)
        self.assertIn("contradictory_crash_window_preserve", report["blockers"])

    def test_consumed_and_revoked_consent_counters(self):
        for name in ("consumed_through_sequence", "revoked_through_sequence"):
            with self.subTest(counter=name):
                self.write_claims(authority_changes={name: 1})
                result = reviewer.review(self.root)
                self.assertIn("already_" + ("consumed" if name.startswith("consumed") else "revoked"),
                              "already_" + ("consumed" if name.startswith("consumed") else "revoked"))
                self.assertTrue(any("already_" in s for s in result["blockers"]))
                self.assertEqual(result["status"], "manual_review_required")

    def test_pending_revoked_expired_or_missing_claim_blocks(self):
        for consent in ("claimed_pending", "claimed_consumed", "claimed_revoked", "claimed_expired"):
            with self.subTest(consent=consent):
                self.write_claims(authority_changes={"consent_claim": consent})
                self.assertIn("consent_not_current_or_consumed", reviewer.review(self.root)["blockers"])
        for status in ("claimed_stale", "claimed_missing", "claimed_revoked", "claimed_foreign"):
            with self.subTest(status=status):
                self.write_claims(authority_changes={"authority_claim_state": status})
                self.assertIn("no_current_independent_authority", reviewer.review(self.root)["blockers"])

    def test_binding_mismatch_of_authority_or_crash_is_not_trusted(self):
        cases = (
            ({"transaction_id": "synthetic-foreign-identity"}, None, "authority_claim_not_bound_to_latest_event"),
            ({"scope_digest": "b" * 64}, None, "authority_claim_not_bound_to_latest_event"),
            ({"latest_event_hash": "c" * 64}, None, "authority_claim_not_bound_to_latest_event"),
            ({"latest_sequence": 2}, None, "authority_claim_not_bound_to_latest_event"),
            (None, {"transaction_id": "synthetic-foreign-identity"}, "crash_claim_not_bound_to_current_phase"),
            (None, {"phase": "backup_started"}, "crash_claim_not_bound_to_current_phase"),
        )
        for a, c, expected in cases:
            with self.subTest(expected=expected, a=a, c=c):
                self.write_claims(authority_changes=a, crash_changes=c)
                self.assertIn(expected, reviewer.review(self.root)["blockers"])

    def test_false_storage_claims_each_require_manual_review(self):
        fields = (
            "same_volume_staging_claimed", "originals_independently_held_claimed",
            "checkpoint_flush_claimed", "parent_metadata_durable_claimed",
        )
        for field in fields:
            with self.subTest(field=field):
                self.write_claims(crash_changes={field: False})
                report = reviewer.review(self.root)
                self.assertEqual(report["status"], "manual_review_required")
                self.assertFalse(report["write_ahead_durable_checkpoint_verified"])
                self.assertTrue(any(x in report["blockers"] for x in (
                    "same_volume_stage_not_even_claimed",
                    "independent_originals_not_even_claimed",
                    "checkpoint_or_metadata_durability_not_even_claimed")))

    def test_corrupt_backup_and_changed_character_settings_look_preservation_first(self):
        self.write("backup", "Interface/AddOns/NCore/player-custom.lua", b"ALTERED")
        self.write("current", "WTF/Account/ACCT2/RealmB/Char2/SavedVariables/Unknown.lua", b"PLAYER CHANGE")
        result = reviewer.review(self.root)
        self.assertEqual(result["status"], "manual_review_required")
        self.assertEqual(result["underlying_backup_mismatch_scopes"], 1)
        self.assertEqual(result["underlying_player_or_settings_conflict_scopes"], 1)
        self.assertIn("existing_journal_or_content_review_requires_manual_attention", result["blockers"])

    def test_coherent_multi_record_replay_remains_undetectable_not_authorised(self):
        self.write_claims(list(journal.PHASES))
        old = {p: (self.root / p).read_bytes() for p in (
            journal.JOURNAL, journal.LATEST, reviewer.AUTHORITY, reviewer.CRASH)}
        self.write_claims(["plan_frozen", "backup_started"], fault="backup_copy_torn")
        self.assertEqual(reviewer.review(self.root)["status"], "manual_review_required")
        for name, data in old.items():
            (self.root / name).write_bytes(data)
        result = reviewer.review(self.root)
        self.assertEqual(result["status"], "claims_consistent_but_NOT_AUTHENTICATED")
        self.assertFalse(result["coherent_rollback_of_all_local_claims_detectable"])
        self.assertFalse(result["automatic_resume_install_or_recovery_allowed"])

    def test_duplicate_json_key_and_unknown_schema_and_integer_bool_refused(self):
        p = self.root / reviewer.AUTHORITY
        s = p.read_text()
        p.write_text(s.replace('"schema_version":1,', '"schema_version":1,"schema_version":1,'), encoding="utf-8")
        with self.assertRaisesRegex(reviewer.Refusal, "unsafe_or_unreadable_claim"):
            reviewer.review(self.root)
        self.write_claims(authority_changes={"schema_version": 2})
        with self.assertRaisesRegex(reviewer.Refusal, "unsupported_authority_schema"):
            reviewer.review(self.root)
        self.write_claims(authority_changes={"latest_sequence": True})
        with self.assertRaisesRegex(reviewer.Refusal, "invalid_authority_counter"):
            reviewer.review(self.root)
        self.write_claims(crash_changes={"checkpoint_flush_claimed": 1})
        with self.assertRaisesRegex(reviewer.Refusal, "invalid_storage_claim"):
            reviewer.review(self.root)

    def test_missing_oversized_and_changed_claim_record(self):
        p = self.root / reviewer.CRASH
        p.unlink()
        with self.assertRaisesRegex(reviewer.Refusal, "unsafe_or_unreadable_claim"):
            reviewer.review(self.root)
        self.write_claims()
        p.write_bytes(b"x" * (reviewer.MAX_RECORD_BYTES + 1))
        with self.assertRaisesRegex(reviewer.Refusal, "unsafe_or_unreadable_claim"):
            reviewer.review(self.root)
        self.write_claims()
        def change_fake_file():
            p.write_text(p.read_text() + "\n", encoding="utf-8")
        with self.assertRaisesRegex(reviewer.Refusal, "authority_or_crash_claim_changed_during_review"):
            reviewer.review(self.root, between_observations=change_fake_file)

    def test_missing_marker_and_linked_claim_refuse(self):
        (self.root / reviewer.MARKER).unlink()
        with self.assertRaisesRegex(reviewer.Refusal, "unsafe_or_unreadable_claim"):
            reviewer.review(self.root)
        (self.root / reviewer.MARKER).write_bytes(reviewer.MARKER_BYTES)
        claim = self.root / reviewer.AUTHORITY
        backup = claim.read_bytes()
        claim.unlink()
        try:
            claim.symlink_to(self.root / reviewer.CRASH)
        except (OSError, NotImplementedError):
            claim.write_bytes(backup)
            self.skipTest("synthetic filesystem does not allow symlinks")
        with self.assertRaisesRegex(reviewer.Refusal, "unsafe_or_unreadable_claim"):
            reviewer.review(self.root)

    def test_cli_report_private_content_not_exposed(self):
        before = self.snapshots()
        proc = subprocess.run(
            [sys.executable, str(SRC), "--synthetic-fixture-root", str(self.root)],
            capture_output=True, text=True, check=True,
        )
        obj = json.loads(proc.stdout)
        self.assertEqual(obj["kind"], "naxxramas_synthetic_independent_authority_design_review")
        for secret in (str(self.root), "ACCT1", "RealmB", "Char2", self.txn, self.scope):
            self.assertNotIn(secret, proc.stdout)
        self.assertEqual(before, self.snapshots())


if __name__ == "__main__":
    unittest.main()
