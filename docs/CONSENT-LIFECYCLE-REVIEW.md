# Milestone 3 — Single-use consent lifecycle (synthetic)

**Status: read-only developer fixture, Windows PowerShell 5.1.** Nothing here issues a genuine user receipt, invokes a WoW installer, writes a journal, authenticates a signer, stores a nonce, calls DPAPI, makes backups, touches a game client, or permits rollback.

## Goal

An eventual installer must not interpret an old approval as permanent permission to change a client's V/Z mandatory patches, optional J/U visuals, realmlist, backup directory or source files. Approval of an exact, validated [plan digest](APPROVAL-PLAN-DIGEST-V2.md) would need to be short-lived, explicitly triggered by the owner, revocable while it has not been used, and **consumable at most once** before any protected transaction begins.

The new tool `tools/Review-Naxxramas-ConsentLifecycle.ps1` classifies **untrusted, caller-created JSON claims**. It models how those outcomes should be reported. It does not enforce actual single-use state or prove consent.

## Fixture v1 format

A positional ten-element JSON array:

`[1, "installation-123", "nonce-fixture-123", "aaaaaaaa...64", "aaaaaaaa...64", issued_unix, expires_unix, observed_unix, "claimed_current", [events]]`

Here the first digest is the alleged *approved* plan, and the second is the alleged *currently observed* plan. Each digest is exactly 64 lowercase hexadecimal characters; both are completely caller controlled. The IDs are 8–80 ASCII characters from the restricted safe identifier set.

Each event is an exact five-element array:

`[sequence, "state", "nonce-fixture-123", "aaaaaaaa...64", event_unix]`

- The accepted event vocabulary is `issued`, `approved`, `use_started`, `finished`, `revoked`.
- The normal claimed transaction path is `issued → approved → use_started → finished`.
- Revocation is modelled from `issued`, `approved`, or from `use_started` to describe a difficult interrupted transaction that **still requires manual review**.
- No transition out of `finished` or `revoked` is permitted.
- All event indices must be sequential and all event nonce/plan digests must match the original fixture; order and timestamps are checked as input consistency only.
- The test-only expiry claim is strictly later than issuance, at most 3,600 seconds later. The observation clock and event times are supplied by the caller, **not obtained from a trusted clock**.
- The supplied authority claim must be one of `claimed_current`, `missing`, `older`, `ahead`, `unverified`. Even `claimed_current` is NOT an authenticated latest-state observation.
- The file must be a regular, nonlinked strict-UTF-8 JSON fixture of at most 8 KiB.

## Why using the token requires special care

A future real implementation must **durably record token consumption before the first destination change**, in a trusted installation journal bound to the exact plan, client and separately protected owner registration. Consuming before a crash does not guarantee that any files were touched, and must never lead to an automatic silent retry.

The `use_started` event is a **hypothetical record only**. A fixture ending at that event is always classified for manual review; a completed fixture is **not** permission to run a second installation or undo a player's later changes. Likewise, revocation after a claimed transaction began cannot retroactively undo file writes.

A revoked, expired, mismatched or reused plan requires a **new display of the precise operations and another genuine owner action** before any separately reviewed future transaction.

## Classifications

| Input situation | Outcome |
| --- | --- |
| Claimed `issued, approved`, within claimed window, matching hashes | `fixture_claims_unused_NOT_AUTHENTICATED`; no action permitted |
| Only issued or event history missing | `explicit_consent_not_observed` |
| Revoked before/after approval or after use | `consent_revoked`; manual review |
| `use_started` or `finished` | `consent_already_used_or_transaction_started` / `consent_already_consumed` |
| Duplicate `approved` or `use_started` | Repeated event and illegal transition blockers |
| Extra states, reversed order, bad sequence numbers or cross-nonce events | Illegal lifecycle, index or binding blockers |
| Current plan digest no longer matches claimed approval | `current_plan_differs_from_approved_digest` |
| Missing, older, ahead or unverified latest-state claim | `latest_state_authority_unverified` |
| Claimed observation at/after expiry | `consent_window_expired` |
| Approval/use event after claimed expiry, regressing/future timestamps | Explicit timing inconsistency blocker |
| Entire old event log reset to an earlier apparently unused snapshot | **May appear internally consistent**: undetectable by these untrusted fixtures |

Every outcome sets `review_required=true`, `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `records_real_consent=false`, `permits_token_consumption=false`. Even a matching claimed unused token is not authentic or usable. Reports exclude installation identifiers, plan SHA and nonce.

## Synthetic test command

From a GitHub checkout under **Windows PowerShell 5.1**:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-ConsentLifecycle.ps1"`

The disposable test suite checks all accepted transitions, expiry boundaries, revocation/cancellation, two uses, reordered or duplicate events, changed current plan, cross-receipt nonce/digest, altered timestamps, missing latest-state claims, invalid JSON/schema, unchanged input bytes and **coherent old-log replay remaining invisible**.

The Windows GitHub Actions workflow is `.github/workflows/consent-lifecycle-fixtures.yml`. Neither the tool nor its test suite reads or changes actual WoW installation files.

## Production blockers — not implemented

1. Verified, **live** 3.3.5a build 12340 enUS client, allowlisted V/Z/J/U/realmlist, original destination byte/hash checks and a separate, verified backup location.
2. Clear one-time owner consent UI that binds an approved plan, a cryptographically unpredictable nonce, a session/installation identity and a genuinely checked expiry window, with explicit cancellation.
3. Authenticated receipts and a durable **independently trusted** latest-use record. Ordinary caller-writable files and DPAPI alone do **not** prevent restoring an entire older, internally consistent approval/journal/anchor snapshot.
4. Strong path/handle identity and just-in-time source/target/hash/free-space verification; Windows filesystem flush/replacement and crash-resume behaviour must be separately tested.
5. Approved local asset provenance and separate rights before distributing any MPQs. Current custom patch history is not a public redistribution licence.
6. Rollback and uninstall design that preserves player edits, original bytes, and uncertain backups. No automatic destructive recovery from a lost token, lost key or missing journal.

Related: [Approval Snapshot Review](APPROVAL-SNAPSHOT-REVIEW.md), [Plan Digest v2](APPROVAL-PLAN-DIGEST-V2.md), [Trust Continuity](TRUST-CONTINUITY-REVIEW.md), [Journal Authority](JOURNAL-AUTHORITY.md), [Project Handover](PROJECT-HANDOVER.md).

**A self-consistent fixture is never proof of ownership, approval, non-replay or permission to install.**
