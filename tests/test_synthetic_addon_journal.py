#!/usr/bin/env python3
"""Synthetic interruption fixture writer / read-only reviewer regression tests."""
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
SRC = TOOLS / "review_synthetic_addon_journal.py"
spec = importlib.util.spec_from_file_location("synthetic_journal", SRC)
assert spec is not None and spec.loader is not None
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
import review_synthetic_addon_recovery as integrity


class JournalCutpointFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="NaxxJournal-FAKE-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / tool.MARKER).write_bytes(tool.MARKER_BYTES)
        (self.root / integrity.MARKER).write_bytes(integrity.MARKER_BYTES)
        for folder in integrity.SNAPSHOTS:
            (self.root / folder).mkdir()
            self.write(folder, "Interface/AddOns/NCore/NCore.toc", b"## Interface: 30300\n")
            self.write(folder, "Interface/AddOns/NCore/custom/Retain.lua", b"CUSTOM ADDON")
            self.write(folder, "Interface/AddOns/MultiBot/Keep.dat", b"EXTRA PLAYER DATA")
            self.write(folder, "Interface/AddOns/NClassicBattlegrounds/Old.lua", b"LEGACY")
            self.write(folder, "WTF/Config.wtf", b"USER CONFIG")
            self.write(folder, "WTF/Account/ONE/RealmA/Alice/SavedVariables/MultiBot.lua", b"CHARACTER A")
            self.write(folder, "WTF/Account/TWO/RealmB/Bob/SavedVariables/Unknown.lua", b"CHARACTER B")
            self.write(folder, "Interface/AddOns/CompletelyUnrelatedAddon/Private.lua", b"UNRELATED")
        (self.root / "outside-client-test-sentinel.txt").write_bytes(b"NOT PART OF GAME")
        self.txn = "synthetic-journal-fixture-001"
        self.scope = "f" * 64
        self.write_chain(["plan_frozen"])

    def write(self, area, path, data):
        target = self.root / area / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        return target

    def write_chain(self, phases, state="claimed_current", latest_seq=None,
                    latest_hash=None, latest_txn=None):
        previous = tool.ZERO
        records = []
        for seq, phase in enumerate(phases, 1):
            digest = tool.event_digest(self.txn, self.scope, seq, phase, previous)
            records.append([seq, phase, previous, digest])
            previous = digest
        journal = {
            "schema_version": 1, "transaction_id": self.txn,
            "scope_digest": self.scope, "events": records,
        }
        latest = {
            "schema_version": 1, "transaction_id": latest_txn or self.txn,
            "scope_digest": self.scope,
            "latest_sequence": len(records) if latest_seq is None else latest_seq,
            "latest_event_hash": previous if latest_hash is None else latest_hash,
            "state": state,
        }
        (self.root / tool.JOURNAL).write_text(json.dumps(journal, separators=(",", ":")), encoding="utf-8")
        (self.root / tool.LATEST).write_text(json.dumps(latest, separators=(",", ":")), encoding="utf-8")
        return journal, latest

    def hashes(self):
        return {str(path.relative_to(self.root)): hashlib.sha256(path.read_bytes()).hexdigest()
                for path in self.root.rglob("*") if path.is_file() and not path.is_symlink()}

    def test_all_thirteen_interruption_cutpoints_deny_every_action(self):
        phases = []
        for phase in tool.PHASES:
            phases.append(phase)
            self.write_chain(phases)
            before = self.hashes()
            report = tool.review(self.root)
            self.assertEqual(report["cutpoint_classification"], tool.CUTPOINT[phase])
            self.assertEqual(report["phase_observed"], phase)
            self.assertEqual(report["events_observed"], len(phases))
            expected = ("manual_review_required" if phase in {
                "backup_started", "backup_copied", "stage_started", "replace_started",
                "replace_finished", "recovery_requested", "recovery_started"
            } else "claims_consistent_NO_AUTHORITY")
            self.assertEqual(report["status"], expected)
            self.assertTrue(report["journal_self_consistent_untrusted"])
            for denial in ("transaction_identity_authenticated", "durable_checkpoint_verified",
                           "independent_latest_state_verified", "backup_authenticated_or_verified_durable",
                           "player_consent_recorded", "single_use_approval_authenticated",
                           "recovery_or_resume_authorised", "install_or_copy_authorised",
                           "restore_or_remove_authorised", "client_files_modified",
                           "public_release_authorised", "coherent_replay_independently_detectable"):
                self.assertFalse(report[denial], f"{phase}: {denial}")
            self.assertEqual(before, self.hashes())

    def test_corrupted_backup_blocks_even_completed_claim(self):
        self.write_chain(list(tool.PHASES))
        self.write("backup", "Interface/AddOns/NCore/custom/Retain.lua", b"CORRUPT")
        result = tool.review(self.root)
        self.assertEqual(result["status"], "manual_review_required")
        self.assertIn("untrusted_or_mismatched_backup_preserve", result["blockers"])
        self.assertEqual(result["backup_mismatch_scopes"], 1)

    def test_current_character_settings_modified_block_even_claimed_after(self):
        self.write_chain(list(tool.PHASES))
        path = "WTF/Account/TWO/RealmB/Bob/SavedVariables/Unknown.lua"
        self.write("claimed_after", path, b"CHANGED PRIVATE")
        self.write("current", path, b"CHANGED PRIVATE")
        result = tool.review(self.root)
        self.assertIn("changed_player_files_or_settings_preserve", result["blockers"])
        self.assertGreater(result["player_or_settings_conflict_scopes"], 0)
        self.assertNotIn("Bob", json.dumps(result))

    def test_missing_or_truncated_journal_is_refused(self):
        (self.root / tool.JOURNAL).unlink()
        with self.assertRaisesRegex(tool.Refusal, "fixture_record_missing_or_unreadable"):
            tool.review(self.root)
        (self.root / tool.JOURNAL).write_bytes(b'{"schema_version":1')
        with self.assertRaisesRegex(tool.Refusal, "invalid_synthetic_json"):
            tool.review(self.root)

    def test_unkeyed_event_hash_tamper_is_refused(self):
        self.write_chain(["plan_frozen", "backup_started", "backup_copied"])
        path = self.root / tool.JOURNAL
        journal = json.loads(path.read_text(encoding="utf-8"))
        journal["events"][-1][-1] = "a" * 64
        path.write_text(json.dumps(journal), encoding="utf-8")
        with self.assertRaisesRegex(tool.Refusal, "journal_chain_checksum_mismatch"):
            tool.review(self.root)

    def test_missing_sequence_checkpoint_blocks(self):
        self.write_chain(["plan_frozen", "backup_started"])
        path = self.root / tool.JOURNAL
        journal = json.loads(path.read_text(encoding="utf-8"))
        journal["events"][-1][0] = 4
        path.write_text(json.dumps(journal), encoding="utf-8")
        with self.assertRaisesRegex(tool.Refusal, "journal_sequence_gap_or_replay"):
            tool.review(self.root)

    def test_skipping_backup_checkpoint_blocks_even_with_matching_checksum(self):
        self.write_chain(["plan_frozen", "backup_started"])
        path = self.root / tool.JOURNAL
        journal = json.loads(path.read_text(encoding="utf-8"))
        phase = "backup_checked"
        journal["events"][1] = [2, phase, journal["events"][0][-1],
                                tool.event_digest(self.txn, self.scope, 2, phase, journal["events"][0][-1])]
        path.write_text(json.dumps(journal), encoding="utf-8")
        with self.assertRaisesRegex(tool.Refusal, "journal_skipped_or_illegal_phase"):
            tool.review(self.root)

    def test_latest_stale_or_revoked_claim_never_grants_recovery(self):
        for state in ("claimed_stale", "claimed_revoked"):
            self.write_chain(["plan_frozen", "backup_started"], state=state)
            result = tool.review(self.root)
            self.assertEqual(result["status"], "manual_review_required")
            self.assertIn("stale_or_revoked_claim_preserve", result["blockers"])

    def test_wrong_latest_sequence_and_foreign_session_are_refused(self):
        self.write_chain(["plan_frozen", "backup_started"], latest_seq=1)
        first = tool.review(self.root)
        self.assertIn("latest_pointer_mismatch_preserve", first["blockers"])
        self.write_chain(["plan_frozen", "backup_started"], latest_txn="synthetic-another-transaction")
        second = tool.review(self.root)
        self.assertIn("foreign_claim_preserve", second["blockers"])

    def test_caller_can_replay_both_local_claims_coherently(self):
        # Deliberately document the missing authority: a complete rollback of
        # two caller-controlled files looks locally consistent again.
        self.write_chain(list(tool.PHASES))
        complete = tool.review(self.root)
        self.assertEqual(complete["phase_observed"], "closed")
        self.write_chain(["plan_frozen", "backup_started", "backup_copied"])
        replay = tool.review(self.root)
        self.assertEqual(replay["status"], "manual_review_required")
        self.assertEqual(replay["phase_observed"], "backup_copied")
        self.assertFalse(replay["coherent_replay_independently_detectable"])
        self.assertFalse(replay["recovery_or_resume_authorised"])

    def test_missing_and_wrong_marker_block_real_client_accidents(self):
        (self.root / tool.MARKER).unlink()
        with self.assertRaisesRegex(tool.Refusal, "fixture_record_missing_or_unreadable"):
            tool.review(self.root)
        (self.root / tool.MARKER).write_bytes(b"WRONG SYNTHETIC MARKER")
        with self.assertRaisesRegex(tool.Refusal, "not_disposable_journal_fixture"):
            tool.review(self.root)

    def test_symlinked_and_hardlinked_claim_file_refused(self):
        latest = self.root / tool.LATEST
        saved = latest.read_bytes()
        latest.unlink()
        try:
            latest.symlink_to(self.root / tool.JOURNAL)
        except (OSError, NotImplementedError):
            latest.write_bytes(saved)
            self.skipTest("test OS forbids disposable symlink creation")
        with self.assertRaisesRegex(tool.Refusal, "fixture_record_unsafe_link_or_type"):
            tool.review(self.root)
        latest.unlink()
        latest.write_bytes(saved)
        second = self.root / "hardlinked-synthetic-record.json"
        try:
            os.link(latest, second)
        except (OSError, NotImplementedError):
            self.skipTest("test OS forbids disposable hardlinks")
        with self.assertRaisesRegex(tool.Refusal, "fixture_record_unsafe_link_or_type"):
            tool.review(self.root)

    def test_claim_changed_during_observation_refuses(self):
        def writer():
            self.write_chain(["plan_frozen", "backup_started"])
        with self.assertRaisesRegex(tool.Refusal, "fixture_claims_changed_during_review"):
            tool.review(self.root, between_observations=writer)

    def test_duplicate_json_key_blocks(self):
        path = self.root / tool.JOURNAL
        original = path.read_text(encoding="utf-8")
        path.write_text(original.replace('"schema_version":1,', '"schema_version":1,"schema_version":1,'),
                        encoding="utf-8")
        with self.assertRaisesRegex(tool.Refusal, "duplicate_json_keys"):
            tool.review(self.root)

    def test_large_and_extra_fields_refused(self):
        file = self.root / tool.JOURNAL
        file.write_bytes(b"x" * (tool.MAX_JSON + 1))
        with self.assertRaisesRegex(tool.Refusal, "fixture_record_too_large"):
            tool.review(self.root)
        self.write_chain(["plan_frozen"])
        path = self.root / tool.LATEST
        record = json.loads(path.read_text(encoding="utf-8"))
        record["unexpected"] = "no"
        path.write_text(json.dumps(record), encoding="utf-8")
        with self.assertRaisesRegex(tool.Refusal, "unexpected_latest_claim_schema"):
            tool.review(self.root)

    def test_cli_reports_only_safe_fixed_fields(self):
        before = self.hashes()
        proc = subprocess.run([sys.executable, str(SRC), "--synthetic-fixture-root", str(self.root)],
                              check=True, capture_output=True, text=True)
        result = json.loads(proc.stdout)
        self.assertEqual(result["kind"], "naxxramas_synthetic_addon_journal_cutpoint_review")
        self.assertFalse(result["restore_or_remove_authorised"])
        for secret in ("RealmA", "Alice", "Bob", "Unknown.lua", str(self.root), self.txn, self.scope):
            self.assertNotIn(secret, proc.stdout)
        self.assertEqual(before, self.hashes())

    def test_private_unrelated_addon_is_not_traversed(self):
        # The referenced integrity reviewer intentionally considers only the
        # known five suite + two legacy addon roots, plus all WTF.
        self.write("current", "Interface/AddOns/CompletelyUnrelatedAddon/Private.lua", b"CHANGED OUT OF SCOPE")
        observed = tool.review(self.root)
        self.assertEqual(observed["player_or_settings_conflict_scopes"], 0)
        self.assertFalse(observed["private_paths_digests_or_contents_reported"])


if __name__ == "__main__":
    unittest.main()
