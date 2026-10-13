#!/usr/bin/env python3
"""Review a patch-update PROPOSAL against frozen public evidence, without writes.

No MPQ, WoW executable, client directory, updater, backup or network request.
This does not authenticate the proposal, establish asset rights, or approve it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import review_public_release_drift as drift

ROOT = Path(__file__).resolve().parents[1]
HISTORY_DIR = ROOT / "config" / "patch-versions"
CURRENT = ROOT / "config" / "client-patches.json"
HISTORICAL_BLOBS = {
    1: "39a8e77d040561930ea2dc076d636664755afaa5",
    2: "deb4a4573401d98d2104f35433b3dce3720cb1f9",
}
PATHS = ("Data/patch-V.mpq", "Data/patch-Z.mpq", "Data/Patch-J.mpq",
         "Data/Patch-C.mpq", "Data/Patch-U.mpq")
IDS = ("patch-v", "patch-z", "patch-j", "patch-c", "patch-u")
KEYS = frozenset(("proposal_schema_version", "kind", "base_patch_set_revision",
                  "proposed_patch_set_revision", "proposed_patch_set_version",
                  "created_utc", "note", "files_checked", "changes"))
CHECKED_KEYS = frozenset(("path", "required", "sha256", "size_bytes", "changed"))
CHANGE_KEYS = frozenset(("path", "previous_sha256", "new_sha256",
                         "previous_size_bytes", "new_size_bytes"))
CREATED = re.compile(r"20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\Z")
MAX_PROPOSAL = 96 * 1024


class Refusal(ValueError):
    """Fixed, privacy-safe refusal reason, never a client path or hash."""


def _integer(value, low=0):
    return type(value) is int and value >= low


def _digest(value):
    return type(value) is str and drift.SHA.fullmatch(value) is not None


def _read_bytes(path: Path, maximum=MAX_PROPOSAL):
    try:
        if path.is_symlink() or not path.is_file() or path.stat().st_size > maximum:
            raise Refusal("unsafe_or_oversized_local_json")
        raw = path.read_bytes()
        if not raw or len(raw) > maximum:
            raise Refusal("unsafe_or_oversized_local_json")
        return raw
    except OSError as exc:
        raise Refusal("unsafe_or_unreadable_local_json") from exc


def _load(path: Path):
    return drift._decode(_read_bytes(path))


def _check_frozen_history():
    history = {}
    for revision, expected_git_blob in HISTORICAL_BLOBS.items():
        path = HISTORY_DIR / ("patchset-%04d.json" % revision)
        raw = _read_bytes(path)
        # GitHub source blob IDs use canonical committed LF data, while
        # windows-latest can check out these text files with CRLF endings.
        # Normalise only the line-ending representation for this reference
        # check; any changed key, digest, size or semantic JSON is refused.
        canonical = raw.replace(b"\r\n", b"\n")
        git_blob = hashlib.sha1(b"blob " + str(len(canonical)).encode("ascii") +
                                b"\0" + canonical).hexdigest()
        if git_blob != expected_git_blob:
            raise Refusal("historical_patchset_changed_from_reviewed_baseline")
        data = drift._decode(raw)
        if (type(data) is not dict or data.get("revision") != revision or
            data.get("version") != ("patchset-%04d" % revision) or
            data.get("public_distribution_approved") is not False or
            data.get("playable_build_verified") is not False or
            type(data.get("patches")) is not list or
            len(data["patches"]) != (4 if revision == 1 else 5)):
            raise Refusal("invalid_frozen_patchset")
        history[revision] = data
    current = _load(CURRENT)
    second = history[2]
    if (type(current) is not dict or
        current.get("patch_set_revision") != 2 or
        current.get("patch_set_version") != second["version"] or
        type(current.get("patches")) is not list or len(current["patches"]) != 5):
        raise Refusal("current_manifest_does_not_match_frozen_base")
    for index, (name, item) in enumerate(zip(PATHS, second["patches"])):
        c = current["patches"][index]
        if (type(c) is not dict or type(item) is not dict or
            c.get("path") != name or item.get("path") != name or
            type(c.get("public_distribution_approved")) is not bool or
            c["public_distribution_approved"] or
            any(c.get(field) != item.get(field)
                for field in ("required", "sha256", "size_bytes"))):
            raise Refusal("current_manifest_does_not_match_frozen_base")
    policy = current.get("validation_policy")
    if (type(policy) is not dict or
        policy.get("optional_login_mutex") != ["Data/Patch-J.mpq", "Data/Patch-C.mpq"] or
        policy.get("do_not_delete_existing_client_files") is not True or
        policy.get("backup_before_overwrite") is not True):
        raise Refusal("required_client_safeguards_not_present")
    # Repo-local Git hashes are NOT trusted independently protected history.
    # They only catch accidental edits unless an attacker also changes code.
    return second


def _proposal_checks(proposal, frozen):
    if type(proposal) is not dict or set(proposal) != KEYS:
        raise Refusal("unrecognised_proposal_schema")
    if (type(proposal["proposal_schema_version"]) is not int or
        proposal["proposal_schema_version"] != 1 or
        proposal["kind"] != "review_only_not_published" or
        type(proposal["base_patch_set_revision"]) is not int or
        proposal["base_patch_set_revision"] != 2 or
        type(proposal["proposed_patch_set_revision"]) is not int or
        proposal["proposed_patch_set_revision"] != 3 or
        proposal["proposed_patch_set_version"] != "patchset-0003" or
        type(proposal["created_utc"]) is not str or
        CREATED.fullmatch(proposal["created_utc"]) is None or
        type(proposal["note"]) is not str or not 10 <= len(proposal["note"]) <= 700):
        raise Refusal("stale_or_untrusted_proposal_base")
    checked = proposal["files_checked"]
    changes = proposal["changes"]
    if (type(checked) is not list or not 2 <= len(checked) <= 5 or
        type(changes) is not list or not 1 <= len(changes) <= 5):
        raise Refusal("missing_or_unbounded_proposal_files")
    frozen_items = {x["path"]: x for x in frozen["patches"]}
    observed_paths = []
    observed = {}
    actual_changed = []
    for row in checked:
        if type(row) is not dict or set(row) != CHECKED_KEYS:
            raise Refusal("unexpected_checked_file_fields")
        path = row["path"]
        if (type(path) is not str or path not in frozen_items or
            path in observed or type(row["required"]) is not bool or
            row["required"] is not frozen_items[path]["required"] or
            not _digest(row["sha256"]) or not _integer(row["size_bytes"], 1) or
            type(row["changed"]) is not bool):
            raise Refusal("ambiguous_or_untrusted_checked_file")
        base = frozen_items[path]
        really_changed = ((row["sha256"], row["size_bytes"]) !=
                          (base["sha256"], base["size_bytes"]))
        if really_changed != row["changed"]:
            raise Refusal("proposal_change_flag_contradicts_pinned_bytes")
        if really_changed:
            actual_changed.append(path)
        observed[path] = row
        observed_paths.append(path)
    if "Data/patch-V.mpq" not in observed or "Data/patch-Z.mpq" not in observed:
        raise Refusal("required_patch_not_checked")
    if observed_paths != [p for p in PATHS if p in observed]:
        raise Refusal("proposal_check_order_drift")
    recorded_changes = set()
    for change in changes:
        if type(change) is not dict or set(change) != CHANGE_KEYS:
            raise Refusal("malformed_changed_file")
        path = change["path"]
        if type(path) is not str or path not in actual_changed or path in recorded_changes:
            raise Refusal("duplicate_or_unobserved_change")
        original = frozen_items[path]
        got = observed[path]
        if (not _digest(change["previous_sha256"]) or
            not _digest(change["new_sha256"]) or
            not _integer(change["previous_size_bytes"], 1) or
            not _integer(change["new_size_bytes"], 1) or
            (change["previous_sha256"], change["previous_size_bytes"]) !=
            (original["sha256"], original["size_bytes"]) or
            (change["new_sha256"], change["new_size_bytes"]) !=
            (got["sha256"], got["size_bytes"])):
            raise Refusal("proposal_before_after_evidence_inconsistent")
        recorded_changes.add(path)
    if recorded_changes != set(actual_changed):
        raise Refusal("proposal_missing_a_detected_change")
    if [c["path"] for c in changes] != actual_changed:
        raise Refusal("changed_file_order_drift")
    return observed, actual_changed


def review(proposal, release_snapshot):
    frozen = _check_frozen_history()
    observed, changed = _proposal_checks(proposal, frozen)
    if type(release_snapshot) is not dict or set(release_snapshot) != {"patch_releases", "addon_releases"}:
        raise Refusal("incomplete_public_release_snapshot")
    releases = drift._validate_releases(release_snapshot["patch_releases"])
    # Validate addon release records too; do not compare them to patch changes.
    drift._validate_releases(release_snapshot["addon_releases"])
    ids = dict(zip(PATHS, IDS))
    checked = []
    for path, row in observed.items():
        asset_id = ids[path]
        if path not in changed:
            status = "matches_current_pinned_bytes_only"
        else:
            newest = drift._latest_asset(releases, drift.FILES[asset_id],
                                         drift.SOURCE_GROUP[asset_id])
            if newest is None:
                status = "no_stable_published_asset_evidence"
            elif (newest[1][1], newest[1][0]) == (row["sha256"], row["size_bytes"]):
                status = "changed_bytes_match_public_release_metadata_NOT_APPROVAL"
            else:
                status = "new_bytes_not_in_latest_public_release_metadata"
        checked.append({"id": asset_id, "status": status, "changed": path in changed})
    warn = []
    if "Data/Patch-C.mpq" in observed and "Data/Patch-J.mpq" in observed:
        warn.append("optional_c_j_both_present_login_mutex_requires_review")
    if "Data/Patch-J.mpq" in observed and "Data/Patch-U.mpq" in observed:
        warn.append("optional_j_u_loading_texture_overlap_requires_review")
    return {
        "kind": "naxxramas_patch_update_proposal_evidence_review",
        "schema_version": 1,
        "read_only": True,
        "status": "manual_review_required_NO_INSTALL_AUTHORITY",
        "base_patchset": "patchset-0002",
        "hypothetical_next_patchset": "patchset-0003_NOT_CREATED",
        "checked_count": len(checked),
        "changed_count": len(changed),
        "items": checked,
        "warnings": warn,
        "proposal_content_authenticated": False,
        "publisher_authenticated": False,
        "published_digest_independently_rehashed": False,
        "immutable_history_independently_protected": False,
        "original_client_or_settings_read": False,
        "original_client_or_settings_modified": False,
        "manifest_or_patchset_modified": False,
        "new_patchset_created": False,
        "gameplay_compatibility_verified": False,
        "backup_or_restore_performed": False,
        "installation_authorised": False,
        "redistribution_authorised": False,
        "public_release_authorised": False,
        "private_paths_hashes_or_timestamps_reported": False,
        "limitations": "Caller-authored proposed bytes and public release metadata, no authenticated author/owner permission, real binary rehash or gameplay tests. A local Git blob pin is not an independent anti-rollback authority.",
    }


def main():
    parser = argparse.ArgumentParser(description="Read-only developer patch update proposal evidence review")
    parser.add_argument("--proposal", type=Path, required=True)
    parser.add_argument("--release-snapshot", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = review(_load(args.proposal), _load(args.release_snapshot))
    except (Refusal, drift.Refusal) as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
