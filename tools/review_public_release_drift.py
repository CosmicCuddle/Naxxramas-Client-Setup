#!/usr/bin/env python3
"""Public GitHub release metadata drift observer; developer-only READ ONLY.

Reads strictly bounded public GitHub release JSON or disposable test fixture.
NEVER downloads MPQs/ZIPs, reads player clients, modifies pinned policy,
authenticates a publisher, or authorises installation, backups or distribution.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
RIGHTS = ROOT / "docs" / "release-rights-evidence-v1.json"
CATALOG = ROOT / "config" / "optional-content.json"
PATCH_POLICY = ROOT / "config" / "patch-versions" / "patchset-0002.json"
HOST = "https://api.github.com/repos/CosmicCuddle/"
URLS = (
    HOST + "Naxxramas-Server-Patches/releases?per_page=100",
    HOST + "N-Addon-Collection/releases?per_page=100",
)
MAX_FILE = 3 * 1024 * 1024
TAG = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}\Z", re.ASCII)
SHA = re.compile(r"[0-9a-f]{64}\Z", re.ASCII)
DATE = re.compile(r"20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\Z")
ITEM_KEYS = ("patch-v", "patch-z", "patch-j", "patch-c", "patch-u")
FILES = {
    "patch-v": "patch-V.mpq", "patch-z": "patch-Z.mpq",
    "patch-j": "Patch-J.mpq", "patch-c": "Patch-C.mpq",
    "patch-u": "Patch-U.mpq",
}
SOURCE_GROUP = {k: "main" if k in ("patch-v", "patch-z") else "optional" for k in ITEM_KEYS}


class Refusal(ValueError):
    """Fixed, path-free refusal code."""


def _unique_keys(items):
    result = {}
    for key, value in items:
        if key in result:
            raise Refusal("duplicate_json_key")
        result[key] = value
    return result


def _decode(raw: bytes):
    if len(raw) == 0 or len(raw) > MAX_FILE:
        raise Refusal("metadata_missing_or_too_large")
    try:
        return json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_keys,
                          parse_constant=lambda _: (_ for _ in ()).throw(Refusal("invalid_json_constant")))
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise Refusal("invalid_public_release_json") from exc


def _local(path: Path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_FILE:
        raise Refusal("unsafe_or_oversized_metadata_file")
    return _decode(path.read_bytes())


def _live(url: str):
    if url not in URLS:
        raise Refusal("unapproved_release_endpoint")
    req = urllib.request.Request(
        url, headers={"Accept": "application/vnd.github+json",
                      "User-Agent": "Naxxramas-ReadOnly-Release-Reference-Review/1.0",
                      "X-GitHub-Api-Version": "2022-11-28"})
    try:
        with urllib.request.urlopen(req, timeout=12) as response:
            if response.geturl() != url or response.status != 200:
                raise Refusal("public_release_endpoint_redirect_or_error")
            raw = response.read(MAX_FILE + 1)
            return _decode(raw)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        raise Refusal("public_release_metadata_unavailable") from exc


def _validate_releases(value):
    if type(value) is not list or not 1 <= len(value) <= 100:
        raise Refusal("incomplete_or_oversized_release_list")
    parsed = []
    for rel in value:
        if type(rel) is not dict:
            raise Refusal("malformed_public_release")
        tag, date, assets = rel.get("tag_name"), rel.get("published_at"), rel.get("assets")
        if (type(tag) is not str or TAG.fullmatch(tag) is None or
            type(date) is not str or DATE.fullmatch(date) is None or
            type(rel.get("draft")) is not bool or
            type(rel.get("prerelease")) is not bool or
            type(assets) is not list or len(assets) > 40):
            raise Refusal("malformed_public_release")
        found = {}
        for asset in assets:
            if type(asset) is not dict:
                raise Refusal("malformed_public_asset")
            name, size, digest = asset.get("name"), asset.get("size"), asset.get("digest")
            if (type(name) is not str or len(name) > 128 or
                re.fullmatch(r"[A-Za-z0-9._-]+", name) is None or
                type(size) is not int or size <= 0 or size > 2**40 or
                type(digest) is not str or not digest.startswith("sha256:") or
                SHA.fullmatch(digest[7:]) is None or name in found):
                raise Refusal("missing_or_ambiguous_public_asset_digest")
            found[name] = (size, digest[7:])
        if rel["draft"] or rel["prerelease"]:
            continue
        parsed.append((date, tag, found))
    if not parsed:
        raise Refusal("no_stable_published_release")
    return sorted(parsed, key=lambda item: (item[0], item[1]), reverse=True)


def _latest_asset(releases, name, kind):
    for date, tag, assets in releases:
        if kind == "main" and re.fullmatch(r"v[0-9]+(?:\.[0-9]+)+", tag) is None:
            continue
        if kind == "optional" and not tag.startswith("optional-"):
            continue
        if name in assets:
            return tag, assets[name]
    return None


def _pinned():
    rights = _local(RIGHTS)
    catalog = _local(CATALOG)
    policy = _local(PATCH_POLICY)
    if (type(rights) is not dict or rights.get("schema_version") != 1 or
        type(rights.get("items")) is not list or
        type(policy) is not dict or policy.get("version") != "patchset-0002" or
        type(policy.get("patches")) is not list or len(policy["patches"]) != 5):
        raise Refusal("incomplete_pinned_reference")
    rows = {a.get("id"): a for a in rights["items"] if type(a) is dict}
    if len(rows) != len(rights["items"]):
        raise Refusal("ambiguous_pinned_reference")
    paths = {p.get("path"): p for p in policy["patches"] if type(p) is dict}
    if len(paths) != 5:
        raise Refusal("ambiguous_patchset_reference")
    expected = {}
    for key in ITEM_KEYS:
        row = rows.get(key)
        match = paths.get("Data/" + FILES[key])
        if not row or not match or row.get("file") != FILES[key]:
            raise Refusal("incomplete_patch_reference")
        tag, digest, size = row.get("release"), row.get("sha256"), row.get("size_bytes")
        if (type(tag) is not str or TAG.fullmatch(tag) is None or
            type(digest) is not str or SHA.fullmatch(digest) is None or
            type(size) is not int or size <= 0 or
            (match.get("sha256"), match.get("size_bytes")) != (digest, size) or
            match.get("required") is not (key in ("patch-v", "patch-z"))):
            raise Refusal("pinned_patch_policy_disagreement")
        if row.get("redistribution_cleared") is not False or row.get("installation_approved") is not False:
            raise Refusal("unexpected_asset_authority")
        expected[key] = (tag, digest, size)
    ac = catalog.get("addon_suite") if type(catalog) is dict else None
    if (type(ac) is not dict or ac.get("install_approved") is not False or
        ac.get("automatic_download_approved") is not False or
        ac.get("version") != "v2.0.0" or ac.get("archive_name") != "N-Addon-Collection-v2.0.0.zip" or
        type(ac.get("archive_sha256")) is not str or SHA.fullmatch(ac["archive_sha256"]) is None or
        type(ac.get("archive_size_bytes")) is not int):
        raise Refusal("unsafe_or_unknown_addon_reference")
    expected["addon-suite"] = (ac["version"], ac["archive_sha256"], ac["archive_size_bytes"])
    return expected


def review(snapshot):
    if type(snapshot) is not dict or set(snapshot) != {"patch_releases", "addon_releases"}:
        raise Refusal("incomplete_release_snapshot")
    main = _validate_releases(snapshot["patch_releases"])
    addons = _validate_releases(snapshot["addon_releases"])
    expected = _pinned()
    rows = []
    for key in ITEM_KEYS:
        latest = _latest_asset(main, FILES[key], SOURCE_GROUP[key])
        tag, digest, size = expected[key]
        if latest is None:
            status = "missing_stable_published_asset"
            observed_tag = None
        elif (latest[0], latest[1][1], latest[1][0]) == (tag, digest, size):
            status = "pinned_public_metadata_matches"
            observed_tag = latest[0]
        else:
            status = "public_reference_changed_manual_review"
            observed_tag = latest[0]
        rows.append({"id": key, "status": status, "observed_public_tag": observed_tag})
    tag, digest, size = expected["addon-suite"]
    latest_addon = None
    for _, observed, assets in addons:
        if re.fullmatch(r"v[0-9]+(?:\.[0-9]+)+", observed):
            name = "N-Addon-Collection-" + observed + ".zip"
            latest_addon = (observed, assets.get(name))
            break
    if latest_addon is None or latest_addon[1] is None:
        addon_status = "missing_stable_published_asset"
    elif (latest_addon[0], latest_addon[1][1], latest_addon[1][0]) == (tag, digest, size):
        addon_status = "pinned_public_metadata_matches"
    else:
        addon_status = "public_reference_changed_manual_review"
    rows.append({"id": "addon-suite", "status": addon_status,
                 "observed_public_tag": latest_addon[0] if latest_addon else None})
    any_changed = any(x["status"] != "pinned_public_metadata_matches" for x in rows)
    return {
        "kind": "naxxramas_public_release_metadata_drift_review",
        "schema_version": 1, "read_only": True,
        "status": "manual_reference_review_required" if any_changed else "public_metadata_matches_pinned_reference_NOT_APPROVAL",
        "items": rows, "historical_pins_modified": False,
        "downloaded_binary_assets": False, "client_files_accessed": False,
        "client_files_modified": False, "backup_or_install_performed": False,
        "redistribution_approved": False, "automatic_update_approved": False,
        "release_authorised": False,
        "limitation": "Only public GitHub release metadata. No signed provenance, full MPQ rehash, game compatibility, owner approval, rights, storage durability or installation authority.",
    }


def main():
    parser = argparse.ArgumentParser(description="Developer-only public GitHub release reference drift review")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--snapshot", type=Path, help="Existing synthetic public release JSON fixture")
    mode.add_argument("--live", action="store_true", help="Read two fixed GitHub public release API endpoints")
    args = parser.parse_args()
    try:
        snapshot = (_local(args.snapshot) if args.snapshot is not None
                    else {"patch_releases": _live(URLS[0]), "addon_releases": _live(URLS[1])})
        result = review(snapshot)
    except (Refusal, OSError) as exc:
        print("BLOCKED: " + (str(exc) if isinstance(exc, Refusal) else "unreadable_public_metadata"), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 3 if args.live and result["status"] == "manual_reference_review_required" else 0


if __name__ == "__main__":
    sys.exit(main())
