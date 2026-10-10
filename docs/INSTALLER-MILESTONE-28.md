# Milestone 28 — Native directory-identity checks for disposable fixtures

**Status:** Windows CI pending. This is a proof-of-concept in the M15 **tiny synthetic-only** Copy prototype. It is **not** an authorised production WoW installer or a fully race-free filesystem implementation.

## Purpose

M27 showed that a separate process changing source, staged or destination **file bytes** at a controlled checkpoint could be detected. File hashes and junction checks alone do not detect an attacker replacing an entire expected directory with a different normal folder of the same name, or with copied synthetic marker text.

M28 adds a conservative Windows **directory-object identity check** before moving each test file, and requires unchanged identities before any automatic failure cleanup.

## Implementation

The M15 fixture-only copy now captures a native Windows volume serial and file-index identity for the explicitly marked source and destination directories, and then for the stage once its owner marker is created. It uses `CreateFile` with directory/OPEN_REPARSE_POINT flags and `GetFileInformationByHandle` on a short-lived **read-only handle**, plus the existing ancestor link/junction checks. The identity is never used to authorise access outside the marked test roots, and no identity token is printed or uploaded.

Before each staged file promotion, the tool verifies the original source, destination and stage identities are unchanged. It also rechecks source and destination fixture markers. An identity mismatch stops the copy, **retains uncertain journals**, and suppresses automatic deletion or directory cleanup against a replaced fixture root. The stage `finally` block verifies the stage's native identity before attempting existing guarded nonrecursive cleanup.

Native file IDs are stronger evidence than pathname matching, but **they are snapshots**, not a pinned transaction: handles are closed after checking, and a second process can still change directory content between a successful identity check and a later move. The checks do **not** make the M15 prototype production-safe.

## Windows tests

New `tests/Test-Fixture-Directory-Identity.ps1` runs the confirmed synthetic copy in a separate Windows PowerShell process and waits for its flushed `applying` journal. The independent harness then **renames an entire directory** and replaces its original path with a newly created normal directory:

| Swapped directory | Expected result |
| --- | --- |
| **Source** | Copy detects a different underlying source directory despite the same marker text, preserves the old source in its new location and retains the journal for review |
| **Destination** | Copy detects a different underlying destination directory despite the same marker text, preserves the original destination and its journal, and does not write into the replacement |
| **Stage** | Copy detects the changed stage identity and neither promotes its files nor deletes replacement-folder contents; its original staged bytes are preserved for review |

The tests use five dummy files under the existing eight-name allowlist. Each is tiny; the strict maximum 256 KiB per file and 1 MiB total remain in place. They also rerun M27 external file-content mutation tests and the previous copy/rollback, recovery-readiness, transaction status, GUI and preview package suites.

## Remaining security gaps

- A directory may be swapped or linked **after** the identity check and **before** the move/delete. This milestone does **not** hold exclusive directory handles across operations, guarantee atomic rename or stop a hostile concurrent writer.
- The prototype uses native Windows file information available on the GitHub Windows runner. It is not yet portable to Linux, nor does it test every Windows filesystem type or unusual network share.
- Junction/symlink replacement at arbitrary times, hard links, marker forgery, atomic journal interruption and recovery after power loss still need separate design and tests.
- Do not merge Draft PR #1 or enable complete-client downloading/copying until legitimate verified content sources, distribution rights and production safety requirements are resolved.
- Never upload the owner's WoW binaries/MPQs, private per-file inventory or account information.
- **Owner action:** None. Keep the known-good client backup unchanged.

## Next step

M29: dedicated test-only linked-directory/junction swaps and safer path-handle/transaction design, with explicit manual recovery and stronger protection around rollback and journal sidecars. Continue dummy-only Windows tests and don't present checkpoint verification as race freedom.

**Windows CI result:** pending.
