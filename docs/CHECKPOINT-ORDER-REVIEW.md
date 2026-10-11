# Milestone 3 — Checkpoint ordering and trust review

**Status:** read-only, synthetic Windows PowerShell 5.1 model. No installer, transaction journal writer, Windows flush call, backup writer, registration key, rollback operation or trusted latest-state anchor is implemented.

## Purpose

Naxxramas requires **both** `Data/patch-V.mpq` and `Data/patch-Z.mpq` to remain consistent with the selected patchset. Installing those files cannot be made one atomic cross-file action merely by renaming individual files. We need an explicit proposed ordering and a conservative restart policy before any write-capable transaction can be considered.

The new fixture viewer, `tools/Review-Naxxramas-CheckpointOrder.ps1`, evaluates a **caller-created array of labels**. It never examines client files, journals, Windows permissions or actual flush state. It is deliberately not linked to the production planner.

## Proposed 13-stage timeline (labels, NOT verified durability)

1. `user_approved` — precise plan and destination would need explicit approval
2. `staging_verified` — staged bytes would need independent size/hash verification
3. `original_v_preserved` — any prior V file would need an exact, verified original backup, or verified initial absence
4. `original_z_preserved` — same requirement for Z
5. `intent_v_recorded` — journal intent for changing V must precede its replacement
6. `destination_v_replaced` — hypothetical replacement of V
7. `destination_v_verified` — hypothetical reopen and readback verification of V
8. `intent_z_recorded` — durable intent for Z must precede its replacement
9. `destination_z_replaced` — hypothetical replacement of Z
10. `destination_z_verified` — hypothetical reopen and readback verification of Z
11. `both_core_verified` — independent V/Z compatibility/hash verification
12. `journal_completion_recorded` — intended final signed journal checkpoint, not a completed trust guarantee
13. `latest_anchor_published` — intended separate protected/latest anchor update, not a real monotonic anchor

An interruption at **any** earlier stage is manually reviewable only. An out-of-order, duplicated, skipped or unknown stage is rejected as an order violation. A claimed anchor that is behind, ahead, inaccessible, associated with another installation, or missing its key is also a manual review case.

The staging/backup and journal/anchor steps have *proposed* persistence boundaries only. Labels such as `original_v_preserved` and `latest_anchor_published` cannot prove the underlying operations really happened.

## Input format

The inspector accepts a positional JSON array of six elements:

`[1, "fixture-install-123", journal_sequence, anchor_sequence, "anchor_claim", ["user_approved", "..."]]`

- `journal_sequence` equals the number of event labels in this synthetic model.
- `anchor_sequence` is a separate claimed sequence; it is not independently obtained from protected storage.
- The `anchor_claim` value must be one of `claimed_matching`, `missing`, `unreadable`, `wrong_installation`, or `key_lost`.
- Event arrays have at most 13 elements; input files are capped at 8 KiB and must be strict UTF-8.
- Invalid schemas or unsafe fixture paths fail without granting any status.

### Developer test

Run from an extracted repository checkout using **Windows PowerShell 5.1**:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-CheckpointOrder.ps1"`

Tests use only disposable JSON files under a fresh temporary test directory. They validate all 13 interrupted prefixes, full sequence, missing or conflicting anchors, journal/anchor sequence gaps, reordered/skipped/duplicate stages, malformed inputs, output privacy and unchanged input bytes.

The output **always** contains:

- `allow_file_writes: false`
- `allow_automatic_resume: false`
- `authorises_rollback: false`

Even a complete self-consistent chain returns `fixture_fields_consistent_NOT_trusted`, **not** installation success. Replaying an entire internally consistent old chain plus matching old anchor remains possible in this purely caller-controlled model.

## What Windows documentation actually supports

**There is no approved persistent implementation in this repository.** Relevant Windows API contracts that a later separately reviewed writer must evaluate include:

- [FlushFileBuffers](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers): asks Windows to flush buffered information associated with an open file handle. It is **not** a universal promise that every filesystem, device, controller, remote host or metadata operation will survive sudden power loss.
- [ReplaceFileW](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilew): performs a file replacement with optional backup handling, and has important partial-failure return cases. **`REPLACEFILE_WRITE_THROUGH` is documented as unsupported.** Furthermore, its replaced, replacement and backup paths must be on the same volume. Never claim that setting this flag makes an installation durable.
- [CryptProtectData (DPAPI)](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata): provides Windows account/computer-scoped protection for secret material under documented conditions. It does **not** provide a monotonic latest-session counter or protect against replay of all other writable records.

A filesystem call returning success is **not** proof that the entire V/Z pair and the journal/anchor have become a single crash-atomic transaction. The actual error cases, directory metadata semantics, flush ordering, ACL and attribute handling, game process locks, linked paths and removable/network volumes all require explicit design and controlled test coverage.

## Remaining trust decisions

1. A separate Windows installation registration must only be created after informed consent and exact destination/source verification. The current directory fingerprint is an *observation*, not installer ownership.
2. Determine whether a truly **nonrollbackable latest-state authority** can be provided under the threat model. Protecting a key with DPAPI and storing signed JSON in the same user-writable location does not prevent coordinated rollback of the JSON, witness and anchor.
3. Define how loss of key, restore from backup, copied client, reinstall, account migration and missing anchor fail safely: **no silent re-registration or automatic rollback**.
4. Resolve the commit window where journal completion may exist but the latest anchor is not published (or the inverse after a crash). Without a trusted way to distinguish these, the only safe automatic behaviour is to **stop and preserve both current files and backups**.
5. Review Windows-supported APIs and device/filesystem combinations for *individually* safe file replacement and flush handling; independent recovery of V and Z is required even if per-file replacement is atomic.
6. Test every actual failure point **only on disposable fixtures** after a separate decision approving fixture-writing experiments. No real game installation, MPQ redistribution or production write engine is authorised.

See [Journal Durability](JOURNAL-DURABILITY.md), [Journal Authority](JOURNAL-AUTHORITY.md), [Crash Boundary Fixtures](CRASH-BOUNDARY-FIXTURES.md), [Transaction Design](TRANSACTION-DESIGN.md), and the [Project Handover](PROJECT-HANDOVER.md).

**These are rules for future review, not a ready-to-run installation transaction.**
