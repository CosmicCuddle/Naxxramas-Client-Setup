# Milestone 25 — Read-only synthetic transaction status

**Status: Windows CI pending.** This milestone is restricted to marked, tiny, disposable M15 fake-game fixtures. It is **not** a repair tool, WoW installer, account scanner, or recovery authorisation.

## Purpose

After M24, an interrupted stage-owner marker, incomplete destination journal or stray journal sidecar can remain. Rather than guessing what to delete, M25 adds one local **read-only summary** that explains which synthetic state has been observed.

New developer-only tool: `tools/Inspect-Fixture-Transaction-Status.ps1`.

It takes explicit `-SourcePath`, `-DestinationPath` and `-ManifestPath`, with an optional explicit `-StagePath`. It **never** searches nearby staging folders. It invokes the existing M20 and M22 read-only inspectors for consistency checks and suppresses their detailed console output. It neither creates a JSON report nor logs absolute paths, unknown filenames, addon/account data or private content.

## Transaction classification

| Transaction label | Meaning |
| --- | --- |
| `EMPTY_MARKED_DESTINATION_NO_JOURNAL` | Exact synthetic markers and tiny manifest accepted; destination contains only its synthetic marker; no journal |
| `VERIFIED_PARTIAL_APPLYING` | M20 verified a journal in `applying` state and the bytes of any present expected dummy files |
| `VERIFIED_COPIED` | M20 verified `copied` and **all** expected dummy files are present and correctly hashed |
| `VERIFIED_PARTIAL_ROLLBACK` | M20 verified `rolling_back` with matching expected files or allowed missing files |
| `BLOCKED_JOURNAL_REPLACEMENT_RESIDUE` | A known journal `.writing`, `.previous`, `.rollback-writing` or `.rollback-previous` residue exists |
| `BLOCKED_JOURNAL_OR_DESTINATION` | The M20 read-only auditor refuses a malformed, conflicting, altered or unsafe journal/destination |
| `BLOCKED_UNEXPECTED_DESTINATION_CONTENT` | No journal exists but the destination is not exactly marker-only |
| `BLOCKED_INVALID_FIXTURE_OR_PATH` | Missing/invalid markers, non-synthetic/oversized manifest, linked/overlapping paths or other validation failure |

A consistent journal produces `STATUS: REVIEW_REQUIRED`, **not** permission to rollback. A blocked condition produces `STATUS: BLOCKED_MANUAL_REVIEW` and a nonzero exit code. Only a marker-only destination without a journal or nominated stage receives `EMPTY_MARKED_FIXTURE`.

## Stage classification

The optional **explicitly named** sibling folder receives either `CONSISTENT_REQUIRES_MANUAL_REVIEW` or `BLOCKED_UNTRUSTED_OR_CHANGED`, based on M22's independent read-only stage check. If no stage was supplied, the summary says `NOT_SELECTED`; this never means no orphan stages exist. A consistent stage is still **review-required**. A truncated owner marker or unexpected empty folder is blocked.

## Windows regression coverage

Added `tests/Test-Fixture-Transaction-Status.ps1` using disposable dummy files. Tests cover marker-only destination, unknown destination file, empty/partial `applying` journal, falsely marked `copied`, fully verified `copied`, partial `rolling_back`, journal sidecar, truncated journal, modified expected file, explicit intact stage, untrusted empty stage directory and incomplete owner marker. Tests also verify the inspector does **not** output private test strings/paths or create/remove fixture files.

The existing PowerShell syntax gate, M15 copy/rollback, M20 and M22 read-only inspections, patch/addon fixture tests, GUI smoke tests and preview ZIP packaging must all pass in Windows CI.

## Limits and next steps

- **No** automatic repair, file deletion, rollback, game archive copy, network request or saved report; no player action is required.
- These results describe a **snapshot** of self-declared synthetic fixture metadata. The status is not an authenticated ownership proof or a race-free transactional guarantee.
- Not a source of legitimate WoW game data, not evidence of permission to redistribute a Blizzard client, and not an installer for the 18.6 GB local client.
- Do not run any fixture tools against a real WoW folder or upload private inventory reports to GitHub.
- Next: add independent, explicitly confirmed, **non-destructive** manual recovery planning and robust tests for concurrent filesystem/path changes. Never automatically delete unknown files or journals.

**CI validation:** pending.
