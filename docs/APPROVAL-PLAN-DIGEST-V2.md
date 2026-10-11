# Milestone 3 — Read-only v2 approval plan digest

**Status:** synthetic, read-only Windows PowerShell 5.1 fixture extension. This does **not** generate real consent, authenticate Windows users, register clients, create signing keys, prove patch provenance or enable installation/rollback.

## Why this extension exists

The [Approval Snapshot Review](APPROVAL-SNAPSHOT-REVIEW.md) compares all fields of a frozen plan with another purportedly current plan. A later, genuinely approved transaction will also need a **versioned, reproducible representation of exactly which plan was shown** before a player confirms any changes.

This stage adds a **domain-separated SHA-256 fixture digest** and tests how to detect inconsistent approval snapshots and plan drift. It explicitly tests a fundamental limit: **anyone who controls both the plan and the unkeyed hash can forge a matching pair**. Therefore a matching digest is **not a signature, a consent event or authorisation**.

## Fixture formats

The existing strict approval plan remains the 11-field positional array from [Approval Snapshot Review](APPROVAL-SNAPSHOT-REVIEW.md). It covers installation ID, client/backup/source directory fingerprints, patchset, build **12340**, **enUS** locale, optional J/U booleans, exact V/Z/J/U/realmlist operations, and a provenance *claim*.

The read-only comparator now supports:

- **v1 legacy synthetic receipt:** `[1, receipt_id, consent_claim, frozen_plan]`. The previous behaviour remains intact for existing fixture tests. There is **no declared digest**.
- **v2 synthetic receipt:** `[2, receipt_id, consent_claim, frozen_plan, declared_plan_sha256]`. The comparator recomputes SHA-256 over the frozen plan and separately checks that the current plan's digest matches the declared one. All reported matches are still unauthenticated.

### Deterministic encoding for this fixture

1. Validate the frozen plan using the strict **typed positional v1 schema**. Reject unknown/extra fields, wrong game build/locale, source/destination digest syntax and forbidden operations.
2. Serialize the **validated JSON array** with Windows PowerShell 5.1 `ConvertTo-Json -InputObject $Plan -Depth 16 -Compress`. This removes cosmetic whitespace from input records, while preserving ordered array positions, JSON booleans, integers and strings.
3. Prepend exactly the ASCII domain separator `NAXX-PLAN-FIXTURE-1:` without any newline.
4. Take SHA-256 of the resulting **UTF-8** bytes and encode as a **lowercase 64-digit hexadecimal** string.

The digest is **not a secret** and is deliberately omitted from the public report to limit correlatable metadata. This is a constrained, implementation-specific canonicalization rule for this synthetic Windows PowerShell 5.1 array schema. It is **not** a general JSON canonicalization standard, a signed receipt protocol or a cross-runtime serialization guarantee.

The regression suite includes a **cross-language golden digest** for the exact fixed test plan plus a pretty-printed-JSON equivalence check.

### Validation outcomes

| Observation | Expected fixture outcome |
| --- | --- |
| Frozen and current plans match the declared digest, consent says confirmed | `fixture_claims_match_NOT_authenticated` |
| Frozen snapshot altered, but declared digest not changed | `approval_snapshot_digest_invalid` |
| Current plan changes without a new declared approval digest | `current_plan_digest_differs_from_approval` |
| Current V/Z, J/U, realmlist, backups or local patch-source fields changed | Per-file or directory blockers **as before**, plus v2 digest mismatch |
| Consent claim revoked, pending or expired | `approval_not_explicit_or_no_longer_current` |
| Invalid digest syntax, invalid frozen/current plan or extra receipt fields | Blocking validation exception |
| Attacker rewrites both the fake receipt and the fake current plan, and recomputes the unkeyed SHA-256 | Fields may match, but **still NOT authenticated** and **never authorises writes** |

**Every result** sets `review_required=true`, `allow_file_writes=false`, `allow_automatic_resume=false`, `authorises_rollback=false`, `records_real_consent=false` and `public_distribution_authorised=false`.

Read-only v2 JSON reports add `approval_fixture_version`, `approval_digest_matches_claimed_snapshot`, and `current_plan_digest_matches_claimed_receipt`, as boolean/nullable observations. They do **not** report the actual digest or personal file paths.

## Synthetic Windows test command

From the GitHub repository checkout on **Windows PowerShell 5.1**:

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-ApprovalFixture.ps1"`

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-ApprovalDigestV2.ps1"`

All tests use disposable temporary JSON only. Both suites run in the Windows approval GitHub Actions workflow. The v2 suite covers deterministic SHA-256, JSON formatting equivalence, altered frozen snapshots, changed current plans, backup location and optional selection drift, revoked consent, malformed hashes and schemas, privacy, preservation of original input bytes, and intentionally **coordinated forgery**.

## Before genuine player approval can be implemented

A real installer will require all of the following, **none of which this milestone implements**:

1. Independently generated and validated plan from **live, safely opened directories and files**, with verified patchset/hash/size, build and account-specific installation identity.
2. A clear human-readable approval dialog, with a fresh exact plan and an explicit real user action, no automatic consent.
3. An authenticated receipt/signature or MAC over that exact versioned plan, installation/session ID, one-time nonce, allowed time window and selected operations; the signing key and receipt lifecycle must be explicitly reviewed.
4. Replay/cancel/one-time use policy backed by an authority that cannot simply be replaced together with its historical record. DPAPI encryption alone is not a monotonic counter. If independent anti-rollback is unavailable for offline clients, remain fail-closed when trust is ambiguous.
5. Separate verification of **license/provenance for using and distributing every asset**; SHA-256 does not grant any rights. Current patch records explicitly do not approve public redistribution.
6. Backup-first, consent-bound, conflict-safe individual file operations with safe Windows file-handle rechecks and tested journal durability; the user must be able to preserve or manually restore exact original data.

**Further synthetic review:** [Single-use Consent Lifecycle](CONSENT-LIFECYCLE-REVIEW.md) models expiry, revocation, single-use and plan nonce binding using caller-written event labels. It is not a genuine one-time receipt or a trusted used-nonce store; a complete old-record replay may appear unused.

**Do not use a v2 fixture checksum to authorise changes to a WoW client or backup folder.** No game file or real backup has been opened or changed by these tests.
