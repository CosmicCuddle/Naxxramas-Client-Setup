# Journal authenticity and ownership — proposal

**Status: design-only. Nothing here creates credentials, signs records or restores files.**  
**Reviewed:** 10 October 2026  
**Related:** [Journal Durability](JOURNAL-DURABILITY.md), [Transaction Design](TRANSACTION-DESIGN.md), [Recovery Preview](RECOVERY-PREVIEW.md).

## Problem

A plain `session.json` file with SHA-256 values is **not proof** that Naxxramas Client Setup created a particular file. Anyone able to edit both the manifest and file can recalculate those hashes. Even if all current bytes match, an untrusted or stale session record must never authorise removal, replacement or restoring an older file automatically.

The existing `tools/Review-Naxxramas-Recovery.ps1` intentionally treats the JSON as **untrusted, read-only context**. It produces suggestions, not verified ownership. This document outlines a future, higher-trust journal format that a *separately reviewed* write-capable engine would need.

## Threat model

| Situation | Required response |
| --- | --- |
| Accidental editing of journal, copied JSON, missing backup or damaged data | Reject automated rollback; preserve player files and original backups |
| Another Windows user account changes a journal without access to its key | Reject journal authentication |
| Installer is closed or Windows crashes between file and journal updates | Never claim an incomplete multi-file setup succeeded; show recovery |
| Backup moved to another computer / Windows account without local key | Do not trust as a managed installation; offer **manual, read-only** comparison and recovery guidance |
| Owner changes a patched file after installation | Hash conflict; do not overwrite user content |
| Malicious software running as the same Windows user or administrator | **Outside the protection claim.** DPAPI CurrentUser and user-writable keys do not guarantee security against same-user compromise or administrators |
| Filesystem corruption, power loss, physical storage errors | Best-effort detection and fail-closed recovery; hashes/signatures cannot guarantee physical durability |

The system is designed primarily for safety from mistakes, stale state and non-privileged tampering—not as a general endpoint security boundary.

## Versioned trust levels

- **Level 0 — current, read-only:** schema v1 `session.json`; only classify; *never perform writes*.
- **Level 1 — proposed managed transaction:** a new, separately versioned signed envelope with strong binding to a specific local installation, operation list, acknowledged plan and session state. This is **not implemented**.
- **No silent upgrade:** a v1 journal must not be re-labelled as trusted v2. It has no authenticated creation history.

## Proposed local key and trust anchor

1. Generate a **unique random 256-bit secret** at the first owner-approved managed installation using a cryptographic system RNG. Never use a static application-wide or repo-stored key.
2. Protect that secret at rest using Windows DPAPI scoped to the current user, in a private directory under the user's `%LOCALAPPDATA%`. Restrict access using Windows ACLs, where available.
3. Keep the protected key **outside** the chosen backup session folder. A copied `session.json` alone must not be sufficient to claim ownership.
4. Sign a *canonical* representation of the journal payload with **HMAC-SHA-256**. Define canonical JSON rules (or use deterministic binary encoding) and reject duplicate keys, unknown required fields, inconsistent types, noncanonical values and invalid signatures. An unkeyed checksum of the same JSON is **not an authenticator**.
5. Maintain a separate protected **latest-session anchor** (session ID, target install identity, last sequence, last journal digest). Recovering older journal copies must be treated as potential replay until the anchor and event chain are reconciled.
6. Never put any secret, derived key, DPAPI blob, absolute user account path or session backup content into GitHub, public logs or a release.
7. Key loss, Windows user migration, inaccessible DPAPI state or ambiguous installation identity must **block automatic file writes**. Preserve backups and offer manual recovery guidance; do not regenerate a matching authority on demand.
8. HMAC verification proves possession of the locally protected secret, *not* publisher legitimacy, patch redistribution rights, or that the game runs correctly.

### Destination identity

A future journal should bind the approved destination to a stable local installation identity, not merely an easily edited path string. The scheme must be reviewed for folder renames, moves, copied installations and Windows drive remapping. Unknown identity after migration means **manual review**, not silent trust.

### Signed state transitions

Each event should include session ID, previous event digest, monotonically increasing sequence, state (e.g. `backing_up`, `write_started`, `verified`), allowlisted relative path, before/after sizes and SHA-256, backup digest, patchset and an event timestamp.

A trusted event must be bound to the latest signed state. A final `completed` event is permitted **only after** post-write checks confirm both V and Z and every selected file. The journal must be written in an interruption-safe order, followed by read-back verification and a protected anchor update. Because a journal update and a game-file replacement are separate operations, the system must still handle either one being ahead of the other after a crash.

The exact commit/flush protocol and atomicity of the trust anchor are **open implementation questions**; a signed envelope alone does not solve them.

## Authentication verification before a future rollback

The future engine must do **all** of the following, freshly and under its own controlled context:

1. Check the selected client and session directories, safe relative paths, symlink/junction protection and no root/nesting collisions.
2. Locate the protected local key and installation trust anchor without accepting paths or key files supplied by untrusted JSON.
3. Verify authenticated journal structure, target identity, full event chain, final sequence and compatible patchset.
4. Confirm the most recently approved operation list, exact original and installed hashes, backup files and required V/Z invariants.
5. Re-hash current on-disk client files immediately before acting. If anything differs from the expected installed signature, preserve the file and report a conflict.
6. Show exact pending restore/delete actions, obtain explicit permission and record consent in a newly authenticated event.
7. Only a separately tested, write-capable engine may then act. The current recovery preview **must not** acquire this role implicitly.

## Tests required before trust level 1 is considered implemented

- Wrong/absent key, changed journal byte, changed order of events or modified checksum field.
- Duplicate JSON properties, unknown operation/status and malformed Unicode/encoding.
- Replayed previous journal, copied session directory, altered installation identity or changed backup path.
- Damaged original backup and changed player file despite an otherwise valid event chain.
- Power loss at each journal/anchor/file update boundary; recovery should never assume a completed transaction.
- Same-volume and different-volume backup failures and partial writes.
- Loss of the DPAPI key, a moved client and recovery under another Windows account.
- No writes, deletes or network transfers during **read-only** validation.
- No operation against an actual client before the fixture-only write/rollback test suite is demonstrated.

## Open design decisions

- Review a production encoding and schema. The [synthetic v2 fixture](JOURNAL-V2-FIXTURE.md) chooses a fixed ASCII event layout with exact-byte HMAC; that choice is **not approved** for a production trust boundary.
- Whether a per-installation HMAC key protected by DPAPI is sufficient for the intended threat model, and how portable *manual* backup recovery works.
- Windows file/directory identity for renamed/moved clients.
- Crash-durable ordering of journal, checkpoint and protected anchor across filesystems.
- Whether the release should be code-signed and how users verify installer provenance.
- Private backup retention and key lifecycle after uninstall.

**Prototype checkpoint (10 October 2026):** a [synthetic v2 signed journal format](JOURNAL-V2-FIXTURE.md) and a **read-only** inspector have now been implemented and tested on Windows PowerShell 5.1. Tests use randomly generated disposable keys and anchors; no production keys, DPAPI, protected installation identity, automatic recovery or write operations exist. A stored signed journal and its **matching** anchor may still be replayed together, because the fixture has no independently protected latest-state authority.

**Next implementation step:** refine secure key/anchor management, strict input limits and Windows installation/volume identity; define a crash-tolerant state protocol and test it without a real WoW client. Do not build a write-capable rollback engine from the fixture format alone.
