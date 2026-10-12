#!/usr/bin/env python3
"""Developer-only, read-only synthetic addon original-copy storage review.

Does NOT create backups, access real WoW files, verify physical disk identity,
prove durability, authenticate storage claims or authorize restoration.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys

import review_synthetic_addon_recovery as integrity
import review_synthetic_addon_journal as journal

MARKER = ".naxx-synthetic-storage-only"
MARKER_BYTES = b"NAXXRAMAS_SYNTHETIC_BACKUP_STORAGE_REVIEW_ONLY\n"
CLAIM = "backup-storage-claim.json"
MAX_CLAIM = 4096
STORAGE_TOKEN = re.compile(r"[A-Za-z0-9_-]{3,32}\Z", re.ASCII)
FIELDS = {
    "schema_version", "original_volume_label", "backup_volume_label",
    "physical_independence_claim", "different_failure_domain_claim",
    "backup_retained_claim", "restore_rehearsed_claim",
}


class Refusal(ValueError):
    """Fixed, private-path-free refusal."""


def _guard(root: Path) -> None:
    try:
        integrity.fixture_guard(root)
        data = journal._regular(root / MARKER, len(MARKER_BYTES))
    except (integrity.Refusal, journal.Refusal) as exc:
        raise Refusal("not_disposable_synthetic_storage_fixture") from exc
    if data != MARKER_BYTES:
        raise Refusal("not_disposable_synthetic_storage_fixture")


def _load_claim(root: Path) -> tuple[bytes, dict]:
    try:
        raw = journal._regular(root / CLAIM, MAX_CLAIM)
        value = journal._json(raw)
    except journal.Refusal as exc:
        raise Refusal("invalid_or_unsafe_local_storage_claim") from exc
    if set(value) != FIELDS or type(value["schema_version"]) is not int or value["schema_version"] != 1:
        raise Refusal("invalid_storage_schema")
    for key in ("original_volume_label", "backup_volume_label"):
        if type(value[key]) is not str or STORAGE_TOKEN.fullmatch(value[key]) is None:
            raise Refusal("invalid_storage_volume_label")
    for key in ("physical_independence_claim", "different_failure_domain_claim",
                "backup_retained_claim", "restore_rehearsed_claim"):
        if type(value[key]) is not bool:
            raise Refusal("invalid_storage_boolean_claim")
    return raw, value


def _snapshot_dir_identity(path: Path) -> tuple[int, int]:
    try:
        m = integrity.directory(path)
    except integrity.Refusal as exc:
        raise Refusal("unsafe_snapshot_directory") from exc
    return (m.st_dev, m.st_ino)


def review(root: Path, between_observations=None) -> dict:
    root = Path(os.path.abspath(root))
    _guard(root)
    raw, claim = _load_claim(root)
    before_original = _snapshot_dir_identity(root / "original")
    before_backup = _snapshot_dir_identity(root / "backup")
    same_logical = before_original[0] == before_backup[0]
    if before_original == before_backup:
        raise Refusal("original_and_backup_same_directory_identity")

    if between_observations is not None:
        # Only disposable unit tests inject mutations; this reader never writes.
        between_observations()
    try:
        byte_report = integrity.review(root)
    except integrity.Refusal as exc:
        raise Refusal("unsafe_synthetic_original_copy_scope") from exc
    if raw != _load_claim(root)[0]:
        raise Refusal("storage_claim_changed_during_review")
    if (before_original != _snapshot_dir_identity(root / "original") or
            before_backup != _snapshot_dir_identity(root / "backup")):
        raise Refusal("snapshot_directory_identity_changed")

    blockers = []
    if same_logical:
        blockers.append("same_logical_volume_observed_not_independent_disaster_recovery")
        if claim["original_volume_label"] != claim["backup_volume_label"]:
            blockers.append("claimed_different_volume_but_observed_same_logical_volume")
    elif claim["original_volume_label"] == claim["backup_volume_label"]:
        blockers.append("claimed_shared_volume_label")
    # Either same or different observed devices is insufficient to establish
    # independent physical spindles, power-loss resilience or isolation.
    if not claim["physical_independence_claim"]:
        blockers.append("physical_storage_independence_not_even_claimed")
    if not claim["different_failure_domain_claim"]:
        blockers.append("independent_failure_domain_not_even_claimed")
    if not claim["backup_retained_claim"]:
        blockers.append("backup_retention_not_even_claimed")
    if not claim["restore_rehearsed_claim"]:
        blockers.append("restore_rehearsal_not_even_claimed")
    if byte_report["unsafe_scopes"]:
        blockers.append("unsafe_original_or_backup_tree_preserve")
    if byte_report["backup_mismatch_scopes"]:
        blockers.append("mismatched_or_missing_original_copy_preserve")
    if byte_report["current_conflict_scopes"]:
        blockers.append("changed_current_addon_or_character_settings_preserve")

    return {
        "kind": "naxxramas_synthetic_addon_backup_storage_review",
        "schema_version": 1,
        "synthetic_fixture_only": True,
        "read_only": True,
        "status": "manual_review_required",
        "backup_copy_observation": (
            "scope_bytes_match_untrusted" if not (byte_report["unsafe_scopes"] or
                                                   byte_report["backup_mismatch_scopes"])
            else "unusable_or_incomplete_original_copy"
        ),
        "observed_logical_volume_relation": (
            "same_logical_volume_not_independent" if same_logical
            else "different_logical_volume_not_physical_independence_proof"
        ),
        "scope_count": byte_report["scopes_checked"],
        "unsafe_scope_count": byte_report["unsafe_scopes"],
        "copy_mismatch_scope_count": byte_report["backup_mismatch_scopes"],
        "player_change_scope_count": byte_report["current_conflict_scopes"],
        "all_fake_wtf_accounts_and_characters_included": byte_report["whole_wtf_included"],
        "blockers": list(dict.fromkeys(blockers)),
        "private_paths_names_hashes_or_claimed_labels_reported": False,
        "device_ids_exposed": False,
        "different_physical_storage_verified": False,
        "independent_power_failure_domain_verified": False,
        "durable_backup_bytes_verified": False,
        "authenticated_backup_ownership_verified": False,
        "independent_original_backup_or_restore_verified": False,
        "restoration_rehearsal_verified": False,
        "storage_claim_authenticated": False,
        "game_client_file_read_or_write_performed": False,
        "backup_created_or_deleted": False,
        "restore_or_install_authorised": False,
        "public_release_authorised": False,
        "limitations": "Same/different st_dev is only a logical filesystem observation. Caller-controlled storage labels, backup bytes and claimed rehearsal are not trustworthy, atomic, physically independent or durable.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="SYNTHETIC ONLY read-only backup storage failure-domain review")
    parser.add_argument("--synthetic-fixture-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        report = review(args.synthetic_fixture_root)
    except Refusal as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
