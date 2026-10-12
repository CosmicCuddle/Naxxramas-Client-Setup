#!/usr/bin/env python3
"""Read-only, developer-only addon journal cutpoint exercise on FAKE fixtures.

The journal, "latest" record, marker, backup and client bytes are all authored
by the test harness, NOT authenticated authority. This module never writes,
creates backups, restores data, or authorises any player-client action.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

import review_synthetic_addon_recovery as integrity

MARKER = ".naxx-synthetic-journal-only"
MARKER_BYTES = b"NAXXRAMAS_SYNTHETIC_JOURNAL_REVIEW_ONLY\n"
JOURNAL = "journal.json"
LATEST = "latest-state.json"
MAX_JSON = 32768
ZERO = "0" * 64
DIGEST = re.compile(r"[0-9a-f]{64}\Z", re.ASCII)
TXN = re.compile(r"synthetic-[A-Za-z0-9_-]{8,56}\Z", re.ASCII)
PHASES = (
    "plan_frozen",
    "backup_started",
    "backup_copied",
    "backup_checked",
    "stage_started",
    "stage_checked",
    "replace_started",
    "replace_finished",
    "postcheck_finished",
    "recovery_requested",
    "recovery_started",
    "recovery_checked",
    "closed",
)
NEXT = {
    "plan_frozen": ("backup_started",),
    "backup_started": ("backup_copied",),
    "backup_copied": ("backup_checked",),
    "backup_checked": ("stage_started",),
    "stage_started": ("stage_checked",),
    "stage_checked": ("replace_started",),
    "replace_started": ("replace_finished", "recovery_requested"),
    "replace_finished": ("postcheck_finished", "recovery_requested"),
    "postcheck_finished": ("recovery_requested", "closed"),
    "recovery_requested": ("recovery_started",),
    "recovery_started": ("recovery_checked",),
    "recovery_checked": ("closed",),
    "closed": (),
}
CUTPOINT = {
    "plan_frozen": "before_backup_preserve",
    "backup_started": "partial_backup_manual_review",
    "backup_copied": "unverified_backup_manual_review",
    "backup_checked": "pre_replace_claim_untrusted_preserve",
    "stage_started": "partial_stage_manual_review",
    "stage_checked": "pre_replace_claim_untrusted_preserve",
    "replace_started": "interrupted_replace_manual_review",
    "replace_finished": "replacement_not_postchecked_manual_review",
    "postcheck_finished": "postcheck_claim_untrusted_preserve",
    "recovery_requested": "recovery_requested_manual_review",
    "recovery_started": "interrupted_recovery_manual_review",
    "recovery_checked": "recovery_claim_untrusted_preserve",
    "closed": "closed_claim_untrusted_preserve",
}
REPARSE = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)


class Refusal(ValueError):
    """Use only fixed path-free diagnostic codes."""


def event_digest(txn: str, scope: str, seq: int, phase: str, previous: str) -> str:
    """Unkeyed *synthetic* checksum. NOT a cryptographic trust guarantee."""
    data = json.dumps([txn, scope, seq, phase, previous],
                      ensure_ascii=True, separators=(",", ":")).encode("ascii")
    return hashlib.sha256(b"NAXX-SYNTHETIC-JOURNAL-EVENT-1:" + data).hexdigest()


def _regular(path: Path, maximum: int) -> bytes:
    try:
        first = path.lstat()
    except OSError as exc:
        raise Refusal("fixture_record_missing_or_unreadable") from exc
    if (not stat.S_ISREG(first.st_mode) or
        stat.S_ISLNK(first.st_mode) or
        getattr(first, "st_file_attributes", 0) & REPARSE or
        first.st_nlink > 1):
        raise Refusal("fixture_record_unsafe_link_or_type")
    if first.st_size > maximum:
        raise Refusal("fixture_record_too_large")
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0) | getattr(os, "O_NOFOLLOW", 0)
    fd = -1
    try:
        fd = os.open(path, flags)
        with os.fdopen(fd, "rb") as handle:
            fd = -1
            observed = os.fstat(handle.fileno())
            if (not stat.S_ISREG(observed.st_mode) or observed.st_nlink > 1 or
                (observed.st_dev, observed.st_ino, observed.st_size, observed.st_mtime_ns) !=
                (first.st_dev, first.st_ino, first.st_size, first.st_mtime_ns)):
                raise Refusal("fixture_record_changed_during_read")
            raw = handle.read(maximum + 1)
            after = os.fstat(handle.fileno())
            if len(raw) > maximum or len(raw) != first.st_size:
                raise Refusal("fixture_record_changed_during_read")
            if (after.st_size, after.st_mtime_ns) != (first.st_size, first.st_mtime_ns):
                raise Refusal("fixture_record_changed_during_read")
    except OSError as exc:
        raise Refusal("fixture_record_missing_or_unreadable") from exc
    finally:
        if fd >= 0:
            os.close(fd)
    try:
        current = path.lstat()
    except OSError as exc:
        raise Refusal("fixture_record_changed_during_read") from exc
    if (stat.S_ISLNK(current.st_mode) or
        getattr(current, "st_file_attributes", 0) & REPARSE or
        (current.st_dev, current.st_ino, current.st_size, current.st_mtime_ns) !=
        (first.st_dev, first.st_ino, first.st_size, first.st_mtime_ns)):
        raise Refusal("fixture_record_changed_during_read")
    return raw


def _no_duplicate_keys(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise Refusal("duplicate_json_keys")
        result[key] = value
    return result


def _json(raw: bytes) -> dict:
    try:
        value = json.loads(raw.decode("utf-8"),
                           object_pairs_hook=_no_duplicate_keys,
                           parse_constant=lambda _: (_ for _ in ()).throw(Refusal("invalid_json_constant")))
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as exc:
        raise Refusal("invalid_synthetic_json") from exc
    if type(value) is not dict:
        raise Refusal("unexpected_fixture_schema")
    return value


def _digest(value: object) -> bool:
    return type(value) is str and DIGEST.fullmatch(value) is not None


def _journal_check(journal: dict) -> tuple[str, str, int, str, str]:
    if set(journal) != {"schema_version", "transaction_id", "scope_digest", "events"} or type(journal["schema_version"]) is not int or journal["schema_version"] != 1:
        raise Refusal("unexpected_journal_schema")
    txn = journal["transaction_id"]
    scope = journal["scope_digest"]
    events = journal["events"]
    if type(txn) is not str or not TXN.fullmatch(txn) or not _digest(scope):
        raise Refusal("invalid_journal_claim_identity")
    if type(events) is not list or not 1 <= len(events) <= len(PHASES):
        raise Refusal("missing_or_excessive_journal_events")
    previous = ZERO
    phase_previous = ""
    for position, event in enumerate(events, 1):
        if type(event) is not list or len(event) != 4:
            raise Refusal("invalid_journal_event")
        seq, phase, prior, checksum = event
        if type(seq) is not int or seq != position:
            raise Refusal("journal_sequence_gap_or_replay")
        if type(phase) is not str or phase not in PHASES:
            raise Refusal("invalid_journal_phase")
        if (position == 1 and phase != "plan_frozen") or (position > 1 and phase not in NEXT[phase_previous]):
            raise Refusal("journal_skipped_or_illegal_phase")
        if not _digest(prior) or not _digest(checksum) or prior != previous:
            raise Refusal("journal_chain_disconnected")
        if checksum != event_digest(txn, scope, seq, phase, previous):
            raise Refusal("journal_chain_checksum_mismatch")
        previous, phase_previous = checksum, phase
    return txn, scope, len(events), phase_previous, previous


def _latest_check(latest: dict, txn: str, scope: str, count: int, checksum: str) -> str:
    if set(latest) != {"schema_version", "transaction_id", "scope_digest",
                       "latest_sequence", "latest_event_hash", "state"}:
        raise Refusal("unexpected_latest_claim_schema")
    if type(latest["schema_version"]) is not int or latest["schema_version"] != 1:
        raise Refusal("unexpected_latest_claim_schema")
    if (type(latest["transaction_id"]) is not str or
        type(latest["scope_digest"]) is not str or
        type(latest["latest_sequence"]) is not int or
        not _digest(latest["latest_event_hash"]) or
        type(latest["state"]) is not str or
        latest["state"] not in ("claimed_current", "claimed_stale", "claimed_revoked")):
        raise Refusal("malformed_latest_claim")
    if latest["transaction_id"] != txn or latest["scope_digest"] != scope:
        return "foreign_claim_preserve"
    if latest["state"] != "claimed_current":
        return "stale_or_revoked_claim_preserve"
    if latest["latest_sequence"] != count or latest["latest_event_hash"] != checksum:
        return "latest_pointer_mismatch_preserve"
    return "caller_claims_self_consistent_not_authenticated"


def review(root: Path, between_observations=None) -> dict:
    root = Path(os.path.abspath(root))
    # The separate recovery inspector already requires its own marker and
    # four pre-existing disposable fake snapshots, checking path ancestors.
    integrity.fixture_guard(root)
    if _regular(root / MARKER, len(MARKER_BYTES)) != MARKER_BYTES:
        raise Refusal("not_disposable_journal_fixture")
    journal_before = _regular(root / JOURNAL, MAX_JSON)
    latest_before = _regular(root / LATEST, MAX_JSON)
    txn, scope, count, phase, checksum = _journal_check(_json(journal_before))
    latest = _json(latest_before)
    latest_status = _latest_check(latest, txn, scope, count, checksum)

    if between_observations is not None:
        # Test-injected fake concurrent edits; reviewer itself cannot write.
        between_observations()

    content_result = integrity.review(root)
    journal_after = _regular(root / JOURNAL, MAX_JSON)
    latest_after = _regular(root / LATEST, MAX_JSON)
    if journal_before != journal_after or latest_before != latest_after:
        raise Refusal("fixture_claims_changed_during_review")

    blockers = []
    if latest_status != "caller_claims_self_consistent_not_authenticated":
        blockers.append(latest_status)
    if content_result["unsafe_scopes"]:
        blockers.append("unsafe_snapshot_scope_preserve")
    if content_result["backup_mismatch_scopes"]:
        blockers.append("untrusted_or_mismatched_backup_preserve")
    if content_result["current_conflict_scopes"]:
        blockers.append("changed_player_files_or_settings_preserve")

    return {
        "kind": "naxxramas_synthetic_addon_journal_cutpoint_review",
        "schema_version": 1,
        "synthetic_fixture_only": True,
        "read_only": True,
        "status": "manual_review_required" if blockers else "claims_consistent_NO_AUTHORITY",
        "phase_observed": phase,
        "cutpoint_classification": CUTPOINT[phase],
        "events_observed": count,
        "journal_self_consistent_untrusted": True,
        "latest_claim_classification": latest_status,
        "blockers": blockers,
        "observed_snapshot_scopes": content_result["scopes_checked"],
        "unsafe_snapshot_scopes": content_result["unsafe_scopes"],
        "backup_mismatch_scopes": content_result["backup_mismatch_scopes"],
        "player_or_settings_conflict_scopes": content_result["current_conflict_scopes"],
        "entire_wtf_protected": content_result["whole_wtf_included"],
        "private_paths_digests_or_contents_reported": False,
        "coherent_replay_independently_detectable": False,
        "transaction_identity_authenticated": False,
        "durable_checkpoint_verified": False,
        "independent_latest_state_verified": False,
        "backup_authenticated_or_verified_durable": False,
        "player_consent_recorded": False,
        "single_use_approval_authenticated": False,
        "recovery_or_resume_authorised": False,
        "install_or_copy_authorised": False,
        "restore_or_remove_authorised": False,
        "client_files_modified": False,
        "public_release_authorised": False,
        "limitations": "Caller-controlled synthetic hashes, marker, events, latest state and snapshots; non-atomic scans cannot detect coherent replay or all races.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only synthetic addon/WTF journal interruption review")
    parser.add_argument("--synthetic-fixture-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        value = review(args.synthetic_fixture_root)
    except (Refusal, integrity.Refusal) as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(value, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
