#!/usr/bin/env python3
"""Opt-in, read-only patch preflight for a MARKED disposable test client.

Not an installer, source authenticator, anti-rollback system, gameplay or
accessibility validator. Never opens WTF, settings, add-ons or player media.
No reports or game files are written. Windows and Linux synthetic CI only.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import stat
import sys
import json

import review_patch_update_proposal as review

MARKER = ".naxx-disposable-test-client-read-only"
MARKER_CONTENT = b"NAXX_DISPOSABLE_TEST_CLIENT_REVIEW_ONLY_V1\n"
MAX_PATCH_SIZE = 1024 * 1024 * 1024
CHUNK = 1024 * 1024
PATHS = (
    ("V", "patch-V.mpq", True),
    ("Z", "patch-Z.mpq", True),
    ("J", "Patch-J.mpq", False),
    ("C", "Patch-C.mpq", False),
    ("U", "Patch-U.mpq", False),
)
OPTIONS = {
    "base": (),
    "u": ("U",),
    "j": ("J",),
    "j-u": ("J", "U"),
    "c": ("C",),
    "c-u": ("C", "U"),
}
KNOWN = {name: (code, required) for code, name, required in PATHS}


class Refusal(ValueError):
    """Safe, fixed error code; never include user paths in exception text."""


def _not_linked(path: Path):
    """Reject symlink/junction anywhere in an input's lexical ancestry."""
    for part in (path, *path.parents):
        try:
            if part.is_symlink() or (hasattr(os.path, "isjunction") and os.path.isjunction(part)):
                raise Refusal("linked_disposable_client_path")
        except OSError as exc:
            raise Refusal("unsafe_disposable_client_path") from exc


def _root_safety(root: Path):
    _not_linked(root)
    if not root.is_dir():
        raise Refusal("disposable_client_directory_missing")
    marker = root / MARKER
    _not_linked(marker)
    try:
        with marker.open("rb") as stream:
            fs = os.fstat(stream.fileno())
            if not stat.S_ISREG(fs.st_mode) or fs.st_nlink != 1 or fs.st_size != len(MARKER_CONTENT):
                raise Refusal("missing_or_unsafe_disposable_marker")
            content = stream.read(len(MARKER_CONTENT) + 1)
    except (FileNotFoundError, PermissionError, IsADirectoryError) as exc:
        raise Refusal("missing_or_unsafe_disposable_marker") from exc
    if content != MARKER_CONTENT:
        raise Refusal("disposable_marker_content_not_trusted")
    # Caller can add/duplicate this marker. This is opt-in, NOT proof that
    # the directory is really disposable or separate from a working client.


def _file_status(path: Path, expected_hash: str, expected_size: int) -> str:
    _not_linked(path)
    try:
        with path.open("rb") as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
                return "UNSAFE_FILE_TYPE_OR_LINK"
            if before.st_size > MAX_PATCH_SIZE or before.st_size < 1:
                return "UNSAFE_FILE_LENGTH"
            if before.st_size != expected_size:
                return "SIZE_MISMATCH"
            h = hashlib.sha256()
            total = 0
            while True:
                part = stream.read(CHUNK)
                if not part:
                    break
                total += len(part)
                if total > MAX_PATCH_SIZE:
                    return "UNSAFE_FILE_LENGTH"
                h.update(part)
            after = os.fstat(stream.fileno())
        now = path.stat()
    except FileNotFoundError:
        return "NOT_PRESENT"
    except (PermissionError, IsADirectoryError, OSError):
        return "UNREADABLE_FILE"
    if (total != before.st_size or before.st_size != after.st_size or
        before.st_mtime_ns != after.st_mtime_ns or
        (before.st_ino and (before.st_ino != after.st_ino or before.st_ino != now.st_ino)) or
        after.st_size != now.st_size or after.st_mtime_ns != now.st_mtime_ns):
        return "UNSTABLE_DURING_SCAN"
    return "MATCHES_PINNED_SHA256_AND_SIZE_NOT_PROVENANCE" if h.hexdigest() == expected_hash else "SHA256_MISMATCH"


def _expected(pins: list) -> dict:
    if type(pins) is not list or len(pins) != 5:
        raise Refusal("invalid_expected_patch_policy")
    out = {}
    for (code, basename, required), row in zip(PATHS, pins):
        if (type(row) is not dict or row.get("path") != "Data/" + basename or
            row.get("required") is not required or
            type(row.get("sha256")) is not str or
            re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is None or
            type(row.get("size_bytes")) is not int or
            not 1 <= row["size_bytes"] <= MAX_PATCH_SIZE):
            raise Refusal("invalid_expected_patch_policy")
        out[code] = (row["sha256"], row["size_bytes"])
    return out


def inspect(root: Path, pins: list, selection: str, *, fixture_policy: bool = False) -> dict:
    if selection not in OPTIONS:
        raise Refusal("unknown_optional_patch_selection")
    expected = _expected(pins)
    root = Path(root).absolute()
    _root_safety(root)
    data = root / "Data"
    _not_linked(data)
    if not data.is_dir():
        raise Refusal("disposable_client_Data_missing")
    # Only inspect the direct Data folder. Do NOT recursively inspect folders,
    # WTF, account settings, realm hostname, screenshots, or installed AddOns.
    try:
        entries = [e.name for e in os.scandir(data)]
    except OSError as exc:
        raise Refusal("unreadable_disposable_Data_directory") from exc
    folds = [x.casefold() for x in entries]
    if len(set(folds)) != len(folds):
        raise Refusal("ambiguous_case_colliding_Data_entries")
    expected_names = [name for _, name, _ in PATHS]
    for name in expected_names:
        if name not in entries and name.casefold() in folds:
            raise Refusal("unexpected_patch_filename_case")
    unknown_patch_names = [
        name for name in entries
        if name.lower().endswith(".mpq") and name.lower().startswith("patch-") and
        name not in expected_names
    ]
    present = set(entries)
    selected = {"V", "Z", *OPTIONS[selection]}
    rows = []
    reasons = []
    matched_selected = True
    unselected_present = False
    for code, name, _ in PATHS:
        if name in present:
            status = _file_status(data / name, *expected[code])
        else:
            status = "NOT_PRESENT"
        is_selected = code in selected
        if is_selected and status != "MATCHES_PINNED_SHA256_AND_SIZE_NOT_PROVENANCE":
            matched_selected = False
            reasons.append("selected_patch_missing_or_metadata_mismatch")
        if not is_selected and status != "NOT_PRESENT":
            unselected_present = True
            reasons.append("unselected_optional_patch_physically_present")
        rows.append({"patch_id": code, "selected_in_claimed_scenario": is_selected,
                     "local_metadata": status})
    if unknown_patch_names:
        reasons.append("unrecognised_patch_mpq_in_Data")
    if "J" in selected and "U" in selected:
        reasons.append("j_u_loading_texture_overlap_requires_in_game_review")
    # Plain file presence is not proof of WoW version or genuine enUS locale.
    exe = root / "Wow.exe"
    locale = data / "enUS"
    _not_linked(exe)
    _not_linked(locale)
    game_exe_present = exe.is_file()
    locale_directory_present = locale.is_dir()
    if not game_exe_present:
        reasons.append("missing_expected_game_executable")
    if not locale_directory_present:
        reasons.append("missing_expected_locale_folder")
    if fixture_policy:
        reasons.append("synthetic_fixture_policy_not_source_provenance")
    clean = bool(matched_selected and not unselected_present and not unknown_patch_names and
                 game_exe_present and locale_directory_present)
    return {
        "kind": "naxxramas_disposable_test_client_patch_preflight",
        "schema_version": 1,
        "status": ("LOCAL_SELECTED_PATCH_BYTES_MATCH_REFERENCE_NOT_GAME_VERIFICATION" if clean
                   else "MANUAL_TEST_CLIENT_REVIEW_REQUIRED"),
        "declared_optional_selection": selection,
        "patch_results": rows,
        "warning_codes": sorted(set(reasons)),
        "unknown_patch_mpq_count": len(unknown_patch_names),
        "selected_patch_metadata_consistent": matched_selected,
        "optional_selection_physically_clean": not unselected_present and not unknown_patch_names,
        "wow_exe_present_not_build_verified": game_exe_present,
        "enUS_folder_present_not_locale_verified": locale_directory_present,
        "marker_claims_disposable_not_authenticated": True,
        "fixture_policy_used_for_test_only": fixture_policy,
        "independently_proven_separate_test_client": False,
        "wow_335a_build_12340_authenticated": False,
        "source_publisher_or_actual_gameplay_verified": False,
        "independent_original_client_baseline_verified": False,
        "physical_windows_accessibility_tested": False,
        "privacy_safe_gameplay_evidence_captured": False,
        "client_or_wtf_modified": False,
        "installer_or_backup_or_restore_performed": False,
        "patchset_or_manifest_written": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_paths_player_data_or_raw_hashes_emitted": False,
        "limitations": "Caller-supplied marker, local bytes and locally pinned SHA-256 cannot prove disposable identity, game build, true source provenance, compatibility, copyright rights, signed custody or permission.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Read only marked disposable test-client patch files")
    parser.add_argument("--test-root", type=Path, required=True)
    parser.add_argument("--selection", choices=list(OPTIONS), required=True)
    args = parser.parse_args()
    try:
        policy = review._check_frozen_history()["patches"]
        result = inspect(args.test_root, policy, args.selection)
    except (Refusal, review.Refusal, OSError) as exc:
        reason = str(exc) if isinstance(exc, (Refusal, review.Refusal)) else "unreadable_test_client"
        print("BLOCKED: " + reason, file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "LOCAL_SELECTED_PATCH_BYTES_MATCH_REFERENCE_NOT_GAME_VERIFICATION" else 3


if __name__ == "__main__":
    raise SystemExit(main())
