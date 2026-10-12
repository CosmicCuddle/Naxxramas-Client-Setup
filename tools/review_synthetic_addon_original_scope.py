#!/usr/bin/env python3
"""Developer-only, SYNTHETIC-ONLY addon/WTF original-scope inspector.

Read-only filesystem metadata inventory. Never copies, backs up, restores,
hashes, opens or outputs user configuration files. Not included in player ZIP.
The fake-client marker is a guard against accidental use, NOT authentication.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import stat
import sys

MARKER = ".naxx-synthetic-only"
MARKER_BYTES = b"NAXXRAMAS_TEST_ONLY_NO_PLAYER_CLIENT\n"
SUITE = ("NCore", "IndividualProgressionAddon", "DungeonJournal", "MultiBot", "NaxxLootLottery")
LEGACY = ("NClassicBattlegrounds", "ServerDungeonJournal")
MAX_ENTRIES = 50000
MAX_DEPTH = 24
MAX_TOTAL_BYTES = 64 * 1024**3
REPARSE_POINT = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)


class ReviewError(ValueError):
    """Contains a fixed, path-free refusal explanation."""


def _metadata(path: Path) -> os.stat_result:
    try:
        return path.lstat()
    except OSError as exc:
        raise ReviewError("unreadable_or_disappeared_entry") from exc


def _linked(meta: os.stat_result) -> bool:
    return stat.S_ISLNK(meta.st_mode) or bool(
        getattr(meta, "st_file_attributes", 0) & REPARSE_POINT
    )


def _normal_directory(path: Path) -> None:
    info = _metadata(path)
    if _linked(info) or not stat.S_ISDIR(info.st_mode):
        raise ReviewError("linked_or_non_directory")


def _parent_safe(path: Path) -> None:
    # Absolute path construction does not resolve symlinks. Check every
    # existing ancestor, including a possibly linked fixture root itself.
    for node in (*reversed(path.parents), path):
        _normal_directory(node)


def _fixture_guard(root: Path) -> None:
    _parent_safe(root)
    marker = root / MARKER
    info = _metadata(marker)
    if _linked(info) or not stat.S_ISREG(info.st_mode) or info.st_size != len(MARKER_BYTES):
        raise ReviewError("not_a_disposable_synthetic_fixture")
    try:
        with marker.open("rb") as stream:
            if stream.read(len(MARKER_BYTES) + 1) != MARKER_BYTES:
                raise ReviewError("not_a_disposable_synthetic_fixture")
    except OSError as exc:
        raise ReviewError("not_a_disposable_synthetic_fixture") from exc


def _list_entries(folder: Path) -> list[os.DirEntry]:
    try:
        with os.scandir(folder) as iterator:
            entries = list(iterator)
    except OSError as exc:
        raise ReviewError("unreadable_directory") from exc
    # A case-insensitive Windows filesystem could interpret different entry
    # spellings as the same intended path. Don't treat these as distinct.
    names = [entry.name.casefold() for entry in entries]
    if len(names) != len(set(names)):
        raise ReviewError("case_colliding_entries")
    return entries


def _scope(root: Path, name: str, kind: str) -> dict:
    row = {
        "scope": name,
        "kind": kind,
        "state": "absent",
        "files_observed": 0,
        "directories_observed": 0,
        "original_bytes_observed": 0,
        "unsafe_reason": "",
        "scope_complete_or_verified": False,
        "backup_created": False,
        "restore_authorised": False,
    }
    if not os.path.lexists(root):
        return row
    total_files = 0
    total_dirs = 0
    total_bytes = 0
    entries_seen = 0
    pending = [(root, 0)]
    try:
        while pending:
            folder, depth = pending.pop()
            if depth > MAX_DEPTH:
                raise ReviewError("directory_depth_limit")
            _normal_directory(folder)
            total_dirs += 1
            for entry in _list_entries(folder):
                entries_seen += 1
                if entries_seen > MAX_ENTRIES:
                    raise ReviewError("entry_limit")
                meta = _metadata(Path(entry.path))
                if _linked(meta):
                    raise ReviewError("linked_or_reparse_entry")
                if stat.S_ISDIR(meta.st_mode):
                    pending.append((Path(entry.path), depth + 1))
                elif stat.S_ISREG(meta.st_mode):
                    if meta.st_nlink > 1:
                        raise ReviewError("hardlinked_file")
                    total_files += 1
                    total_bytes += meta.st_size
                    if total_bytes > MAX_TOTAL_BYTES:
                        raise ReviewError("observed_byte_limit")
                else:
                    raise ReviewError("unsupported_file_type")
        row.update(
            state="present_unverified_metadata",
            files_observed=total_files,
            directories_observed=total_dirs,
            original_bytes_observed=total_bytes,
        )
    except ReviewError as exc:
        row["state"] = "unsafe_preserve_manual_review"
        row["unsafe_reason"] = str(exc)
        # Partial counts are deliberately withheld, not mislabelled complete.
    return row


def review(root: Path) -> dict:
    root = Path(os.path.abspath(root))
    _fixture_guard(root)
    addons_parent = root / "Interface" / "AddOns"
    addon_entries: dict[str, Path] = {}
    parent_failure = ""
    try:
        if addons_parent.parent.exists() or os.path.lexists(addons_parent.parent):
            _normal_directory(addons_parent.parent)
        if os.path.lexists(addons_parent):
            _normal_directory(addons_parent)
            # Inspect immediate entry names ONLY; do not descend into any
            # unrelated addon. Unknown third-party addons remain untouched.
            addon_entries = {e.name: Path(e.path) for e in _list_entries(addons_parent)}
    except ReviewError as exc:
        parent_failure = str(exc)

    rows = []
    for name in (*SUITE, *LEGACY):
        candidates = [p for label, p in addon_entries.items() if label.casefold() == name.casefold()]
        if parent_failure:
            row = _scope(root / "__absent_scope__", name, "suite" if name in SUITE else "legacy")
            row.update(state="unsafe_preserve_manual_review", unsafe_reason="unsafe_addons_parent")
        elif len(candidates) > 1:
            row = _scope(root / "__absent_scope__", name, "suite" if name in SUITE else "legacy")
            row.update(state="unsafe_preserve_manual_review", unsafe_reason="ambiguous_addon_folder")
        elif len(candidates) == 1 and candidates[0].name != name:
            row = _scope(root / "__absent_scope__", name, "suite" if name in SUITE else "legacy")
            row.update(state="unsafe_preserve_manual_review", unsafe_reason="case_mismatched_folder")
        else:
            row = _scope(candidates[0] if candidates else addons_parent / name,
                         name, "suite" if name in SUITE else "legacy")
        rows.append(row)

    # WHOLE WTF: includes Config, every account, every realm, every character,
    # every SavedVariables directory, extra unknown files and nested profiles.
    rows.append(_scope(root / "WTF", "WTF (all profiles)", "private_settings"))
    unsafe_count = sum(x["state"] == "unsafe_preserve_manual_review" for x in rows)
    return {
        "kind": "naxxramas_synthetic_addon_original_scope_review",
        "schema_version": 1,
        "synthetic_fixture_only": True,
        "read_only": True,
        "status": "unsafe_scope_manual_review" if unsafe_count else "scope_observation_only_not_backup",
        "scopes": rows,
        "suite_folder_count": len(SUITE),
        "legacy_folder_count": len(LEGACY),
        "unsafe_scope_count": unsafe_count,
        "whole_wtf_tree_in_scope": True,
        "private_settings_contents_read": False,
        "unrelated_addon_contents_read": False,
        "user_paths_or_filenames_reported": False,
        "exact_verified_original_inventory": False,
        "atomic_snapshot": False,
        "backup_created": False,
        "backup_verified": False,
        "restoration_tested": False,
        "any_client_file_modified": False,
        "installation_update_or_recovery_authorised": False,
        "public_release_authorised": False,
        "limitations": "Synthetic metadata only; caller-controlled fixture marker, no content hashes, reliable Windows ownership, atomicity, crash-durable backups, protected journal or player consent.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only synthetic addon/WTF preservation-scope fixture review")
    parser.add_argument("--synthetic-fixture-client", required=True, type=Path,
                        help="Path to disposable generated client fixture, never a real game client")
    args = parser.parse_args()
    try:
        report = review(args.synthetic_fixture_client)
    except ReviewError as exc:
        # No path or private filenames in exceptions or JSON.
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
