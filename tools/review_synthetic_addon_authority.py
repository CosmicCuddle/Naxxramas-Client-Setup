#!/usr/bin/env python3
"""Developer-only synthetic authority/crash-boundary CLAIM classifier.

This is not an authenticated authority, a journal writer, a backup engine or a
recovery tool. Every input lives in caller-created disposable fake fixtures.
Even perfectly consistent claims can be replayed together and NEVER authorise
a file operation.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys

import review_synthetic_addon_journal as journal
import review_synthetic_addon_recovery as integrity

MARKER = ".naxx-synthetic-authority-only"
MARKER_BYTES = b"NAXXRAMAS_SYNTHETIC_AUTHORITY_CLAIMS_ONLY\n"
AUTHORITY = "authority-claim.json"
CRASH = "crash-claim.json"
MAX_RECORD_BYTES = 8192

AUTHORITY_FIELDS = frozenset((
    "schema_version", "transaction_id", "scope_digest", "latest_sequence",
    "latest_event_hash", "epoch_claim", "consent_claim",
    "consumed_through_sequence", "revoked_through_sequence",
    "authority_claim_state",
))
CRASH_FIELDS = frozenset((
    "schema_version", "transaction_id", "scope_digest", "phase",
    "fault_window", "same_volume_staging_claimed",
    "originals_independently_held_claimed", "checkpoint_flush_claimed",
    "parent_metadata_durable_claimed",
))
FAULTS = {
    "none": None,
    "backup_copy_torn": {"backup_started", "backup_copied"},
    "backup_claim_before_validation": {"backup_copied", "backup_checked"},
    "staged_file_torn": {"stage_started", "stage_checked"},
    "rename_done_commit_missing": {"replace_started", "replace_finished"},
    "commit_record_file_missing": {"replace_finished", "postcheck_finished"},
    "recovery_copy_torn": {"recovery_started", "recovery_checked"},
    "power_loss_metadata_ambiguous": set(journal.PHASES),
}
CONSENT = ("claimed_granted", "claimed_pending", "claimed_consumed",
           "claimed_revoked", "claimed_expired")
AUTH_STATES = ("claimed_current", "claimed_stale", "claimed_missing",
               "claimed_revoked", "claimed_foreign")


class Refusal(ValueError):
    """Path-free refusal codes, never private journal or settings details."""


def _integer(value: object, low: int, high: int) -> bool:
    return type(value) is int and low <= value <= high


def _read_claim(path: Path) -> tuple[bytes, dict]:
    try:
        raw = journal._regular(path, MAX_RECORD_BYTES)
        claim = journal._json(raw)
    except journal.Refusal as exc:
        raise Refusal("unsafe_or_unreadable_claim") from exc
    return raw, claim


def _check_authority(claim: dict) -> None:
    if set(claim) != AUTHORITY_FIELDS or type(claim["schema_version"]) is not int or claim["schema_version"] != 1:
        raise Refusal("unsupported_authority_schema")
    if (type(claim["transaction_id"]) is not str or not journal.TXN.fullmatch(claim["transaction_id"]) or
        not journal._digest(claim["scope_digest"]) or not journal._digest(claim["latest_event_hash"])):
        raise Refusal("invalid_claim_binding")
    if not (_integer(claim["latest_sequence"], 1, len(journal.PHASES)) and
            _integer(claim["epoch_claim"], 1, 2**31 - 1) and
            _integer(claim["consumed_through_sequence"], 0, len(journal.PHASES)) and
            _integer(claim["revoked_through_sequence"], 0, len(journal.PHASES))):
        raise Refusal("invalid_authority_counter")
    if type(claim["consent_claim"]) is not str or claim["consent_claim"] not in CONSENT:
        raise Refusal("invalid_consent_claim")
    if type(claim["authority_claim_state"]) is not str or claim["authority_claim_state"] not in AUTH_STATES:
        raise Refusal("invalid_authority_state_claim")


def _check_crash(claim: dict) -> None:
    if set(claim) != CRASH_FIELDS or type(claim["schema_version"]) is not int or claim["schema_version"] != 1:
        raise Refusal("unsupported_crash_schema")
    if (type(claim["transaction_id"]) is not str or not journal.TXN.fullmatch(claim["transaction_id"]) or
        not journal._digest(claim["scope_digest"])):
        raise Refusal("invalid_crash_binding")
    if (type(claim["phase"]) is not str or claim["phase"] not in journal.PHASES or
        type(claim["fault_window"]) is not str or claim["fault_window"] not in FAULTS):
        raise Refusal("unknown_crash_window")
    for key in ("same_volume_staging_claimed", "originals_independently_held_claimed",
                "checkpoint_flush_claimed", "parent_metadata_durable_claimed"):
        if type(claim[key]) is not bool:
            raise Refusal("invalid_storage_claim")


def _classify_authority(claim: dict, txn: str, scope: str, count: int,
                        checksum: str) -> list[str]:
    blockers = []
    if (claim["transaction_id"] != txn or claim["scope_digest"] != scope or
        claim["latest_event_hash"] != checksum or claim["latest_sequence"] != count):
        blockers.append("authority_claim_not_bound_to_latest_event")
    if claim["authority_claim_state"] != "claimed_current":
        blockers.append("no_current_independent_authority")
    if claim["consent_claim"] != "claimed_granted":
        blockers.append("consent_not_current_or_consumed")
    if claim["consumed_through_sequence"] >= claim["latest_sequence"]:
        blockers.append("claimed_receipt_already_consumed")
    if claim["revoked_through_sequence"] >= claim["latest_sequence"]:
        blockers.append("claimed_receipt_already_revoked")
    return blockers


def _classify_crash(claim: dict, txn: str, scope: str, phase: str) -> list[str]:
    blockers = []
    if (claim["transaction_id"] != txn or claim["scope_digest"] != scope or
        claim["phase"] != phase):
        blockers.append("crash_claim_not_bound_to_current_phase")
    window = claim["fault_window"]
    if window != "none":
        blockers.append("interrupted_or_powerloss_boundary_preserve")
        if phase not in FAULTS[window]:
            blockers.append("contradictory_crash_window_preserve")
    if not claim["same_volume_staging_claimed"]:
        blockers.append("same_volume_stage_not_even_claimed")
    if not claim["originals_independently_held_claimed"]:
        blockers.append("independent_originals_not_even_claimed")
    if not claim["checkpoint_flush_claimed"] or not claim["parent_metadata_durable_claimed"]:
        blockers.append("checkpoint_or_metadata_durability_not_even_claimed")
    return blockers


def review(root: Path, between_observations=None) -> dict:
    root = Path(os.path.abspath(root))
    try:
        integrity.fixture_guard(root)
        marker = journal._regular(root / MARKER, len(MARKER_BYTES))
        if marker != MARKER_BYTES:
            raise Refusal("not_disposable_authority_fixture")
        # An extra guard: require the previous journal marker before reading
        # any original/backup/current fixture bytes.
        if journal._regular(root / journal.MARKER, len(journal.MARKER_BYTES)) != journal.MARKER_BYTES:
            raise Refusal("not_disposable_journal_fixture")
        auth_bytes, auth = _read_claim(root / AUTHORITY)
        crash_bytes, crash = _read_claim(root / CRASH)
        _check_authority(auth)
        _check_crash(crash)
        raw_journal = journal._regular(root / journal.JOURNAL, journal.MAX_JSON)
        txn, scope, count, phase, checksum = journal._journal_check(journal._json(raw_journal))
        blockers = _classify_authority(auth, txn, scope, count, checksum)
        blockers.extend(_classify_crash(crash, txn, scope, phase))

        if between_observations is not None:
            # Unit tests can mutate FAKE bytes, this source only reads.
            between_observations()
        journal_result = journal.review(root)
        auth_again, _ = _read_claim(root / AUTHORITY)
        crash_again, _ = _read_claim(root / CRASH)
        if auth_bytes != auth_again or crash_bytes != crash_again:
            raise Refusal("authority_or_crash_claim_changed_during_review")
        if raw_journal != journal._regular(root / journal.JOURNAL, journal.MAX_JSON):
            raise Refusal("journal_changed_during_authority_review")
    except (integrity.Refusal, journal.Refusal) as exc:
        raise Refusal("underlying_synthetic_evidence_unsafe") from exc

    if journal_result["status"] != "claims_consistent_NO_AUTHORITY":
        blockers.append("existing_journal_or_content_review_requires_manual_attention")
    # No trust is awarded to a caller-edited authority and crash file, even
    # when the claims are mutually consistent or all their booleans are true.
    return {
        "kind": "naxxramas_synthetic_independent_authority_design_review",
        "schema_version": 1,
        "synthetic_fixture_only": True,
        "read_only": True,
        "status": "manual_review_required" if blockers else "claims_consistent_but_NOT_AUTHENTICATED",
        "journal_phase": journal_result["phase_observed"],
        "claimed_fault_window": crash["fault_window"],
        "blockers": list(dict.fromkeys(blockers)),
        "existing_journal_manual_review": journal_result["status"] == "manual_review_required",
        "full_addon_and_whole_wtf_preservation_reviewed": journal_result["entire_wtf_protected"],
        "underlying_backup_mismatch_scopes": journal_result["backup_mismatch_scopes"],
        "underlying_player_or_settings_conflict_scopes": journal_result["player_or_settings_conflict_scopes"],
        "local_claims_are_independent_authority": False,
        "coherent_rollback_of_all_local_claims_detectable": False,
        "user_or_owner_authenticated": False,
        "protected_monotonic_counter_verified": False,
        "one_use_consent_verified": False,
        "write_ahead_durable_checkpoint_verified": False,
        "independent_backup_durability_verified": False,
        "power_loss_recovery_tested": False,
        "real_client_files_read": False,
        "real_client_files_modified": False,
        "backup_copy_or_restore_performed": False,
        "automatic_resume_install_or_recovery_allowed": False,
        "deletion_allowed": False,
        "public_release_authorised": False,
        "private_paths_hashes_or_contents_reported": False,
        "limitations": "Untrusted fake local claims; no monotonic external trust, atomic filesystem transaction, durable checkpoint or authenticated approval.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="SYNTHETIC-ONLY read-only independent-authority design gate")
    parser.add_argument("--synthetic-fixture-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = review(args.synthetic_fixture_root)
    except Refusal as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
