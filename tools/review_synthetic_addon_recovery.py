#!/usr/bin/env python3
"""Developer-only synthetic addon/WTF byte comparison. NEVER run on a player client.

This observer does not create backups, modify files or enable recovery. All four
snapshots and their marker are caller-controlled synthetic evidence only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

MARKER = '.naxx-recovery-synthetic-only'
MARKER_BYTES = b'NAXXRAMAS_SYNTHETIC_RECOVERY_TEST_ONLY\n'
SNAPSHOTS = ('original', 'backup', 'claimed_after', 'current')
ADDONS = ('NCore', 'IndividualProgressionAddon', 'DungeonJournal', 'MultiBot', 'NaxxLootLottery')
LEGACY = ('NClassicBattlegrounds', 'ServerDungeonJournal')
MAX_DEPTH = 24
MAX_ITEMS = 20000
MAX_FILE = 32 * 1024 * 1024
MAX_BYTES = 256 * 1024 * 1024
REPARSE = getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400)
CHUNK = 65536


class Refusal(ValueError):
    """Path-free failure category for the synthetic reviewer."""


def metadata(path: Path) -> os.stat_result:
    try:
        return path.lstat()
    except OSError as exc:
        raise Refusal('unavailable_entry') from exc


def is_link(meta: os.stat_result) -> bool:
    return stat.S_ISLNK(meta.st_mode) or bool(getattr(meta, 'st_file_attributes', 0) & REPARSE)


def directory(path: Path) -> os.stat_result:
    m = metadata(path)
    if is_link(m) or not stat.S_ISDIR(m.st_mode):
        raise Refusal('unsafe_directory_or_reparse')
    return m


def ancestors_safe(path: Path) -> None:
    for part in (*reversed(path.parents), path):
        directory(part)


def list_children(path: Path) -> dict[str, Path]:
    try:
        with os.scandir(path) as entries:
            values = [(e.name, Path(e.path)) for e in entries]
    except OSError as exc:
        raise Refusal('unreadable_directory') from exc
    lower = [name.casefold() for name, _ in values]
    if len(set(lower)) != len(lower):
        raise Refusal('case_collision')
    return dict(values)


def fixture_guard(root: Path) -> None:
    ancestors_safe(root)
    marker = root / MARKER
    m = metadata(marker)
    if is_link(m) or not stat.S_ISREG(m.st_mode) or m.st_size != len(MARKER_BYTES) or m.st_nlink > 1:
        raise Refusal('not_disposable_synthetic_fixture')
    try:
        with marker.open('rb') as stream:
            valid = stream.read(len(MARKER_BYTES) + 1) == MARKER_BYTES
    except OSError as exc:
        raise Refusal('not_disposable_synthetic_fixture') from exc
    if not valid:
        raise Refusal('not_disposable_synthetic_fixture')
    observed = set()
    for name in SNAPSHOTS:
        m = directory(root / name)
        identity = (m.st_dev, m.st_ino)
        if identity in observed:
            raise Refusal('shared_snapshot_directory')
        observed.add(identity)


def fixed_scope(root: Path, name: str) -> Path | None:
    if name == 'WTF':
        entries = list_children(root)
        matches = [n for n in entries if n.casefold() == 'wtf']
        if matches and matches[0] != 'WTF':
            raise Refusal('unexpected_scope_case')
        return entries.get('WTF')
    entries = list_children(root)
    interface = entries.get('Interface')
    if interface is None:
        if any(n.casefold() == 'interface' for n in entries):
            raise Refusal('unexpected_scope_case')
        return None
    directory(interface)
    children = list_children(interface)
    if 'AddOns' not in children:
        if any(n.casefold() == 'addons' for n in children):
            raise Refusal('unexpected_scope_case')
        return None
    addons = children['AddOns']
    directory(addons)
    names = list_children(addons)
    if name not in names:
        if any(n.casefold() == name.casefold() for n in names):
            raise Refusal('unexpected_scope_case')
        return None
    return names[name]


def hash_file(path: Path, meta: os.stat_result) -> str:
    if is_link(meta) or not stat.S_ISREG(meta.st_mode):
        raise Refusal('unsafe_file_type')
    if meta.st_nlink > 1:
        raise Refusal('hardlinked_file')
    if meta.st_size > MAX_FILE:
        raise Refusal('file_size_limit')
    flags = os.O_RDONLY | getattr(os, 'O_BINARY', 0) | getattr(os, 'O_NOFOLLOW', 0)
    try:
        fd = os.open(path, flags)
    except OSError as exc:
        raise Refusal('unavailable_or_locked_file') from exc
    try:
        with os.fdopen(fd, 'rb', closefd=True) as stream:
            fd = -1
            held = os.fstat(stream.fileno())
            if not stat.S_ISREG(held.st_mode) or is_link(held) or held.st_nlink > 1:
                raise Refusal('unsafe_open_file')
            if (held.st_dev, held.st_ino, held.st_size, held.st_mtime_ns) != (
                    meta.st_dev, meta.st_ino, meta.st_size, meta.st_mtime_ns):
                raise Refusal('file_changed_during_read')
            h = hashlib.sha256()
            total = 0
            while True:
                piece = stream.read(CHUNK)
                if not piece:
                    break
                total += len(piece)
                if total > MAX_FILE:
                    raise Refusal('file_size_limit')
                h.update(piece)
            ended = os.fstat(stream.fileno())
            if total != meta.st_size or (ended.st_size, ended.st_mtime_ns) != (meta.st_size, meta.st_mtime_ns):
                raise Refusal('file_changed_during_read')
    finally:
        if fd >= 0:
            os.close(fd)
    after = metadata(path)
    if is_link(after) or (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns) != (
            meta.st_dev, meta.st_ino, meta.st_size, meta.st_mtime_ns):
        raise Refusal('file_changed_during_read')
    return h.hexdigest()


def observe(root: Path, scope: str) -> dict:
    node = fixed_scope(root, scope)
    if node is None:
        return {'present': False, 'entries': {}, 'files': 0, 'dirs': 0, 'bytes': 0}
    seen = 0
    total_bytes = 0
    files = 0
    dirs = 0
    inventory = {}
    pending = [(node, '', 0)]
    while pending:
        folder, rel, depth = pending.pop()
        if depth > MAX_DEPTH:
            raise Refusal('depth_limit')
        directory(folder)
        # Include even empty directories; missing empty directories are not
        # silently treated as complete backups.
        inventory['D:' + rel] = None
        dirs += 1
        for filename, child in list_children(folder).items():
            seen += 1
            if seen > MAX_ITEMS:
                raise Refusal('entry_limit')
            child_rel = f'{rel}/{filename}' if rel else filename
            m = metadata(child)
            if is_link(m):
                raise Refusal('linked_or_reparse_entry')
            if stat.S_ISDIR(m.st_mode):
                pending.append((child, child_rel, depth + 1))
            elif stat.S_ISREG(m.st_mode):
                total_bytes += m.st_size
                if total_bytes > MAX_BYTES:
                    raise Refusal('total_byte_limit')
                inventory['F:' + child_rel] = (m.st_size, hash_file(child, m))
                files += 1
            else:
                raise Refusal('unsafe_file_type')
    return {'present': True, 'entries': inventory, 'files': files, 'dirs': dirs, 'bytes': total_bytes}


def compare(left: dict, right: dict) -> str:
    if left['entries'] == right['entries'] and left['present'] == right['present']:
        return 'matching_observed_bytes_not_backup_proof'
    if left['present'] != right['present'] or set(left['entries']) != set(right['entries']):
        return 'missing_or_extra_entries_preserve'
    return 'changed_bytes_preserve'


def review(root: Path, between_passes=None) -> dict:
    root = Path(os.path.abspath(root))
    fixture_guard(root)
    rows = []
    for scope in (*ADDONS, *LEGACY, 'WTF'):
        error = ''
        result = None
        try:
            first = {name: observe(root / name, scope) for name in SNAPSHOTS}
            if between_passes is not None:
                # Test-only injection; the reviewer itself does not write.
                between_passes(scope)
            second = {name: observe(root / name, scope) for name in SNAPSHOTS}
            if first != second:
                raise Refusal('observations_changed_between_passes')
            result = first
        except Refusal as exc:
            error = str(exc)
        row = {
            'scope': 'WTF (every account/realm/character)' if scope == 'WTF' else scope,
            'kind': 'private_settings' if scope == 'WTF' else 'legacy' if scope in LEGACY else 'suite',
            'observation': 'unsafe_manual_review' if error else 'synthetic_two_pass_observation_only',
            'reason': error,
            'backup_comparison': 'unavailable_preserve',
            'current_comparison': 'unavailable_preserve',
            'original_file_count': 0,
            'original_byte_count': 0,
            'backup_copy_authenticated': False,
            'restoration_authorised': False,
        }
        if result is not None:
            before, backup, after, current = (result[x] for x in SNAPSHOTS)
            row['original_file_count'] = before['files']
            row['original_byte_count'] = before['bytes']
            row['backup_comparison'] = compare(before, backup)
            # Any settings variation is a manual conflict, regardless of an
            # untrusted claimed after-image matching current settings bytes.
            if current == before:
                row['current_comparison'] = 'already_original_preserve'
            elif scope == 'WTF':
                row['current_comparison'] = 'settings_changed_preserve_manual_review'
            elif current == after:
                row['current_comparison'] = 'matches_untrusted_after_claim_not_recovery_permission'
            else:
                row['current_comparison'] = 'player_or_unknown_changes_preserve'
        rows.append(row)
    unsafe = sum(r['observation'] == 'unsafe_manual_review' for r in rows)
    mismatch = sum(r['backup_comparison'] != 'matching_observed_bytes_not_backup_proof' for r in rows)
    conflicts = sum(r['current_comparison'] in (
        'player_or_unknown_changes_preserve', 'settings_changed_preserve_manual_review') for r in rows)
    return {
        'kind': 'naxxramas_synthetic_addon_recovery_conflict_review',
        'schema_version': 1,
        'synthetic_fixture_only': True,
        'read_only': True,
        'status': 'manual_review_required' if (unsafe or mismatch or conflicts) else 'observations_only_no_approval',
        'scopes': rows,
        'scopes_checked': len(rows),
        'unsafe_scopes': unsafe,
        'backup_mismatch_scopes': mismatch,
        'current_conflict_scopes': conflicts,
        'whole_wtf_included': True,
        'file_contents_read_for_synthetic_sha256_only': True,
        'private_filenames_or_hashes_exposed': False,
        'backup_created': False,
        'original_backup_authenticated_or_durable': False,
        'journal_authenticity_verified': False,
        'client_updated': False,
        'restore_or_delete_performed': False,
        'automatic_recovery_authorised': False,
        'installation_or_backup_authorised': False,
        'public_release_authorised': False,
        'limitations': 'All fixture snapshots are caller-controlled, not atomic, not authoritative, not independently stored and cannot grant real recovery.',
    }


def main() -> int:
    parser = argparse.ArgumentParser(description='Read-only synthetic addon/WTF recovery conflict rehearsal')
    parser.add_argument('--synthetic-fixture-root', type=Path, required=True)
    args = parser.parse_args()
    try:
        report = review(args.synthetic_fixture_root)
    except Refusal as exc:
        print('BLOCKED: ' + str(exc), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
