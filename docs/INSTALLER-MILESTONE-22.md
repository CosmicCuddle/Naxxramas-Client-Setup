# Milestone 22 — Read-only orphan staging inspection

**Status:** development preview, Windows CI pending. This is strictly a **disposable synthetic fixture** feature, not a WoW installer, game repair tool, or orphan-folder cleaner.

## Background

M15 creates a temporary staging folder next to the dummy copy destination. Before this milestone its final cleanup used unconditional recursive deletion; that could remove unexpected contents introduced during staging. Interruption could also leave an orphan stage with no reliable ownership record.

## New protections

1. A new stage is named `.naxx-test-copy-stage-<32 lowercase hex characters>` and is created only for an explicit confirmed, tiny synthetic copy.
2. Before writing staged dummy files, M15 creates a flushed, create-new stage marker `.naxx-fixture-stage-owner.json` containing the declared source and destination, stage path and fixed manifest file list with expected byte lengths and hashes.
3. M15 no longer calls `Remove-Item -Recurse -Force` on its staging folder. Its controlled final cleanup checks the marker, path, fixed folder layout and expected SHA-256 hashes before removing known dummy files, then removes only empty expected directories and the marker.
4. If the stage contains an unexpected file, **unexpected empty directory**, changed dummy file, unexpected link or unverifiable ownership record, the stage is **retained for manual review**. Nothing is recursively removed.
5. New `tools/Inspect-Fixture-Stage.ps1` is **read-only** and inspects exactly one stage path explicitly passed by the developer. It does not search surrounding folders. It checks both synthetic M15 markers, matching stage metadata/manifest, strict sibling and path constraints, known expected dummy file paths, sizes and SHA-256 hashes. It returns `CONSISTENT_FOR_MANUAL_REVIEW` or `BLOCKED`, never an automatic cleanup authorisation.
6. An unmarked stage caused by a crash before the stage marker write remains **untrusted** and must not be deleted by the tool. A consistent marker is self-declared evidence, not a tamperproof or authenticated ownership guarantee.

## Windows synthetic tests

`tests/Test-Fixture-Stage.ps1` creates fake tiny archive files, an empty and partially filled marked stage, then tests changed file bytes, unexpected file, unexpected empty directory, a forged stage destination, a missing stage marker and an unrelated folder. It verifies source files and the stage marker remain unchanged by inspection.

Existing M15 dummy-only copy/rollback CI also tests the guarded stage cleanup in normal success/failure paths. **No actual WoW binary, MPQ or account file is used.**

## Unresolved before any real-client copying

- Cleanup checks and deletion are not one atomic filesystem transaction; concurrent malicious changes or a power loss during multi-file cleanup still need deeper design.
- No independent cleanup action is available to players or maintainers. A reported `CONSISTENT_FOR_MANUAL_REVIEW` does not authorise deletion.
- Disk exhaustion, low-space fault injection, concurrent filesystem changes and automated staged-journal reconciliation are future, isolated synthetic milestones.
- The 1 MiB cumulative cap, maximum 256 KiB per fixture file, exact dummy path allowlist, distinct source/destination markers and closed fresh-game source remain unchanged.
- Full client file download, proprietary MPQ distribution and production client installation are disabled, pending trusted sources and applicable rights.

**Owner action:** None. Preserve the known-good WoW backup; do not run developer fixture tools against a real client.
