# Transaction journal design — crash boundaries and file ownership

**Status:** engineering proposal; no write-capable installer exists.  
**Related:** [Transaction Design](TRANSACTION-DESIGN.md), [Recovery Preview](RECOVERY-PREVIEW.md).

## Why this is needed

Changing V and Z requires multiple filesystem operations, which cannot be one atomic transaction. If Windows crashes between writing `patch-V.mpq` and `patch-Z.mpq`, the next run must detect an incomplete session and refuse to treat the client as a complete Naxxramas installation.

The read-only recovery preview currently trusts an explicitly supplied local `session.json` for **classification only**. It checks SHA-256 and sizes, but this is *not* authenticated session ownership. No write-capable tool should be allowed to act merely because that preview says `restore_after_approval`.

## Safety prerequisites — before implementation

1. Only an explicitly selected **disposable test client** until repeated simulated interruptions, rollback conflicts and path guards are verified.
2. A private, unique session directory **outside** the destination client and patch source; reject nesting, junctions and drive roots.
3. Strict allowlist of V, Z, J, U and the enUS realmlist. Do not touch personal addons, unrelated MPQs, standard game files, logs or account settings.
4. Owner review of redistributable sources and their allowed usage, independently of SHA-256. Existing patch manifest values do not grant download or distribution rights.
5. Clear ownership rule: `no_change` never acquires ownership of an existing file; `install` owns only bytes the transaction created; `replace_after_backup` restores exact original bytes, never a guessed default.
6. Session metadata must be bound to the destination identity, patch reference, operation allowlist, file sizes/hashes, and the user's explicit approval at execution time. The user must be able to inspect and revoke an unstarted plan.
7. Authenticity/authorisation must be designed and reviewed: an arbitrary writable JSON file is **not trusted**. A SHA-256 field inside the same JSON cannot authenticate it. Windows ACLs help prevent casual modification but are not a cryptographic guarantee; DPAPI/HMAC design and recovery portability are currently unresolved.
8. No installation starts unless another unfinished transaction is resolved.

## Proposed on-disk layout

All files would be *local* to a chosen private backup root (never GitHub):

```text
backup-root/
  sessions/
    random-session-id/
      session.json
      originals/
        0001.bin
        0002.bin
      staged/
        0001.bin
      audit/
        events.jsonl
```

Do not publicly upload any of these files. The session may contain absolute local paths used exclusively for recovery, but those must not appear in the read-only public-facing JSON output. Backups should remain preserved after a completed install and after a conflict until explicitly retired.

## Tentative write protocol (not implemented)

**1. Plan:** verify a separate client and source; calculate expected changes and required storage on **both** the client drive and the separate backup drive; don't rely on the current planner's one-volume estimate for future writes.

**2. Freeze:** record the exact requested actions, source manifest revision, client identity and initial destination hashes. Obtain explicit approval of the exact changes and backup location.

**3. Stage:** write temporary files in a private session folder, flush/close them, verify SHA-256/length and reject a source that changed between initial preview and staging. Because final per-file atomic replacement needs same-volume staging, prepare a verified, same-volume temporary sibling for each eventual destination replacement; refuse filesystem layouts where safe placement isn't possible.

**4. Back up:** before touching the game client, copy each pre-existing destination file to a unique original backup path, flush and verify it. Do not proceed if any backup cannot be read back and verified byte for byte. Do not reuse a backup filename across different operations.

**5. Record intent:** write a new journal checkpoint containing the file path, approved source/backup hashes and the next action before executing it. Replace the previous journal using a separately verified temporary file. *Do not* mark the action committed yet.

**6. Replace file:** recheck path identity, game process/locks and immediately-before checksum; perform a same-volume per-file replacement where supported, then reopen and hash the final file. If it no longer matches expected bytes, stop and mark session recoverable/ambiguous.

**7. Record completion:** only after verification should the next checkpoint say `verified`. Before reporting the **whole session** `completed`, independently hash **both** mandatory V/Z and every selected artifact. Final output must not confuse "journal says complete" with runtime/gameplay verification.

**8. Recovery:** on next launch, if the journal is incomplete or unreadable, **do not continue installing**. Classify current and backup state without writing. If any file was edited later, keep it; if a backup is absent or corrupt, stop. Require user confirmation for each safe revert. Never silently remove files that existed before the session.

## Crash and durability qualifications

For a **prototype**, consider a Windows PowerShell 5.1 .NET FileStream that flushes bytes to disk before journal replacement and uses same-volume atomic file replacement when available. The implementation must be reviewed for the actual Windows/filesystem APIs and cannot assume an `fsync`-equivalent directory durability guarantee on every filesystem. Successful `Flush` and rename are *not* proof that a sudden power loss cannot lose or reorder metadata.

The system must recover from **both** of these ambiguity cases:

- Destination contains the installed checksum, but the journal still says `write_started` because the process stopped before the commit record.
- Journal says `verified`, but a later crash, hardware error or external modification means destination contents do not match the recorded installed checksum.

Treat each as **manual review required**, not an automatic destructive rollback. A checksum match alone does not prove that this application wrote the file or that the supplied session record is authentic.

### Pre-write and post-write crash test table

| Injection point | Required observable behaviour after restart |
| --- | --- |
| Before creating session directory | No game writes or orphaned claim of ownership |
| During writing a staged file | Ignore unfinished stage and refuse to commit |
| During original backup copy | Preserve original client, reject missing/unverified backup |
| After backup but before first commit | No changes made to client, or explicitly documented verified checkpoint |
| Immediately before renaming first destination | Do not report a completed Naxxramas installation |
| Immediately after renaming V, before completion journal | Detect journal/client mismatch and require human review |
| Between V and Z | Mark whole session incomplete and block new installs |
| After V/Z but before final manifest completion | Re-verify all file bytes and journal state; do not infer success |
| During rollback before or after any file | Replay *read-only* classification and refuse to overwrite new player edits |
| If journal contains unknown/truncated/tampered fields | Fail closed; preserve both current files and backups |

## Current tests and limits

- Windows PowerShell 5.1 synthetic tests previously passed for preflight, read-only planner, and recovery inspector.
- The next regression tests must include deterministic disk-capacity failures without any bypass parameter in the public planner, plus incomplete/forged checkpoint records and duplicate backup paths.
- No current test demonstrates the ability to survive a crash in a **write-capable** transaction. All current tools are read-only with respect to the client.

## Decision gates before fixture-only writing is considered

- [ ] Written design review of trusted session ownership and tamper detection.
- [ ] Concrete, testable journal checkpoint schema and backup retention policy.
- [ ] Atomic replacement and flush/durability semantics documented per supported Windows filesystem.
- [ ] Automated failures at every stage on disposable fixtures.
- [ ] Disk-budget enforcement on **both** volumes and safe fallback when the size is unknown.
- [ ] Security review of path traversal, reparse points, changes made between plan and commit (TOCTOU), and process locks.
- [ ] Separate approval for controlled fixture-only file-writing prototype.
- [ ] Independent approval/verification of patch source/provenance before any real-client or public installer.
