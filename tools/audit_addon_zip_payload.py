#!/usr/bin/env python3
"""Developer-only, read-only N Addon Suite v2.0.0 ZIP payload audit.

Streams ZIP members in memory to check CRC, exact TOC load paths, expected
SavedVariables declarations, NCore dependencies, generated version manifest,
and licence/credit *presence*. Does not extract files, execute addon code,
modify WoW, back up data, or grant distribution/install approval.

--fixture is ONLY for independent disposable synthetic tests and always
reports synthetic_test_only. No fixture result establishes release approval.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import zipfile

EXPECTED_FILENAME = "N-Addon-Collection-v2.0.0.zip"
EXPECTED_SIZE = 26_762_217
EXPECTED_SHA256 = "07595216ccffe4cfc7566810ad0990bd030f813e78e2eefb4ebe2a656f5bd324"
ADDONS = ("NCore", "IndividualProgressionAddon", "DungeonJournal", "MultiBot", "NaxxLootLottery")
TOCS = {name: f"{name}/{name}.toc" for name in ADDONS}
SAVED_VARIABLES = {
    "NCore": ((), ()),
    "IndividualProgressionAddon": (("IndividualProgressionDB",), ()),
    "DungeonJournal": (("DungeonJournalDB",), ()),
    "MultiBot": (("MultiBotGlobalSave",), ("MultiBotSave", "MultiBotDB", "MultiBotSaved")),
    "NaxxLootLottery": (("NaxxLootLotteryDB",), ()),
}
EXPECTED_VERSIONS = {
    "IndividualProgressionAddon": "5.2.0",
    "DungeonJournal": "0.6.1",
    "MultiBot": "4.0",
    "NaxxLootLottery": "0.1.0.27",
}
EXTRA_MARKERS = (
    "NCore/ExpectedVersions.lua",
    "NCore/ClassicBattlegrounds/NClassicBattlegrounds.lua",
    "NCore/LegacyCheck.lua",
    "NCore/Settings.lua",
    "DungeonJournal/LICENSE-GPL-2.0.txt",
    "DungeonJournal/CREDITS.txt",
    "MultiBot/LICENSE",
)
CAPTURE = frozenset((*TOCS.values(), "NCore/ExpectedVersions.lua",
                    "DungeonJournal/LICENSE-GPL-2.0.txt",
                    "DungeonJournal/CREDITS.txt", "MultiBot/LICENSE"))
MAX_FILE = 128 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024
MAX_CAPTURE = 256 * 1024
CHUNK = 64 * 1024
RESERVED = re.compile(r"^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$", re.I)
UNSAFE = re.compile(r'[\x00-\x1f<>:"|?*]')
META = re.compile(r"^##\s*([A-Za-z][A-Za-z0-9]*):\s*(.*?)\s*$")


class AuditFailure(ValueError):
    pass


def require(condition: bool, detail: str) -> None:
    if not condition:
        raise AuditFailure(detail)


def inspect_name(name: str) -> tuple[str, bool]:
    require(bool(name) and not name.startswith("/") and "\\" not in name
            and not UNSAFE.search(name), "unsafe ZIP path")
    is_dir = name.endswith("/")
    normalized = name[:-1] if is_dir else name
    parts = normalized.split("/")
    require(1 <= len(parts) <= 12 and parts[0] in ADDONS,
            "unrecognised addon root or path depth")
    require(all(p not in ("", ".", "..") and not p.endswith((".", " "))
                and not RESERVED.fullmatch(p) for p in parts),
            "unsafe Windows filename or traversal")
    return normalized, is_dir


def toc_fields(raw: bytes, addon: str) -> tuple[dict[str, list[str]], list[str]]:
    require(len(raw) <= MAX_CAPTURE, "TOC exceeds metadata review limit")
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise AuditFailure("non-UTF-8 addon TOC: " + addon) from exc
    fields: dict[str, list[str]] = {}
    files = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") and not stripped.startswith("##"):
            continue
        match = META.match(stripped)
        if match:
            key, value = match.groups()
            fields.setdefault(key.lower(), []).append(value)
        elif stripped.startswith("##"):
            # A malformed metadata directive must not silently become code.
            raise AuditFailure("malformed addon TOC metadata: " + addon)
        else:
            require(stripped.lower().endswith((".lua", ".xml")),
                    "unexpected addon TOC content line: " + addon)
            require(not stripped.startswith(("/", "\\")) and
                    all(p not in ("", ".", "..") for p in stripped.replace("\\", "/").split("/")),
                    "unsafe addon TOC load path: " + addon)
            files.append(stripped.replace("\\", "/"))
    return fields, files


def one(fields: dict[str, list[str]], key: str, addon: str) -> str:
    values = fields.get(key.lower(), [])
    require(len(values) == 1, f"expected one {key} metadata line in {addon}")
    return values[0]


def csv_names(value: str) -> tuple[str, ...]:
    return tuple(x.strip() for x in value.split(",") if x.strip())


def check_tocs(contents: dict[str, bytes], paths: set[str]) -> int:
    references = 0
    for addon in ADDONS:
        fields, loads = toc_fields(contents[TOCS[addon]], addon)
        require(one(fields, "Interface", addon) == "30300",
                "unsupported Interface number in " + addon)
        deps = fields.get("dependencies", []) + fields.get("requireddeps", [])
        if addon == "NCore":
            require(not deps, "NCore must not require an optional addon")
        else:
            require(len(deps) == 1 and "NCore" in csv_names(deps[0]),
                    "missing NCore dependency in " + addon)
        expected_global, expected_character = SAVED_VARIABLES[addon]
        got_global = csv_names(one(fields, "SavedVariables", addon)) if expected_global else ()
        got_character = (csv_names(one(fields, "SavedVariablesPerCharacter", addon))
                         if expected_character else ())
        if not expected_global:
            require(not fields.get("savedvariables"),
                    "unexpected NCore SavedVariables declarations")
        if not expected_character:
            require(not fields.get("savedvariablespercharacter"),
                    "unexpected SavedVariablesPerCharacter declaration in " + addon)
        require(got_global == expected_global and got_character == expected_character,
                "SavedVariables declarations differ from v2.0.0 tag in " + addon)
        require(bool(loads), "empty TOC load order in " + addon)
        for relative in loads:
            require(f"{addon}/{relative}" in paths,
                    f"missing TOC referenced file in {addon}: {relative}")
            references += 1
        if addon == "NCore":
            for name in ("ExpectedVersions.lua", "ClassicBattlegrounds/NClassicBattlegrounds.lua",
                         "Settings.lua", "LegacyCheck.lua"):
                require(name in loads, "NCore TOC omits bundled component: " + name)
    return references


def audit(archive_path: Path, fixture: bool = False) -> dict:
    # No path is created, no network and no extraction. Never follow linked
    # archive components even if a path was supplied by an untrusted caller.
    absolute = archive_path.absolute()
    for node in (absolute, *absolute.parents):
        require(not node.is_symlink() and not (hasattr(node, "is_junction") and node.is_junction()),
                "linked archive path refused")
    require(absolute.is_file(), "choose an existing local ZIP")
    if not fixture:
        require(absolute.name == EXPECTED_FILENAME,
                "real-release audit requires the exact v2.0.0 ZIP filename")

    # One open read-only handle is used for hash and all ZIP member inspection.
    with absolute.open("rb") as handle:
        size = os.fstat(handle.fileno()).st_size
        if not fixture:
            require(size == EXPECTED_SIZE, "real-release ZIP size differs")
        sha = hashlib.sha256()
        while True:
            chunk = handle.read(CHUNK)
            if not chunk:
                break
            sha.update(chunk)
        digest = sha.hexdigest()
        if not fixture:
            require(digest == EXPECTED_SHA256, "real-release ZIP SHA-256 differs")
        handle.seek(0)

        with zipfile.ZipFile(handle, "r") as z:
            entries = z.infolist()
            require(5 <= len(entries) <= 15_000, "unexpected ZIP entry count")
            seen: set[str] = set()
            file_paths: set[str] = set()
            dir_paths: set[str] = set()
            for info in entries:
                path, is_dir = inspect_name(info.filename)
                key = path.casefold()
                require(key not in seen, "case-colliding or duplicate ZIP entry")
                seen.add(key)
                require(((info.external_attr >> 16) & 0xF000) != 0xA000,
                        "ZIP symlink entry refused")
                require(not (info.flag_bits & 0x1), "encrypted addon ZIP entry refused")
                require(info.file_size <= MAX_FILE and info.compress_size >= 0
                        and (info.file_size == 0 or info.compress_size > 0)
                        and (info.compress_size == 0 or
                             info.file_size <= info.compress_size * 2_000),
                        "ZIP entry too large or implausibly compressed")
                (dir_paths if is_dir else file_paths).add(key)
            require(not file_paths.intersection(dir_paths), "file-directory path collision")
            for item in file_paths:
                parts = item.split("/")
                for i in range(1, len(parts)):
                    require("/".join(parts[:i]) not in file_paths,
                            "ZIP parent path is a file")
            for path in (*TOCS.values(), *EXTRA_MARKERS):
                require(path.casefold() in file_paths, "missing tagged ZIP marker: " + path)
            require(all(any(p.startswith(addon.casefold() + "/") for p in file_paths)
                        for addon in ADDONS), "missing addon folder")

            captured: dict[str, bytes] = {}
            total = 0
            files = 0
            # zipfile's ZipExtFile verifies each member CRC on reading to EOF.
            for info in entries:
                if info.is_dir():
                    require(info.file_size == 0, "nonempty ZIP directory")
                    continue
                files += 1
                take = info.filename in CAPTURE
                if take:
                    require(info.file_size <= MAX_CAPTURE,
                            "critical manifest or licence file too large")
                buffer = bytearray()
                with z.open(info, "r") as member:
                    while True:
                        data = member.read(CHUNK)
                        if not data:
                            break
                        total += len(data)
                        require(total <= MAX_TOTAL and len(data) <= CHUNK,
                                "payload exceeds bounded streaming limit")
                        if take:
                            buffer.extend(data)
                if take:
                    captured[info.filename] = bytes(buffer)
            require(set(CAPTURE).issubset(captured),
                    "critical manifest or licence payload missing")
            references = check_tocs(captured, {info.filename for info in entries
                                                  if not info.is_dir()})
            versions = captured["NCore/ExpectedVersions.lua"].decode("utf-8-sig")
            for name, version in EXPECTED_VERSIONS.items():
                pattern = rf'\["{re.escape(name)}"\]\s*=\s*"{re.escape(version)}"'
                require(re.search(pattern, versions) is not None,
                        "generated version manifest differs: " + name)
            dj_license = captured["DungeonJournal/LICENSE-GPL-2.0.txt"].decode("utf-8-sig")
            mb_license = captured["MultiBot/LICENSE"].decode("utf-8-sig")
            credits = captured["DungeonJournal/CREDITS.txt"].decode("utf-8-sig")
            require("GNU GENERAL PUBLIC LICENSE" in dj_license.upper()
                    and "VERSION 2" in dj_license.upper(),
                    "Dungeon Journal GPLv2 licence text missing")
            require("GNU GENERAL PUBLIC LICENSE" in mb_license.upper()
                    and "VERSION 3" in mb_license.upper(),
                    "MultiBot GPLv3 licence text missing")
            require(bool(credits.strip()), "Dungeon Journal credits empty")

    return {
        "kind": "naxxramas_addon_payload_read_only_audit",
        "reference_kind": "synthetic_test_only" if fixture else "published_v2.0.0_sha256_verified",
        "archive_size_bytes": size,
        "archive_sha256": digest,
        "files_crc_verified": files,
        "streamed_uncompressed_bytes": total,
        "toc_load_file_references_checked": references,
        "five_addon_tocs_interface_30300": True,
        "ncore_dependency_and_expected_versions_checked": True,
        "savedvariables_declarations_match_tag": True,
        "license_and_credits_files_readable": True,
        "no_extraction": True,
        "lua_executed": False,
        "license_compliance_approved": False,
        "gameplay_compatibility_approved": False,
        "installation_backup_or_rollback_authorised": False,
        "redistribution_authorised": False,
        "client_files_modified": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path, help="existing local ZIP outside WoW")
    parser.add_argument("--fixture", action="store_true", help="synthetic test archives only")
    args = parser.parse_args()
    try:
        result = audit(args.archive, args.fixture)
    except (AuditFailure, OSError, ValueError, zipfile.BadZipFile, RuntimeError,
            UnicodeError, EOFError) as exc:
        print(f"BLOCKED: addon ZIP payload audit failed ({type(exc).__name__}): {exc}",
              file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
